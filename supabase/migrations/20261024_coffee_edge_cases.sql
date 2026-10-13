-- One-to-one coffees: what happens when life gets in the way.
--
-- 1. Never pair two people when one asked not to be matched with the other,
--    or reported one of the other's messages.
-- 2. Someone leaves the Circle, is removed, or deletes their account: their
--    planned coffees are called off and the other person is told (without
--    saying why).
-- 3. "Don't match us again" during the programme calls off a planned coffee
--    between those two, the same quiet way.
-- 4. A cancelled Circle calls off its coffees (members already hear about
--    the cancellation itself).
begin;

create or replace function public.circle_coffee_blocked(x uuid, y uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.circle_exclusions e
                  where (e.profile_id = x and e.excluded_profile_id = y)
                     or (e.profile_id = y and e.excluded_profile_id = x))
      or exists (select 1 from public.circle_reports r
                   join public.messages m on m.id = r.message_id
                  where (r.profile_id = x and m.sender_id = y)
                     or (r.profile_id = y and m.sender_id = x));
$$;
revoke all on function public.circle_coffee_blocked(uuid, uuid) from public, anon, authenticated;

do $$
declare d text := pg_get_functiondef('public.queue_circle_coffees()'::regprocedure);
begin
  d := replace(d, 'continue when x is null or y is null or public.circle_coffee_met(c.id, x, y);',
                  'continue when x is null or y is null or public.circle_coffee_met(c.id, x, y)
        or public.circle_coffee_blocked(x, y);');
  d := replace(d, 'continue when y = x or y = any(paired) or public.circle_coffee_met(rw.circle_id, x, y)',
                  'continue when y = x or y = any(paired) or public.circle_coffee_met(rw.circle_id, x, y)
          or public.circle_coffee_blocked(x, y)');
  if (length(d) - length(replace(d, 'circle_coffee_blocked', ''))) / length('circle_coffee_blocked') <> 2 then
    raise exception 'coffee pairing patch did not apply';
  end if;
  execute d;
end;
$$;

-- Calls off the upcoming coffees of [who] (in [cid], or anywhere when null),
-- or only the one with [other] when given, and tells the partner.
create or replace function public.circle_coffees_call_off(who uuid, cid uuid default null,
                                                          other uuid default null, quiet boolean default false)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  k public.circle_coffees;
  partner uuid;
  n integer := 0;
  who_name text := (select first_name from public.profiles where id = who);
begin
  for k in select * from public.circle_coffees
            where status in ('asked', 'confirmed') and starts_at > now()
              and who in (a, b)
              and (cid is null or circle_id = cid)
              and (other is null or other in (a, b))
            for update loop
    update public.circle_coffees set status = 'off' where id = k.id;
    partner := case when k.a = who then k.b else k.a end;
    if not quiet then
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
      values (partner, 'update', coalesce(who_name, 'Your match') || ' can’t make it after all',
              'Your coffee on ' || public.circle_coffee_when(k.starts_at) || ' is off. See you with the whole group!',
              'coffee-off:' || k.id, jsonb_build_object('open', 'home'))
      on conflict do nothing;
    end if;
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.circle_coffees_call_off(uuid, uuid, uuid, boolean) from public, anon, authenticated;

-- Leaving, being removed, moving to another group, or the Circle closing.
create or replace function public.circle_coffees_on_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'joined' and (new.status <> 'joined' or (new.archived_at is not null and old.archived_at is null)) then
    perform public.circle_coffees_call_off(new.profile_id, new.circle_id);
  end if;
  return new;
end;
$$;
drop trigger if exists circle_coffees_on_membership on public.circle_memberships_all;
create trigger circle_coffees_on_membership
after update of status, archived_at on public.circle_memberships_all
for each row execute function public.circle_coffees_on_membership();

create or replace function public.circle_coffees_on_circle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    update public.circle_coffees set status = 'off'
     where circle_id = new.id and status in ('asked', 'confirmed');
  end if;
  return new;
end;
$$;
drop trigger if exists circle_coffees_on_circle on public.circles;
create trigger circle_coffees_on_circle
after update of status on public.circles
for each row execute function public.circle_coffees_on_circle();

-- Account deletion: tell the partner before the coffee row disappears.
create or replace function public.circle_coffees_on_profile_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.circle_coffees_call_off(old.id);
  return old;
end;
$$;
drop trigger if exists circle_coffees_on_profile_delete on public.profiles;
create trigger circle_coffees_on_profile_delete
before delete on public.profiles
for each row execute function public.circle_coffees_on_profile_delete();

-- "Don't match us again" during the programme.
create or replace function public.circle_coffees_on_exclusion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.circle_coffees_call_off(new.profile_id, null, new.excluded_profile_id);
  return new;
end;
$$;
drop trigger if exists circle_coffees_on_exclusion on public.circle_exclusions;
create trigger circle_coffees_on_exclusion
after insert on public.circle_exclusions
for each row execute function public.circle_coffees_on_exclusion();

commit;
