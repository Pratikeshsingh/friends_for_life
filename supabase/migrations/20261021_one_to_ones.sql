-- One-to-one coffees between group meetups.
--
-- After group meetup 2, every week brings a round: between meetups 2–3, 3–4,
-- 4–5, 5–6 and in the week after meetup 6 (the Circle ends after that week).
-- Each round pairs people who haven't met one-to-one yet (a round-robin, so
-- in five rounds everyone can meet everyone once), at a time both are free,
-- never on a group-meetup day, at a café from the organiser's list (rotated,
-- so a Circle gets to know a few places). Coffee by day, a drink in the
-- evening: beer, tea or something without alcohol, whatever people like.
--
--   * Both say yes: it's on, both hear "You're meeting Anna".
--   * One yes, one no: the "no" gets one gentle nudge.
--   * After two days the round is settled: people whose partner couldn't,
--     and anyone left without a partner, are paired with each other where
--     possible ("Anna is busy, but Leo is free"). Everyone else: "Enjoy your
--     free week".
--   * No private chats: running late is for the group chat.
--   * Afterwards, one optional question: good, not great, or "we didn't
--     meet after all". Only the organiser sees the answers.
begin;

create table if not exists public.circle_coffee_places (
  id uuid primary key default gen_random_uuid(),
  city text not null default 'Alkmaar' check (length(city) between 1 and 80),
  kind text not null check (kind in ('daytime', 'evening')),
  name text not null check (length(name) between 1 and 120),
  address text check (address is null or length(address) <= 200),
  sort integer not null default 0
);
alter table public.circle_coffee_places enable row level security;

-- Starting list; the organiser keeps it up to date (opening hours!).
insert into public.circle_coffee_places(kind, name, address, sort)
select * from (values
  ('daytime', 'De Koffiemolen', 'Ritsevoort 26', 1),
  ('daytime', 'Kaldi', null, 2),
  ('daytime', 'Het Alkmaars Koffiehuis', 'Gedempte Nieuwesloot 42', 3),
  ('evening', 'Mr. Gold', null, 1),
  ('evening', 'Echt Alkmaar', null, 2)) v(kind, name, address, sort)
where not exists (select 1 from public.circle_coffee_places);

create table if not exists public.circle_coffee_rounds (
  circle_id uuid not null references public.circles(id) on delete cascade,
  round integer not null check (round between 1 and 5),
  window_start date not null,
  window_end date not null,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  primary key (circle_id, round)
);
alter table public.circle_coffee_rounds enable row level security;

create table if not exists public.circle_coffees (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles(id) on delete cascade,
  round integer not null check (round between 1 and 5),
  a uuid not null references public.profiles(id) on delete cascade,
  b uuid not null references public.profiles(id) on delete cascade,
  starts_at timestamptz not null,
  place text not null check (length(place) <= 120),
  address text check (address is null or length(address) <= 200),
  a_answer text check (a_answer in ('yes', 'no')),
  b_answer text check (b_answer in ('yes', 'no')),
  swap boolean not null default false,
  nudged boolean not null default false,
  status text not null default 'asked' check (status in ('asked', 'confirmed', 'off')),
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  check (a <> b)
);
create index if not exists circle_coffees_round on public.circle_coffees(circle_id, round);
alter table public.circle_coffees enable row level security;

