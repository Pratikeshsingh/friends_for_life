-- Coffee places: opening hours and a map link.
--
-- 1. Each place gets its opening hours per weekday, a map link, and the date
--    the hours were checked. Hours look like
--      {"mon": [{"open": "08:30", "close": "17:30"}], "tue": [], ...}
--    where [] means closed that day, and a missing day or null means we
--    don't know. A close at or before the opening time runs past midnight.
-- 2. A coffee only goes to a place that's open for the whole hour. Places
--    whose hours we don't know are used only when no other place is open,
--    and a time when every place is closed isn't suggested at all.
-- 3. The coffee card links to the place on the map.
-- 4. Saving the list in the organiser screen keeps each place's hours, and
--    its link while the address stays the same.
-- 5. Alkmaar's list: seven cafés for daytime, seven places for an evening
--    drink. Runs after 20261030_evening_coffees.
begin;

alter table public.circle_coffee_places
  add column if not exists opening_hours jsonb,
  add column if not exists maps_url text,
  add column if not exists hours_checked_at date;
alter table public.circle_coffee_places drop constraint if exists circle_coffee_places_maps_url_check;
alter table public.circle_coffee_places add constraint circle_coffee_places_maps_url_check
  check (maps_url is null or (maps_url like 'https://%' and length(maps_url) <= 500));
alter table public.circle_coffee_places drop constraint if exists circle_coffee_places_opening_hours_check;
alter table public.circle_coffee_places add constraint circle_coffee_places_opening_hours_check
  check (opening_hours is null or jsonb_typeof(opening_hours) = 'object');
alter table public.circle_coffees add column if not exists maps_url text;
alter table public.circle_coffees drop constraint if exists circle_coffees_maps_url_check;
alter table public.circle_coffees add constraint circle_coffees_maps_url_check
  check (maps_url is null or (maps_url like 'https://%' and length(maps_url) <= 500));

-- Open for the whole of [starts, starts + minutes]? Null when the hours for
-- that day aren't known. Coffees are at 10:30, 14:00 and 19:00, so a night
-- before that runs past midnight never matters.
create or replace function public.circle_place_open(hours jsonb, starts timestamptz, minutes integer default 60)
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  t timestamp := starts at time zone 'Europe/Amsterdam';
  that_day jsonb := hours -> lower(to_char(t, 'Dy'));
  r jsonb; o timestamp; c timestamp;
begin
  if jsonb_typeof(that_day) is distinct from 'array' then return null; end if;
  for r in select value from jsonb_array_elements(that_day) loop
    -- A typo in the hours must never stop the coffees: it counts as unknown.
    if coalesce(r->>'open', '') !~ '^([01][0-9]|2[0-4]):[0-5][0-9]$'
       or coalesce(r->>'close', '') !~ '^([01][0-9]|2[0-4]):[0-5][0-9]$' then
      return null;
    end if;
    o := t::date + (r->>'open')::time;
    c := t::date + (r->>'close')::time;
    if c <= o then c := c + interval '1 day'; end if;
    if t >= o and t + minutes * interval '1 minute' <= c then return true; end if;
  end loop;
  return false;
end;
$$;
revoke all on function public.circle_place_open(jsonb, timestamptz, integer) from public, anon, authenticated;

-- 20261030's time picking, and a time only when somewhere is open then.
create or replace function public.circle_coffee_slot(cid uuid, x uuid, y uuid, from_d date, to_d date)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sx jsonb; sy jsonb; gx text; gy text; d date; part text; dy text;
  pass integer; first_pass integer; ts timestamptz; want text;
  town text := (select c.city from public.circles c where c.id = cid);
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
        continue when not (coalesce(sx->dy, '[]'::jsonb) ? part and coalesce(sy->dy, '[]'::jsonb) ? part);
        ts := (d + case part when 'morning' then time '10:30'
                             when 'afternoon' then time '14:00'
                             else time '19:00' end) at time zone 'Europe/Amsterdam';
        want := case when part = 'evening' then 'evening' else 'daytime' end;
        -- Somewhere must be open then, unless the town has no list yet.
        if not exists (select 1 from public.circle_coffee_places pl where pl.city = town and pl.kind = want)
           or exists (select 1 from public.circle_coffee_places pl
                       where pl.city = town and pl.kind = want
                         and public.circle_place_open(pl.opening_hours, ts) is not false) then
          return ts;
        end if;
      end loop;
    end loop;
  end loop;
  return null;
end;
$$;
revoke all on function public.circle_coffee_slot(uuid, uuid, uuid, date, date) from public, anon, authenticated;

