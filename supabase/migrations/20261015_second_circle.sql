-- A second Circle.
--
-- After six weeks someone can look for a new Circle (a new €19) and keep
-- their finished one: its chat stays open as a "past Circle". Someone who
-- MOVES out of a Circle still loses it entirely (status 'left', unchanged).
--
-- How: memberships get an archived_at. The table becomes
-- circle_memberships_all, and circle_memberships is now a view of the
-- memberships that are not archived. Every existing function keeps asking
-- for "the" membership and keeps getting exactly one: the current Circle.
-- When someone joins a new Circle, their finished Circle is archived; if
-- that new place falls through (declined, released, refunded, moved), the
-- finished Circle comes back as current.
begin;

alter table public.circle_memberships add column if not exists archived_at timestamptz;
alter table public.circle_memberships rename to circle_memberships_all;
create view public.circle_memberships as
  select * from public.circle_memberships_all where archived_at is null;
revoke all on public.circle_memberships from public, anon, authenticated;
grant select, insert, update, delete on public.circle_memberships to service_role;

-- Still one current Circle per person; past (archived) ones do not count.
drop index if exists public.circle_one_membership;
create unique index circle_one_membership on public.circle_memberships_all (profile_id)
  where status <> 'left' and archived_at is null;

-- Archive the finished Circle when a new one starts; bring it back when
-- the new place falls through.
create or replace function public.circle_membership_archive()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Before the new membership is stored, so the one-current-Circle rule
  -- already sees the finished Circle as past.
  if tg_op = 'INSERT' and new.status <> 'left' then
    update public.circle_memberships_all m
       set archived_at = now()
      from public.circles c
     where c.id = m.circle_id and c.status = 'completed'
       and m.profile_id = new.profile_id and m.circle_id <> new.circle_id
       and m.archived_at is null and m.status = 'joined';
    return new;
  elsif tg_op = 'UPDATE' and new.status = 'left' and old.status <> 'left'
        and new.archived_at is null then
    if not exists (select 1 from public.circle_memberships_all
                    where profile_id = new.profile_id and circle_id <> new.circle_id
                      and archived_at is null and status <> 'left') then
      update public.circle_memberships_all
         set archived_at = null
       where profile_id = new.profile_id
         and circle_id = (select circle_id from public.circle_memberships_all
                           where profile_id = new.profile_id and archived_at is not null
                             and status = 'joined'
                           order by archived_at desc limit 1);
    end if;
  end if;
  return new;  -- never cancels the insert; ignored after an update
end;
$$;
revoke all on function public.circle_membership_archive() from public, anon, authenticated;
drop trigger if exists circle_membership_archive on public.circle_memberships_all;
drop trigger if exists circle_membership_restore on public.circle_memberships_all;
create trigger circle_membership_archive
before insert on public.circle_memberships_all
for each row execute function public.circle_membership_archive();
create trigger circle_membership_restore
after update of status on public.circle_memberships_all
for each row execute function public.circle_membership_archive();

-- Former Circle-mates keep seeing each other's photos and can still write
-- in their finished Circle's chat. (Copied from the live functions; only
-- the table name changed.)
CREATE OR REPLACE FUNCTION public.can_view_circle_photo(object_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select auth.uid() is not null and exists(select 1 from public.profiles owner where owner.profile_photo_path=object_name and split_part(object_name,'/',1)=owner.id::text and (
 owner.id=auth.uid() or (public.circle_is_admin() and exists(select 1 from public.circle_applications a where a.profile_id=owner.id)) or exists(
 select 1 from public.circle_memberships_all viewer join public.circle_memberships_all member on member.circle_id=viewer.circle_id join public.circles c on c.id=viewer.circle_id
 where viewer.profile_id=auth.uid() and member.profile_id=owner.id and viewer.status<>'left' and member.status<>'left' and viewer.payment_status<>'refunded' and member.payment_status<>'refunded' and c.status<>'cancelled')));
$function$;

CREATE OR REPLACE FUNCTION public.guard_circle_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cid uuid;
begin
  new.created_at := now();
  select circle_id into cid from public.chat_threads where id = new.thread_id;
  if cid is not null then
    if not exists (
      select 1 from public.circle_memberships_all m
      join public.circles c on c.id = m.circle_id
      where m.circle_id = cid and m.profile_id = new.sender_id
        and m.status = 'joined' and m.payment_status = 'paid'
        and c.status in ('active', 'completed')) then
      raise exception 'An active paid membership is required.';
    end if;
    if length(trim(new.body)) not between 1 and 2000 then
      raise exception 'Messages must be 1–2000 characters.';
    end if;
    perform pg_advisory_xact_lock(hashtext('circle-message:' || new.sender_id::text));
    if (select count(*) from public.messages
         where sender_id = new.sender_id
           and created_at > now() - interval '1 minute') >= 12 then
      raise exception 'Please wait a moment before sending more messages.';
    end if;
  end if;
  return new;
end;
$function$;

-- Actions: look for a new Circle, stop looking, write in a past Circle.
alter function public.circle_action(text, jsonb) rename to circle_action_before_second_circle;
revoke all on function public.circle_action_before_second_circle(text, jsonb) from public, anon, authenticated;

create function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.circle_memberships;
  cid uuid;
  tid uuid;
begin
  if action in ('join_again', 'stop_looking') then
    if uid is null then raise exception 'Sign in first.'; end if;
    select * into m from public.circle_memberships where profile_id = uid and status <> 'left';
    if m.circle_id is null or m.status <> 'joined'
       or not exists (select 1 from public.circles where id = m.circle_id and status = 'completed') then
      raise exception 'You can look for a new Circle once your six weeks are finished.';
    end if;
    if action = 'join_again' then
      update public.circle_applications
         set status = 'waiting', submitted_at = now(), updated_at = now()
       where profile_id = uid and status <> 'waiting';
    else
      update public.circle_applications set status = 'joined', updated_at = now()
       where profile_id = uid and status = 'waiting';
    end if;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, m.circle_id);
    return;
  elsif action = 'past_message' then
    if uid is null then raise exception 'Sign in first.'; end if;
    cid := nullif(payload->>'circle_id', '')::uuid;
    if not exists (select 1 from public.circle_memberships_all
                    where circle_id = cid and profile_id = uid and archived_at is not null
                      and status = 'joined' and payment_status = 'paid') then
      raise exception 'This is not one of your Circles.';
    end if;
    if length(trim(coalesce(payload->>'body', ''))) not between 1 and 2000 then
      raise exception 'Write a message of 1–2000 characters.';
    end if;
    select id into tid from public.chat_threads where circle_id = cid;
    insert into public.messages(thread_id, sender_id, body) values (tid, uid, trim(payload->>'body'));
    return;
  end if;
  perform public.circle_action_before_second_circle(action, payload);
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Member snapshot: looking again, everyone of a finished Circle, past Circles.
alter function public.circle_snapshot() rename to circle_snapshot_before_second_circle;
revoke all on function public.circle_snapshot_before_second_circle() from public, anon, authenticated;