create table if not exists public.circle_coffee_feedback (
  coffee_id uuid not null references public.circle_coffees(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  rating text not null check (rating in ('good', 'bad', 'no_show')),
  note text check (note is null or length(note) <= 1000),
  created_at timestamptz not null default now(),
  primary key (coffee_id, profile_id)
);
alter table public.circle_coffee_feedback enable row level security;

-- Helpers --------------------------------------------------------------------------
create or replace function public.circle_coffee_met(cid uuid, x uuid, y uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.circle_coffees k
                  where k.circle_id = cid and k.status = 'confirmed'
                    and ((k.a = x and k.b = y) or (k.a = y and k.b = x)));
$$;

-- The first time in [from_d, to_d] both are free: one of the offered slots,
-- not on a day the Circle meets, not on a day either already has a coffee.
create or replace function public.circle_coffee_slot(cid uuid, x uuid, y uuid, from_d date, to_d date)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sx jsonb; sy jsonb; d date; part text; dy text;
begin
  select coalesce(answers->'availability_slots', '{}'::jsonb) into sx from public.circle_applications where profile_id = x;
  select coalesce(answers->'availability_slots', '{}'::jsonb) into sy from public.circle_applications where profile_id = y;
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
      if coalesce(sx->dy, '[]'::jsonb) ? part and coalesce(sy->dy, '[]'::jsonb) ? part then
        return (d + case part when 'morning' then time '10:30'
                              when 'afternoon' then time '14:00'
                              else time '19:00' end) at time zone 'Europe/Amsterdam';
      end if;
    end loop;
  end loop;
  return null;
end;
$$;

create or replace function public.circle_coffee_when(t timestamptz)
returns text
language sql
stable
set search_path = public
as $$
  select to_char(t at time zone 'Europe/Amsterdam', 'Dy DD Mon "at" HH24:MI');
$$;

-- Proposes x and y; false when they have no time in common.
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
  spot public.circle_coffee_places;
  kid uuid;
  p uuid; o uuid; was uuid;
begin
  if t is null then return false; end if;
  -- The place this Circle has used least, so they get to know a few.
  select pl.* into spot from public.circle_coffee_places pl
   where pl.city = (select c.city from public.circles c where c.id = cid)
     and pl.kind = case when extract(hour from t at time zone 'Europe/Amsterdam') >= 17
                        then 'evening' else 'daytime' end
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
             || '. Coffee or a drink, just the two of you. Can you make it? Answer in the app.',
           'coffee:' || kid || ':' || p,
           jsonb_build_object('open', 'home')
      from public.profiles op left join public.profiles wp on wp.id = was
     where op.id = o
    on conflict do nothing;
  end loop;
  return true;
end;
$$;

-- Rounds, nudges, swaps -----------------------------------------------------------
create or replace function public.queue_circle_coffees()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer := 0; added integer;
  c record; rw record; kc record;
  r integer; w2 timestamptz; w3 timestamptz; w6 timestamptz;
  from_d date; to_d date;
  p uuid[]; m integer; i integer; x uuid; y uuid; idx integer;
  pool uuid[]; paired uuid[]; was uuid;
begin
  -- 1. A new round once the group meetup before it has ended.
  for c in select id from public.circles where status = 'active' loop
    r := null;
    for i in reverse 5..1 loop
      if exists (select 1 from public.events where circle_id = c.id and circle_week = i + 1
                                               and status <> 'cancelled' and ends_at < now()) then
        r := i; exit;
      end if;
    end loop;
    continue when r is null or exists (select 1 from public.circle_coffee_rounds where circle_id = c.id and round = r);
    select starts_at into w2 from public.events where circle_id = c.id and circle_week = r + 1;
    select starts_at into w3 from public.events where circle_id = c.id and circle_week = r + 2;
    from_d := (w2 at time zone 'Europe/Amsterdam')::date + 1;
    to_d := case when w3 is null then from_d + 6 else (w3 at time zone 'Europe/Amsterdam')::date - 1 end;
    insert into public.circle_coffee_rounds(circle_id, round, window_start, window_end)
    values (c.id, r, from_d, to_d);
    continue when to_d <= (now() at time zone 'Europe/Amsterdam')::date;

    -- Round-robin ("circle method"): fix the first person, rotate the rest.
    select array_agg(profile_id order by profile_id) into p
      from public.circle_memberships where circle_id = c.id and status = 'joined';
    continue when coalesce(array_length(p, 1), 0) < 2;
    m := array_length(p, 1) + array_length(p, 1) % 2;
    for i in 0 .. m / 2 - 1 loop
      idx := case when i = 0 then 1 else 2 + ((i - 1 + r - 1) % (m - 1)) end;
      x := p[idx];
      idx := 2 + ((m - 1 - i - 1 + r - 1) % (m - 1));
      y := p[idx];
      continue when x is null or y is null or public.circle_coffee_met(c.id, x, y);
      if public.circle_coffee_ask(c.id, r, x, y, from_d, to_d) then n := n + 2; end if;
    end loop;
  end loop;

  -- 2. One nudge for a "no" whose partner said yes, half a day later.
  for kc in select * from public.circle_coffees
            where status = 'asked' and not nudged and starts_at > now() + interval '12 hours'
              and ((a_answer = 'yes' and b_answer = 'no') or (a_answer = 'no' and b_answer = 'yes'))
              and answered_at < now() - interval '12 hours' loop
    update public.circle_coffees set nudged = true where id = kc.id;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
    select case when kc.a_answer = 'no' then kc.a else kc.b end, 'update',
           coalesce(yp.first_name, 'Your match') || ' would love to meet',
           coalesce(yp.first_name, 'Your match') || ' said yes to ' || public.circle_coffee_when(kc.starts_at)
             || '. If your plans changed, you can still say yes in the app.',
           'coffee-nudge:' || kc.id, jsonb_build_object('open', 'home')
      from public.profiles yp where yp.id = case when kc.a_answer = 'yes' then kc.a else kc.b end
    on conflict do nothing;
    n := n + 1;
  end loop;

  -- 3. Settle rounds after two days (or once nothing is open): pair up those
  --    left without a coffee, and wish everyone else a free week.
  for rw in select * from public.circle_coffee_rounds
             where decided_at is null
               and (created_at < now() - interval '48 hours'
                    or not exists (select 1 from public.circle_coffees k
                                    where k.circle_id = circle_coffee_rounds.circle_id
                                      and k.round = circle_coffee_rounds.round and k.status = 'asked')) loop
    update public.circle_coffees set status = 'off'
     where circle_id = rw.circle_id and round = rw.round and status = 'asked';
    -- Said yes but their partner couldn't, then those who had no partner.
    select coalesce(array_agg(q.pid order by q.prio, q.pid), '{}') into pool from (
      select m2.profile_id pid,
             case when exists (select 1 from public.circle_coffees k
                                where k.circle_id = rw.circle_id and k.round = rw.round
                                  and ((k.a = m2.profile_id and k.a_answer = 'yes') or (k.b = m2.profile_id and k.b_answer = 'yes')))
                  then 0 else 1 end prio
        from public.circle_memberships m2
       where m2.circle_id = rw.circle_id and m2.status = 'joined'
         and not exists (select 1 from public.circle_coffees k
                          where k.circle_id = rw.circle_id and k.round = rw.round
                            and (k.a = m2.profile_id or k.b = m2.profile_id)
                            and (k.status = 'confirmed'
                                 or (k.a = m2.profile_id and k.a_answer is distinct from 'yes')
                                 or (k.b = m2.profile_id and k.b_answer is distinct from 'yes')))) q;
    paired := '{}';
    foreach x in array pool loop
      continue when x = any(paired);
      foreach y in array pool loop
        continue when y = x or y = any(paired) or public.circle_coffee_met(rw.circle_id, x, y)
          or exists (select 1 from public.circle_coffees k where k.circle_id = rw.circle_id and k.round = rw.round
                        and ((k.a = x and k.b = y) or (k.a = y and k.b = x)));
        -- Name the partner who couldn't, for "Anna is busy, but Leo is free".
        select case when k.a = x then k.b else k.a end into was from public.circle_coffees k
         where k.circle_id = rw.circle_id and k.round = rw.round and x in (k.a, k.b) limit 1;
        if public.circle_coffee_ask(rw.circle_id, rw.round, x, y, rw.window_start, rw.window_end, was,
             (select case when k.a = y then k.b else k.a end from public.circle_coffees k
               where k.circle_id = rw.circle_id and k.round = rw.round and y in (k.a, k.b) and k.status = 'off' limit 1)) then
          paired := paired || array[x, y];
          n := n + 2;
          exit;
        end if;
      end loop;
    end loop;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
    select m2.profile_id, 'update', 'Enjoy your free week',
           'No one-to-one coffee for you this time. See you with the whole group!',
           'coffee-free:' || rw.circle_id || ':' || rw.round || ':' || m2.profile_id,
           jsonb_build_object('open', 'home')
      from public.circle_memberships m2
     where m2.circle_id = rw.circle_id and m2.status = 'joined'
       and not exists (select 1 from public.circle_coffees k
                        where k.circle_id = rw.circle_id and k.round = rw.round and k.status <> 'off'
                          and m2.profile_id in (k.a, k.b))
    on conflict do nothing;
    get diagnostics added = row_count; n := n + added;
    update public.circle_coffee_rounds set decided_at = now()
     where circle_id = rw.circle_id and round = rw.round;
  end loop;

  -- 4. A proposal nobody settled in time lapses quietly.
  update public.circle_coffees set status = 'off'
   where status = 'asked' and starts_at < now() + interval '6 hours';
  return n;
end;
$$;
revoke all on function public.queue_circle_coffees() from public, anon, authenticated;
revoke all on function public.circle_coffee_ask(uuid, integer, uuid, uuid, date, date, uuid, uuid) from public, anon, authenticated;
revoke all on function public.circle_coffee_slot(uuid, uuid, uuid, date, date) from public, anon, authenticated;
revoke all on function public.circle_coffee_met(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.circle_coffee_when(timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-coffees', '15 * * * *', 'select public.queue_circle_coffees();');
  end if;
end;
$$;

-- Answering ------------------------------------------------------------------------
alter function public.circle_action(text, jsonb) rename to circle_action_before_coffee;
revoke all on function public.circle_action_before_coffee(text, jsonb) from public, anon, authenticated;

create function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  k public.circle_coffees;
  answer text := payload->>'answer';
  other uuid;
  p uuid;
begin
  if action = 'coffee_feedback' then
    if uid is null then raise exception 'Sign in first.'; end if;
    select * into k from public.circle_coffees where id = nullif(payload->>'id', '')::uuid;
    if k.id is null or uid not in (k.a, k.b) then raise exception 'This one-to-one is not yours.'; end if;
    if k.status <> 'confirmed' or k.starts_at > now() then raise exception 'You can tell us once the coffee has happened.'; end if;
    if coalesce(payload->>'rating', '') not in ('good', 'bad', 'no_show') then raise exception 'Choose one of the options.'; end if;
    if length(coalesce(payload->>'note', '')) > 1000 then raise exception 'Please keep it under 1000 characters.'; end if;
    insert into public.circle_coffee_feedback(coffee_id, profile_id, rating, note)
    values (k.id, uid, payload->>'rating', nullif(trim(coalesce(payload->>'note', '')), ''))
    on conflict (coffee_id, profile_id) do update
      set rating = excluded.rating, note = coalesce(excluded.note, circle_coffee_feedback.note);
    return;
  elsif action = 'admin_coffee_places' then
    if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
    if payload->>'kind' not in ('daytime', 'evening') then raise exception 'Choose daytime or evening.'; end if;
    if jsonb_typeof(payload->'places') is distinct from 'array' or jsonb_array_length(payload->'places') = 0
       or exists (select 1 from jsonb_array_elements(payload->'places') x
                   where coalesce(length(trim(x->>'name')), 0) not between 1 and 120
                      or length(coalesce(x->>'address', '')) > 200) then
      raise exception 'Add at least one place, each with a name.';
    end if;
    delete from public.circle_coffee_places
     where kind = payload->>'kind' and city = coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar');
    insert into public.circle_coffee_places(city, kind, name, address, sort)
    select coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar'), payload->>'kind',
           trim(x->>'name'), nullif(trim(coalesce(x->>'address', '')), ''), i
      from jsonb_array_elements(payload->'places') with ordinality t(x, i);
    insert into public.circle_audit(actor, action, target_id) values (uid, action, uid);
    return;
  elsif action <> 'coffee_answer' then
    perform public.circle_action_before_coffee(action, payload);
    return;
  end if;
  if uid is null then raise exception 'Sign in first.'; end if;
  select * into k from public.circle_coffees where id = nullif(payload->>'id', '')::uuid for update;
  if k.id is null or uid not in (k.a, k.b)
     or not exists (select 1 from public.circle_memberships
                     where circle_id = k.circle_id and profile_id = uid and status = 'joined') then
    raise exception 'This one-to-one is not yours.';
  end if;
  if answer is null or answer not in ('yes', 'no') then raise exception 'Answer yes or no.'; end if;
  if k.status = 'off' then raise exception 'This one-to-one is no longer planned.'; end if;
  if k.starts_at <= now() then raise exception 'This one-to-one has already started.'; end if;
  other := case when uid = k.a then k.b else k.a end;

  if k.status = 'confirmed' then
    if answer = 'no' then
      update public.circle_coffees
         set status = 'off', answered_at = now(),
             a_answer = case when uid = a then 'no' else a_answer end,
             b_answer = case when uid = b then 'no' else b_answer end
       where id = k.id;
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
      select other, 'update', coalesce(me.first_name, 'Your match') || ' can’t make it after all',
             'Your coffee on ' || public.circle_coffee_when(k.starts_at) || ' is off. See you with the whole group!',
             'coffee-off:' || k.id, jsonb_build_object('open', 'home')
        from public.profiles me where me.id = uid
      on conflict do nothing;
    end if;
    return;
  end if;

  update public.circle_coffees
     set a_answer = case when uid = a then answer else a_answer end,
         b_answer = case when uid = b then answer else b_answer end,
         answered_at = now()
   where id = k.id
  returning * into k;
  if k.a_answer = 'yes' and k.b_answer = 'yes' then
    update public.circle_coffees set status = 'confirmed' where id = k.id;
    foreach p in array array[k.a, k.b] loop
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
      select p, 'update', 'You’re meeting ' || coalesce(op.first_name, 'your match'),
             public.circle_coffee_when(k.starts_at) || ' · ' || k.place
               || '. Running late? Say so in the group chat.',
             'coffee-on:' || k.id || ':' || p, jsonb_build_object('open', 'home')
        from public.profiles op where op.id = case when p = k.a then k.b else k.a end
      on conflict do nothing;
    end loop;
  elsif k.a_answer = 'no' and k.b_answer = 'no' then
    update public.circle_coffees set status = 'off' where id = k.id;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- What members see ------------------------------------------------------------------
alter function public.circle_snapshot() rename to circle_snapshot_before_coffee;
revoke all on function public.circle_snapshot_before_coffee() from public, anon, authenticated;

create function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_coffee();
  cid uuid := nullif(result->'circle'->>'id', '')::uuid;
  latest public.circle_coffee_rounds;
begin
  if cid is null or not exists (select 1 from public.circle_memberships
                                 where circle_id = cid and profile_id = uid and status = 'joined') then
    return result;
  end if;
  select * into latest from public.circle_coffee_rounds where circle_id = cid order by round desc limit 1;
  return result || jsonb_build_object('coffees', jsonb_build_object(
    'started', latest.circle_id is not null,
    'round', latest.round,
    'current', (
      select jsonb_build_object(
               'id', k.id, 'round', k.round, 'starts_at', k.starts_at, 'place', k.place, 'address', k.address,
               'status', k.status, 'swap', k.swap,
               'mine', case when k.a = uid then k.a_answer else k.b_answer end,
               'theirs', case when k.a = uid then k.b_answer else k.a_answer end,
               'other', jsonb_build_object('id', o.id, 'name', coalesce(o.first_name, 'Member'),
                                           'photo_path', o.profile_photo_path))
        from public.circle_coffees k
        join public.profiles o on o.id = case when k.a = uid then k.b else k.a end
       where k.circle_id = cid and uid in (k.a, k.b) and k.status <> 'off'
         and k.starts_at > now() - interval '3 hours'
       order by k.starts_at limit 1),
    'met', coalesce((
      select jsonb_agg(distinct case when k.a = uid then k.b else k.a end)
        from public.circle_coffees k
       where k.circle_id = cid and uid in (k.a, k.b) and k.status = 'confirmed' and k.starts_at < now()
         and not exists (select 1 from public.circle_coffee_feedback f
                          where f.coffee_id = k.id and f.rating = 'no_show')),
      '[]'::jsonb),
    -- Once, after a coffee: how was it? Optional; it goes away after a few days.
    'feedback_due', (
      select jsonb_build_object('id', k.id, 'name', coalesce(o.first_name, 'Member'))
        from public.circle_coffees k
        join public.profiles o on o.id = case when k.a = uid then k.b else k.a end
       where k.circle_id = cid and uid in (k.a, k.b) and k.status = 'confirmed'
         and k.starts_at < now() - interval '90 minutes' and k.starts_at > now() - interval '5 days'
         and not exists (select 1 from public.circle_coffee_feedback f
                          where f.coffee_id = k.id and f.profile_id = uid)
       order by k.starts_at desc limit 1),
    'free_week', latest.decided_at is not null
      and latest.window_end >= (now() at time zone 'Europe/Amsterdam')::date
      and not exists (select 1 from public.circle_coffees k
                       where k.circle_id = cid and k.round = latest.round and k.status <> 'off'
                         and uid in (k.a, k.b))));
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- What organisers see ---------------------------------------------------------------
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_coffee;
revoke all on function public.circle_admin_snapshot_before_coffee() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_admin_snapshot_before_coffee();
begin
  return result || jsonb_build_object('circles', coalesce((
    select jsonb_agg(c || jsonb_build_object('coffees', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'round', k.round, 'starts_at', k.starts_at, 'status', k.status,
                      'a', coalesce(pa.first_name, 'Member'), 'b', coalesce(pb.first_name, 'Member'),
                      'a_answer', k.a_answer, 'b_answer', k.b_answer, 'place', k.place,
                      'feedback', (select jsonb_agg(jsonb_build_object(
                                     'name', coalesce(fp.first_name, 'Member'), 'rating', f.rating, 'note', f.note))
                                     from public.circle_coffee_feedback f
                                     join public.profiles fp on fp.id = f.profile_id
                                    where f.coffee_id = k.id)) order by k.round, k.starts_at)
               from public.circle_coffees k
               join public.profiles pa on pa.id = k.a
               join public.profiles pb on pb.id = k.b
              where k.circle_id = (c->>'id')::uuid),
             '[]'::jsonb)) order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)),
    '[]'::jsonb),
    'coffee_places', coalesce((select jsonb_agg(jsonb_build_object('city', pl.city, 'kind', pl.kind, 'name', pl.name, 'address', pl.address)
                                                order by pl.city, pl.kind, pl.sort, pl.name)
                                 from public.circle_coffee_places pl), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

commit;