-- 20261030's invitation, at an open place, with the map link.
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
  -- The open place this Circle has used least, so they get to know a few.
  -- A place whose hours we don't know only when no other place is open.
  select pl.* into spot from public.circle_coffee_places pl
   where pl.city = (select c.city from public.circles c where c.id = cid)
     and pl.kind = case when evening then 'evening' else 'daytime' end
     and public.circle_place_open(pl.opening_hours, t) is not false
   order by public.circle_place_open(pl.opening_hours, t) is null,
            (select count(*) from public.circle_coffees k
              where k.circle_id = cid and k.place = pl.name and k.status <> 'off'), pl.sort, pl.name
   limit 1;
  insert into public.circle_coffees(circle_id, round, a, b, starts_at, place, address, maps_url, swap)
  values (cid, rnd, x, y, t, coalesce(spot.name, 'De Koffiemolen'), spot.address, spot.maps_url,
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

-- The organiser's list: saving keeps hours and links (patched in place).
do $$
declare
  d text := pg_get_functiondef('public.circle_action_before_details(text, jsonb)'::regprocedure);
  old_sql text := $o$    delete from public.circle_coffee_places
     where kind = payload->>'kind' and city = coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar');
    insert into public.circle_coffee_places(city, kind, name, address, sort)
    select coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar'), payload->>'kind',
           trim(x->>'name'), nullif(trim(coalesce(x->>'address', '')), ''), i
      from jsonb_array_elements(payload->'places') with ordinality t(x, i);$o$;
  new_sql text := $n$    -- A place keeps its opening hours, and its map link while the
    -- address stays the same.
    with gone as (
      delete from public.circle_coffee_places
       where kind = payload->>'kind' and city = coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar')
      returning *)
    insert into public.circle_coffee_places(city, kind, name, address, sort, opening_hours, maps_url, hours_checked_at)
    select coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar'), payload->>'kind',
           trim(x->>'name'), nullif(trim(coalesce(x->>'address', '')), ''), i,
           kept.opening_hours,
           case when kept.address is not distinct from nullif(trim(coalesce(x->>'address', '')), '')
                then kept.maps_url end,
           kept.hours_checked_at
      from jsonb_array_elements(payload->'places') with ordinality t(x, i)
      left join lateral (select * from gone where lower(gone.name) = lower(trim(x->>'name')) limit 1) kept on true;$n$;
begin
  if position('kept.opening_hours' in d) = 0 then
    if position(old_sql in d) = 0 then
      raise exception 'coffee places patch did not apply';
    end if;
    execute replace(d, old_sql, new_sql);
  end if;
end;
$$;

-- Members see the link for their coffee; organisers see hours and links.
do $$
declare d text := pg_get_functiondef('public.circle_snapshot_before_details()'::regprocedure);
begin
  if position('k.maps_url' in d) = 0 then
    d := replace(d, '''place'', k.place, ''address'', k.address,',
                    '''place'', k.place, ''address'', k.address, ''maps_url'', k.maps_url,');
    if position('k.maps_url' in d) = 0 then raise exception 'snapshot patch did not apply'; end if;
    execute d;
  end if;
  d := pg_get_functiondef('public.circle_admin_snapshot_before_details()'::regprocedure);
  if position('pl.opening_hours' in d) = 0 then
    d := replace(d, '''name'', pl.name, ''address'', pl.address)',
                    '''name'', pl.name, ''address'', pl.address, ''maps_url'', pl.maps_url, ''opening_hours'', pl.opening_hours)');
    if position('pl.opening_hours' in d) = 0 then raise exception 'organiser snapshot patch did not apply'; end if;
    execute d;
  end if;
end;
$$;

-- Alkmaar ------------------------------------------------------------------------
-- Hours Monday to Sunday: 'closed', or null for every day when the venue
-- doesn't publish reliable hours (Soepp's change weekly; 1480 Foodbar gives
-- no closing time). Those are only used when nothing else is open.
-- One statement, no temporary tables, so it also works when the SQL editor
-- runs it again or in parts. Same name and kind: updated in place; new ones
-- added; the rest removed (Mr. Gold, and Echt Alkmaar and Het Alkmaars
-- Koffiehuis under their old kinds, as each moved to the other list).
with places(kind, name, address, sort, hours, maps_url) as (values
  ('daytime', 'Anne&Max', 'Kraanbuurt 3', 1,
   array['08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30'],
   'https://www.google.com/maps/search/?api=1&query=Anne%26Max%2C+Kraanbuurt+3%2C+Alkmaar'),
  ('daytime', 'De Koffiemolen', 'Ritsevoort 26', 2,
   array['09:00-17:00', '09:00-17:00', '09:00-17:00', '09:00-17:00', '09:00-17:00', '09:00-17:00', '09:30-16:30'],
   'https://www.google.com/maps/search/?api=1&query=De+Koffiemolen%2C+Ritsevoort+26%2C+Alkmaar'),
  ('daytime', 'Echt Alkmaar', 'Marktstraat 4', 3,
   array['08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30', '08:30-17:30'],
   'https://www.google.com/maps/search/?api=1&query=Echt+Alkmaar%2C+Marktstraat+4%2C+Alkmaar'),
  ('daytime', 'Soepp', 'Hekelstraat 31', 4, null::text[],
   'https://www.google.com/maps/search/?api=1&query=Soepp%2C+Hekelstraat+31%2C+Alkmaar'),
  ('daytime', 'Kaatje''s Bakery', 'Zevenhuizen 8', 5,
   array['08:30-16:00', '08:30-16:00', '08:30-16:00', '08:30-16:00', '08:30-16:00', '09:00-16:00', '09:00-16:00'],
   'https://www.google.com/maps/search/?api=1&query=Kaatje%27s+Bakery%2C+Zevenhuizen+8%2C+Alkmaar'),
  ('daytime', 'Miss Central', 'Laat 183', 6,
   array['closed', '09:30-17:00', '09:30-17:00', '09:30-17:00', '09:30-17:00', '10:00-18:00', '10:00-18:00'],
   'https://www.google.com/maps/search/?api=1&query=Miss+Central%2C+Laat+183%2C+Alkmaar'),
  ('daytime', 'Kaldi', 'Marktstraat 13', 7,
   array['13:00-17:30', '09:00-17:30', '09:00-17:30', '09:00-17:30', '09:00-17:30', '09:00-17:00', '12:00-17:00'],
   'https://www.google.com/maps/search/?api=1&query=Kaldi%2C+Marktstraat+13%2C+Alkmaar'),
  ('evening', 'De Binnenkomer', 'Kerkplein 6', 1,
   array['closed', '10:00-00:00', '10:00-00:00', '10:00-00:00', '10:00-01:00', '10:00-01:00', '11:00-00:00'],
   'https://www.google.com/maps/search/?api=1&query=De+Binnenkomer%2C+Kerkplein+6%2C+Alkmaar'),
  ('evening', 'Hofman', 'Kerkplein 7', 2,
   array['10:00-00:00', '10:00-00:00', '10:00-00:00', '10:00-00:00', '10:00-00:00', '10:00-00:00', '10:00-00:00'],
   'https://www.google.com/maps/search/?api=1&query=Hofman%2C+Kerkplein+7%2C+Alkmaar'),
  ('evening', 'Jonas Bistro Bar', 'Zevenhuizen 11', 3,
   array['16:00-00:00', '16:00-00:00', '16:00-00:00', '16:00-00:00', '16:00-00:00', '14:00-00:00', '14:00-00:00'],
   'https://www.google.com/maps/search/?api=1&query=Jonas+Bistro+Bar%2C+Zevenhuizen+11%2C+Alkmaar'),
  ('evening', 'Grand Café Klunder', 'Canadaplein 2', 4,
   array['09:00-22:00', '09:00-22:00', '09:00-22:00', '09:00-22:00', '09:00-22:00', '09:00-22:00', '11:00-22:00'],
   'https://www.google.com/maps/search/?api=1&query=Grand+Caf%C3%A9+Klunder%2C+Canadaplein+2%2C+Alkmaar'),
  ('evening', 'Soepp', 'Hekelstraat 31', 5, null,
   'https://www.google.com/maps/search/?api=1&query=Soepp%2C+Hekelstraat+31%2C+Alkmaar'),
  ('evening', '1480 Foodbar', 'Mient 16', 6, null,
   'https://www.google.com/maps/search/?api=1&query=1480+Foodbar%2C+Mient+16%2C+Alkmaar'),
  ('evening', 'Het Alkmaars Koffiehuis', 'Gedempte Nieuwesloot 42', 7,
   array['closed', 'closed', '12:00-00:00', '12:00-00:00', '12:00-02:00', '12:00-02:00', '12:00-00:00'],
   'https://www.google.com/maps/search/?api=1&query=Het+Alkmaars+Koffiehuis%2C+Gedempte+Nieuwesloot+42%2C+Alkmaar')),
ready as (
  select v.kind, v.name, v.address, v.sort, v.maps_url,
         case when v.hours is not null then
           (select jsonb_object_agg(u.dk, case when u.h is null then 'null'::jsonb
                                               when u.h = 'closed' then '[]'::jsonb
                                               else jsonb_build_array(jsonb_build_object(
                                                      'open', split_part(u.h, '-', 1),
                                                      'close', split_part(u.h, '-', 2))) end)
              from unnest(array['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], v.hours) u(dk, h))
         end as opening_hours,
         case when v.hours is not null and array_position(v.hours, null) is null
              then date '2026-10-13' end as hours_checked_at
    from places v),
updated as (
  update public.circle_coffee_places p
     set address = r.address, sort = r.sort, opening_hours = r.opening_hours,
         maps_url = r.maps_url, hours_checked_at = r.hours_checked_at
    from ready r
   where p.city = 'Alkmaar' and p.kind = r.kind and p.name = r.name
  returning p.id),
added as (
  insert into public.circle_coffee_places(city, kind, name, address, sort, opening_hours, maps_url, hours_checked_at)
  select 'Alkmaar', r.kind, r.name, r.address, r.sort, r.opening_hours, r.maps_url, r.hours_checked_at
    from ready r
   where not exists (select 1 from public.circle_coffee_places p
                      where p.city = 'Alkmaar' and p.kind = r.kind and p.name = r.name)
  returning id)
delete from public.circle_coffee_places p
 where p.city = 'Alkmaar'
   and not exists (select 1 from ready r where r.kind = p.kind and r.name = p.name);

commit;
