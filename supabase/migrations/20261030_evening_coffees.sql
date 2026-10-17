-- Evening one-to-ones: a friendly drink, and never any pressure.
--
-- 1. Two men or two women meet at the first time they're both free, as
--    before. Any other pair gets the first daytime they share, and the
--    evening only when they share no daytime that week.
-- 2. An evening invitation says it's a coffee or drink as friends, and that
--    saying no needs no reason.
-- 3. A "no" to an evening coffee gets no "would love to meet" nudge.
begin;

create or replace function public.circle_coffee_slot(cid uuid, x uuid, y uuid, from_d date, to_d date)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sx jsonb; sy jsonb; gx text; gy text; d date; part text; dy text;
  pass integer; first_pass integer;
begin
  select coalesce(answers->'availability_slots', '{}'::jsonb), answers->>'gender' into sx, gx
    from public.circle_applications where profile_id = x;
  select coalesce(answers->'availability_slots', '{}'::jsonb), answers->>'gender' into sy, gy
    from public.circle_applications where profile_id = y;
  -- Pass 1 looks at daytimes only, pass 2 at every time.
  first_pass := case when gx = gy and gx in ('man', 'woman') then 2 else 1 end;
  for pass in first_pass .. 2 loop
    for d in select g::date from generate_series(
               greatest(from_d, (now() at time zone 'Europe/Amsterdam')::date + 1), to_d, interval '1 day') g loop
      continue when exists (select 1 from public.events e
                             where e.circle_id = cid and e.status <> 'cancelled'
                               and (e.starts_at at time zone 'Europe/Amsterdam')::date = d);
      continue when exists (select 1 from public.circle_coffees k
                             where k.status <> 'off' and (k.a in (x, y) or k.b in (x, y))
                               and (k.starts_at at time zone 'Europe/Amsterdam')::date = d);
      dy := lower(to_char(d, 'Dy'));
      foreach part in array case when dy = 'tue' then array['morning']
                                 when dy in ('wed', 'thu') then array['morning', 'evening']
                                 when dy in ('fri', 'sat', 'sun') then array['afternoon', 'evening']
                                 else array[]::text[] end loop
        continue when pass = 1 and part = 'evening';
        if coalesce(sx->dy, '[]'::jsonb) ? part and coalesce(sy->dy, '[]'::jsonb) ? part then
          return (d + case part when 'morning' then time '10:30'
                                when 'afternoon' then time '14:00'
                                else time '19:00' end) at time zone 'Europe/Amsterdam';
        end if;
      end loop;
    end loop;
  end loop;
  return null;
end;
$$;
revoke all on function public.circle_coffee_slot(uuid, uuid, uuid, date, date) from public, anon, authenticated;

create or replace function public.circle_coffee_ask(cid uuid, rnd integer, x uuid, y uuid,
                                                    from_d date, to_d date,
                                                    x_was uuid default null, y_was uuid default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  t timestamptz := public.circle_coffee_slot(cid, x, y, from_d, to_d);
  evening boolean := extract(hour from t at time zone 'Europe/Amsterdam') >= 17;
  spot public.circle_coffee_places;
  kid uuid;
  p uuid; o uuid; was uuid;
begin
  if t is null then return false; end if;
  -- The place this Circle has used least, so they get to know a few.
  select pl.* into spot from public.circle_coffee_places pl
   where pl.city = (select c.city from public.circles c where c.id = cid)
     and pl.kind = case when evening then 'evening' else 'daytime' end
   order by (select count(*) from public.circle_coffees k
              where k.circle_id = cid and k.place = pl.name and k.status <> 'off'), pl.sort, pl.name
   limit 1;
  insert into public.circle_coffees(circle_id, round, a, b, starts_at, place, address, swap)
  values (cid, rnd, x, y, t, coalesce(spot.name, 'De Koffiemolen'), spot.address,
          x_was is not null or y_was is not null)
  returning id into kid;
  foreach p in array array[x, y] loop
    o := case when p = x then y else x end;
    was := case when p = x then x_was else y_was end;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
    select p, 'update',
           case when was is null then 'This week you could meet ' || coalesce(op.first_name, 'someone')
                else coalesce(wp.first_name, 'Your match') || ' is busy, but ' || coalesce(op.first_name, 'someone') || ' is free' end,
           public.circle_coffee_when(t) || ' · ' || coalesce(spot.name, 'De Koffiemolen')
             || case when evening
                     then '. An evening coffee or drink, just as friends. Can you make it? Answer in the app. Not for you? No reason needed.'
                     else '. Coffee or a drink, just the two of you. Can you make it? Answer in the app.' end,
           'coffee:' || kid || ':' || p,
           jsonb_build_object('open', 'home')
      from public.profiles op left join public.profiles wp on wp.id = was
     where op.id = o
    on conflict do nothing;
  end loop;
  return true;
end;
$$;
revoke all on function public.circle_coffee_ask(uuid, integer, uuid, uuid, date, date, uuid, uuid) from public, anon, authenticated;

-- The nudge skips evening coffees. Patched in place: the pairing already
-- carries the edge-case checks from 20261024.
do $$
declare
  d text := pg_get_functiondef('public.queue_circle_coffees()'::regprocedure);
  guard text := 'and extract(hour from starts_at at time zone ''Europe/Amsterdam'') < 17';
begin
  if position(guard in d) = 0 then
    d := replace(d, 'where status = ''asked'' and not nudged and starts_at > now() + interval ''12 hours''',
                    'where status = ''asked'' and not nudged and starts_at > now() + interval ''12 hours''
              ' || guard);
    if position(guard in d) = 0 then
      raise exception 'evening nudge patch did not apply';
    end if;
    execute d;
  end if;
end;
$$;

commit;