create function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_second_circle();
  cid uuid := nullif(result->'circle'->>'id', '')::uuid;
begin
  if result->>'stage' = 'completed' then
    result := result || jsonb_build_object(
      'looking_again', exists (select 1 from public.circle_applications
                                where profile_id = uid and status = 'waiting'),
      -- Those who went on to a new Circle are still part of this one.
      'members', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', mm.profile_id,
                 'name', coalesce(mp.first_name, ma.answers->>'name', 'Member'),
                 'photo_path', mp.profile_photo_path,
                 'bio', coalesce(nullif(ma.answers->>'intro', ''), 'Looking forward to meeting the Circle.'),
                 'interests', ma.answers->'interests') order by mm.created_at)
          from public.circle_memberships_all mm
          join public.profiles mp on mp.id = mm.profile_id
          left join public.circle_applications ma on ma.profile_id = mm.profile_id
         where mm.circle_id = cid and mm.status = 'joined'), result->'members'));
  end if;
  return result || jsonb_build_object('past_circles', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', c.id,
             'name', c.name,
             'members', coalesce((
               select jsonb_agg(coalesce(p.first_name, 'Member') order by o.created_at)
                 from public.circle_memberships_all o join public.profiles p on p.id = o.profile_id
                where o.circle_id = c.id and o.status = 'joined' and o.profile_id <> uid), '[]'::jsonb),
             'messages', coalesce((
               select jsonb_agg(x.item order by x.created_at) from (
                 select msg.created_at, jsonb_build_object(
                          'id', msg.id, 'created_at', msg.created_at,
                          'name', coalesce(p.first_name, 'Member'),
                          'body', msg.body, 'own', msg.sender_id = uid) item
                   from public.messages msg
                   join public.chat_threads t on t.id = msg.thread_id
                   join public.profiles p on p.id = msg.sender_id
                  where t.circle_id = c.id
                  order by msg.created_at desc limit 100) x), '[]'::jsonb))
           order by m.archived_at desc)
      from public.circle_memberships_all m join public.circles c on c.id = m.circle_id
     where m.profile_id = uid and m.archived_at is not null and m.status = 'joined'), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Organiser snapshot: people who already shared a Circle are not matched
-- together again (added to the pairs to keep apart).
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_second_circle;
revoke all on function public.circle_admin_snapshot_before_second_circle() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_admin_snapshot_before_second_circle();
begin
  return result || jsonb_build_object('exclusions',
    coalesce(result->'exclusions', '[]'::jsonb) || coalesce((
      select jsonb_agg(jsonb_build_array(x.profile_id::text, y.profile_id::text))
        from public.circle_memberships_all x
        join public.circle_memberships_all y
          on y.circle_id = x.circle_id and x.profile_id < y.profile_id
        join public.circle_applications ax on ax.profile_id = x.profile_id and ax.status = 'waiting'
        join public.circle_applications ay on ay.profile_id = y.profile_id and ay.status = 'waiting'
       where x.status = 'joined' and y.status = 'joined'), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

commit;
