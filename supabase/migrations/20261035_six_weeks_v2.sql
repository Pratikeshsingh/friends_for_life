-- The six weeks, version two. Runs after 20261034_time_windows.
--
-- 1. The fee is €39 once, with two activities included.
-- 2. Three plans (morning, afternoon, evening). Weeks 1–4 and 6 are booked
--    for the group; week 5 is the group's own ("Your call"). Each week has
--    its own start: evening activities at 20:00, the dinner at 19:00.
-- 3. Members plan week 5 only: its day stays, and they choose a start in
--    their part of the day (evenings 18:00–21:00).
-- 4. Week 5 reminders: an email to everyone 7 days before, a VriendTime
--    message in the group chat 5 days before, and an alert to the organiser
--    3 days before if it is still open. Week 6 is never changed by members.
-- 5. Booking: each place says how it is booked (online, email or phone);
--    for email-only places the organiser sends a booking email in one tap.
-- Every statement stands alone and can run again safely.

-- 1. €39 -------------------------------------------------------------------------------
alter table public.circle_payments alter column amount_cents set default 3900;
alter table public.circle_payments drop constraint if exists circle_payments_amount_cents_check;
alter table public.circle_payments add constraint circle_payments_amount_cents_check
  check (amount_cents in (1900, 3900));
alter table public.circle_payments alter column agreement_version set default 'circle-39-eur-v1';

-- Every message that names the fee (agreements, reminders, refunds).
do $$
declare f record;
begin
  for f in select p.oid from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.prosrc like '%€19%' loop
    execute replace(pg_get_functiondef(f.oid), '€19', '€39');
  end loop;
end;
$$;

-- 2. Plans --------------------------------------------------------------------------------
alter table public.circle_programme_template add column if not exists start_time time;
alter table public.circle_programme_template add column if not exists included boolean not null default false;
alter table public.circle_programme_template alter column venue drop not null;
alter table public.events add column if not exists included boolean not null default false;
alter table public.events add column if not exists booking_status text;
alter table public.events drop constraint if exists events_booking_status_check;
alter table public.events add constraint events_booking_status_check
  check (booking_status is null or booking_status in ('requested', 'booked'));
alter table public.events add column if not exists booking_requested_at timestamptz;
alter table public.events add column if not exists group_nudged_at timestamptz;

insert into public.circle_programme_template(city, kind, week, title, venue, address, cost, start_time, included, booking_name)
values
  ('Alkmaar', 'evening', 1, 'Hello, new faces', '1480 Foodbar', 'Mient 16',
   'You pay for your own drinks.', '20:00', false, null),
  ('Alkmaar', 'evening', 2, 'Find out who’s secretly competitive', 'The Boules Club', 'Noorderkade 108',
   'Included in your fee: we book and pay for the court. Drinks are on you.', '20:00', true, null),
  ('Alkmaar', 'evening', 3, 'Go beyond “what do you do?”', 'Rozey Alkmaar', 'Gedempte Nieuwesloot 4B',
   'About €40 per person: dinner and drinks, all you can eat.', '19:00', false, null),
  ('Alkmaar', 'evening', 4, 'The rematch', 'The Hangout', 'Kwakelkade 10',
   'Included in your fee: we book and pay for the game. Drinks are on you.', '20:00', true, null),
  ('Alkmaar', 'evening', 5, 'Your call', null, null,
   'Up to your group.', '20:00', false, null),
  ('Alkmaar', 'evening', 6, 'Graduation: a new beginning', 'Hofman', 'Kerkplein 7',
   'Drinks and sharing bites, about €15–20 per person. You pay for yourself.', '20:00', false, null),
  ('Alkmaar', 'afternoon', 1, 'Hello, new faces', 'Grand Café Klunder', 'Canadaplein 2',
   'You pay for your own coffee or drinks.', '14:00', false, null),
  ('Alkmaar', 'afternoon', 2, 'Find out who’s secretly competitive', 'De Spellentoren', 'Schoutenstraat 28',
   'Included in your fee: entry to the board-game room. Drinks are on you.', '14:00', true, null),
  ('Alkmaar', 'afternoon', 3, 'Go beyond “what do you do?”', 'Rozey Alkmaar', 'Gedempte Nieuwesloot 4B',
   'About €35 per person: lunch and drinks, all you can eat.', '14:00', false, null),
  ('Alkmaar', 'afternoon', 4, 'The rematch', 'The Hangout', 'Kwakelkade 10',
   'Included in your fee: we book and pay for the game. Drinks are on you.', '14:00', true, null),
  ('Alkmaar', 'afternoon', 5, 'Your call', null, null,
   'Up to your group.', '14:00', false, null),
  ('Alkmaar', 'afternoon', 6, 'Graduation: a new beginning', 'Hofman', 'Kerkplein 7',
   'Drinks and sharing bites, about €15–20 per person. You pay for yourself.', '14:00', false, null),
  ('Alkmaar', 'morning', 1, 'Hello, new faces', 'Grand Café Klunder', 'Canadaplein 2',
   'You pay for your own coffee.', '10:30', false, null),
  ('Alkmaar', 'morning', 2, 'Find out who’s secretly competitive', 'De Spellentoren', 'Schoutenstraat 28',
   'Included in your fee: entry to the board-game room. Coffee is on you.', '10:30', true, null),
  ('Alkmaar', 'morning', 3, 'Go beyond “what do you do?”', 'Soepp', 'Hekelstraat 31',
   'A shared brunch, about €25 per person. You pay for yourself.', '10:30', false, null),
  ('Alkmaar', 'morning', 4, 'Say cheese', 'Hollands Kaasmuseum', 'Waagplein 2',
   'Included in your fee: your museum tickets.', '10:30', true, null),
  ('Alkmaar', 'morning', 5, 'Your call', null, null,
   'Up to your group.', '10:30', false, null),
  ('Alkmaar', 'morning', 6, 'Graduation: a new beginning', 'Hofman', 'Kerkplein 7',
   'Brunch, about €15–20 per person. You pay for yourself.', '10:30', false, null)
on conflict (city, kind, week) do update
  set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost,
      start_time = excluded.start_time, included = excluded.included, booking_name = excluded.booking_name;

-- Creating a Circle and saving suggestions (patched in place): each week
-- carries its start time and whether it is included; week 5 may have no place.
do $$
declare
  d text := pg_get_functiondef('public.circle_action_before_coffee(text, jsonb)'::regprocedure);
  pairs text[][] := array[
    -- The plan's validation.
    [$o$       or exists (select 1 from jsonb_array_elements(payload->'weeks') w
                   where coalesce(length(trim(w->>'title')), 0) not between 1 and 120
                      or coalesce(length(trim(w->>'venue')), 0) not between 1 and 180) then
      raise exception 'Add an activity and a place for all six weeks.';$o$,
     $n$       or exists (select 1 from jsonb_array_elements(payload->'weeks') with ordinality v(w, i)
                   where coalesce(length(trim(w->>'title')), 0) not between 1 and 120
                      or length(trim(coalesce(w->>'venue', ''))) > 180
                      -- Week 5 is the group's own: its place may stay open.
                      or (i <> 5 and coalesce(length(trim(w->>'venue')), 0) = 0)
                      or coalesce(w->>'time', '00:00') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'Add an activity and a place for every week except week 5.';$n$],
    -- Older apps send no plan: use the saved one for this part of the day.
    [$o$'cost', t.cost, 'booking', t.booking_name) order by t.week)$o$,
     $n$'cost', t.cost, 'booking', t.booking_name, 'included', t.included) order by t.week)$n$],
    [$o$and t.kind = case when public.circle_time_period((payload->>'time')::time) = 'evening' then 'evening' else 'daytime' end));$o$,
     $n$and t.kind = coalesce(public.circle_time_period((payload->>'time')::time), 'evening')));$n$],
    -- Each week: its own start (and so its end), included or not, maybe no place yet.
    [$o$       set title = trim(w->>'title'), venue_name = trim(w->>'venue'),$o$,
     $n$       set title = trim(w->>'title'), venue_name = nullif(trim(coalesce(w->>'venue', '')), ''),
           included = coalesce((w->>'included')::boolean, false),
           starts_at = case when w->>'time' is not null
                            then ((e.starts_at at time zone 'Europe/Amsterdam')::date + (w->>'time')::time) at time zone 'Europe/Amsterdam'
                            else e.starts_at end,
           ends_at = public.circle_window_end(case when w->>'time' is not null
                            then ((e.starts_at at time zone 'Europe/Amsterdam')::date + (w->>'time')::time) at time zone 'Europe/Amsterdam'
                            else e.starts_at end),$n$],
    -- Saved suggestions keep the start time and whether it is included.
    [$o$if payload->>'kind' not in ('morning', 'afternoon', 'daytime', 'evening') then raise exception 'Choose daytime or evening.'; end if;
    insert into public.circle_programme_template(city, kind, week, title, venue, address, cost, booking_name)
    select coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar'), payload->>'kind', (w->>'week')::int, trim(w->>'title'), trim(w->>'venue'),$o$,
     $n$if payload->>'kind' not in ('morning', 'afternoon', 'daytime', 'evening') then raise exception 'Choose daytime or evening.'; end if;
    insert into public.circle_programme_template(city, kind, week, title, venue, address, cost, booking_name, start_time, included)
    select coalesce(nullif(trim(payload->>'city'), ''), 'Alkmaar'), payload->>'kind', (w->>'week')::int, trim(w->>'title'), nullif(trim(coalesce(w->>'venue', '')), ''),$n$],
    [$o$           nullif(left(trim(coalesce(w->>'booking', '')), 120), '')
      from jsonb_array_elements(coalesce(payload->'weeks', '[]'::jsonb)) w
    on conflict (city, kind, week) do update
      set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost,
          booking_name = excluded.booking_name;$o$,
     $n$           nullif(left(trim(coalesce(w->>'booking', '')), 120), ''),
           case when w->>'time' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then (w->>'time')::time end,
           coalesce((w->>'included')::boolean, false)
      from jsonb_array_elements(coalesce(payload->'weeks', '[]'::jsonb)) w
    on conflict (city, kind, week) do update
      set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost,
          booking_name = excluded.booking_name, start_time = excluded.start_time, included = excluded.included;$n$]];
  i int;
begin
  if position('every week except week 5' in d) > 0 then return; end if;
  for i in 1 .. array_length(pairs, 1) loop
    if position(pairs[i][1] in d) = 0 then
      raise exception 'six-week plan patch % did not apply', i;
    end if;
    d := replace(d, pairs[i][1], pairs[i][2]);
  end loop;
  execute d;
end;
$$;

-- Members see whether a week is included.
do $$
declare d text := pg_get_functiondef('public.circle_snapshot_before_moves()'::regprocedure);
begin
  if position('''included'',e.included' in d) = 0 then
    if position('''cost_notes'',e.cost_notes,' in d) = 0 then raise exception 'meetup included patch did not apply'; end if;
    execute replace(d, '''cost_notes'',e.cost_notes,', '''cost_notes'',e.cost_notes,''included'',e.included,');
  end if;
end;
$$;

-- 3. Members plan week 5 only ---------------------------------------------------------------
-- The member path differs between databases (some versions also move the
-- date and time), so only the week number changes here; the top of
-- circle_action checks week 5 and saves its time itself.
do $$
declare d text := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
begin
  if position('circle_week>=5' in d) > 0 then
    d := replace(d, 'circle_week>=5', 'circle_week=5');
    d := replace(d, 'Only upcoming weeks 5 and 6 can be changed by members.', 'Only week 5 is yours to plan. We book the other weeks.');
    execute d;
  elsif position('circle_week=5' in d) = 0 then
    raise exception 'week 5 patch did not apply';
  end if;
end;
$$;

-- 5. Places and how to book them ------------------------------------------------------------
create table if not exists public.circle_venues (
  id uuid primary key default gen_random_uuid(),
  city text not null default 'Alkmaar' check (length(city) between 1 and 80),
  name text not null check (length(name) between 1 and 180),
  address text check (address is null or length(address) <= 200),
  booking text not null check (booking in ('online', 'email', 'phone')),
  booking_url text check (booking_url is null or (booking_url like 'https://%' and length(booking_url) <= 500)),
  booking_email text check (booking_email is null or booking_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  booking_phone text check (booking_phone is null or length(booking_phone) <= 40),
  unique (city, name)
);
alter table public.circle_venues enable row level security;

insert into public.circle_venues(city, name, address, booking, booking_url, booking_email, booking_phone) values
  ('Alkmaar', 'Hofman', 'Kerkplein 7', 'online', 'https://www.hofman-alkmaar.nl/reserveren', 'info@hofman-alkmaar.nl', '072 582 3612'),
  ('Alkmaar', 'Rozey Alkmaar', 'Gedempte Nieuwesloot 4B', 'online', 'https://rozey.nl/rozey-alkmaar', 'alkmaar@rozey.nl', '072 220 3961'),
  ('Alkmaar', '1480 Foodbar', 'Mient 16', 'online', 'https://www.1480foodbar.nl/', 'bar@1480foodbar.nl', '072 241 0099'),
  ('Alkmaar', 'Grand Café Klunder', 'Canadaplein 2', 'online', 'https://grandcafeklunder.nl/reserveren/', 'reserveringen@grandcafeklunder.nl', '072 548 9898'),
  ('Alkmaar', 'Soepp', 'Hekelstraat 31', 'online', 'https://soepp.nl/', 'info@soepp.nl', '072 220 2061'),
  ('Alkmaar', 'The Hangout', 'Kwakelkade 10', 'online', 'https://booking.thehangout.nl/', 'events@thehangout.nl', '072 202 9799'),
  ('Alkmaar', 'Hollands Kaasmuseum', 'Waagplein 2', 'online', 'https://www.kaasmuseum.nl/openingstijden-prijzen', 'info@kaasmuseum.nl', '072 515 5516'),
  ('Alkmaar', 'The Boules Club', 'Noorderkade 108', 'email', 'https://theboulesclub.com/alkmaar/', 'reserveringen.alkmaar@theboulesclub.com', '072 202 9779'),
  ('Alkmaar', 'De Spellentoren', 'Schoutenstraat 28', 'email', null, 'info@despellentoren.nl', '072 220 3100'),
  ('Alkmaar', 'Miss Central', 'Laat 183', 'online', 'https://www.misscentral.nl', null, null),
  ('Alkmaar', 'Anne&Max', 'Kraanbuurt 3', 'online', 'https://www.annemax.nl/vestigingen/vestigingen-alkmaar/', null, null),
  ('Alkmaar', 'Jonas Bistro Bar', 'Zevenhuizen 11', 'online', 'https://www.jonasalkmaar.nl/', null, '072 520 0079'),
  ('Alkmaar', 'De Binnenkomer', 'Kerkplein 6', 'phone', null, null, '072 582 2655'),
  ('Alkmaar', 'Het Alkmaars Koffiehuis', 'Gedempte Nieuwesloot 42', 'phone', null, null, '072 531 8712')
on conflict (city, name) do update
  set address = excluded.address, booking = excluded.booking, booking_url = excluded.booking_url,
      booking_email = excluded.booking_email, booking_phone = excluded.booking_phone;

create table if not exists public.circle_venue_emails (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  to_email text not null,
  subject text not null,
  body text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  leased_at timestamptz,
  sent_at timestamptz,
  attempts integer not null default 0,
  last_error text
);
alter table public.circle_venue_emails enable row level security;

-- The email worker takes a few at a time and reports back.
create or replace function public.venue_emails_pending(max_rows integer default 10)
returns table(id uuid, to_email text, subject text, body text)
language sql
security definer
set search_path = public
as $$
  update public.circle_venue_emails v
     set leased_at = now(), attempts = v.attempts + 1
   where v.id in (select x.id from public.circle_venue_emails x
                   where x.sent_at is null and x.attempts < 3
                     and (x.leased_at is null or x.leased_at < now() - interval '5 minutes')
                   order by x.created_at limit greatest(1, least(max_rows, 25))
                   for update skip locked)
  returning v.id, v.to_email, v.subject, v.body;
$$;
create or replace function public.ack_venue_email(email_id uuid, failure text default null)
returns void
language sql
security definer
set search_path = public
as $$
  update public.circle_venue_emails
     set sent_at = case when failure is null then now() end,
         last_error = left(failure, 300), leased_at = null
   where id = email_id;
$$;
revoke all on function public.venue_emails_pending(integer) from public, anon, authenticated;
revoke all on function public.ack_venue_email(uuid, text) from public, anon, authenticated;
grant execute on function public.venue_emails_pending(integer) to service_role;
grant execute on function public.ack_venue_email(uuid, text) to service_role;

-- The booking email, in Dutch: venues here read Dutch.
create or replace function public.circle_booking_email(e public.events)
returns table(subject text, body text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  t timestamp := e.starts_at at time zone 'Europe/Amsterdam';
  u timestamp := e.ends_at at time zone 'Europe/Amsterdam';
  day_text text := (array['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'])[extract(isodow from t)::int]
              || ' ' || extract(day from t)::int || ' '
              || (array['januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus',
                        'september', 'oktober', 'november', 'december'])[extract(month from t)::int];
  people int := (select count(*) from public.circle_memberships m
                  where m.circle_id = e.circle_id and m.status <> 'left');
  booked_as text := coalesce(nullif(trim(e.booking_name), ''), (select c.name from public.circles c where c.id = e.circle_id), 'VriendTime');
  organiser text := (select p.first_name from public.profiles p where p.id = auth.uid());
begin
  subject := 'Reservering voor ' || people || ' personen op ' || day_text || ' om ' || to_char(t, 'HH24:MI');
  body := 'Beste team van ' || coalesce(e.venue_name, 'jullie zaak') || ',' || E'\n\n'
       || 'Graag reserveren we voor ' || people || ' personen op ' || day_text
       || ' van ' || to_char(t, 'HH24:MI') || ' tot ' || to_char(u, 'HH24:MI')
       || ', op naam van “' || booked_as || '”.' || E'\n\n'
       || 'Het gaat om een groepje van VriendTime: mensen die elkaar zes weken lang leren kennen.'
       || case when e.included then ' Wij betalen deze activiteit vooraf; stuurt u ons daarvoor een factuur of betaallink?' else '' end
       || E'\n\n' || 'Wilt u de reservering bevestigen door op deze e-mail te antwoorden?' || E'\n\n'
       || 'Alvast bedankt!' || E'\n\n' || 'Met vriendelijke groet,' || E'\n'
       || coalesce(organiser || E'\n', '') || 'VriendTime · support@vriendtime.com';
  return next;
end;
$$;
revoke all on function public.circle_booking_email(public.events) from public, anon, authenticated;

-- The top of circle_action: week 5 rules and booking -----------------------------------
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_action_before_plans') then
    alter function public.circle_action(text, jsonb) rename to circle_action_before_plans;
  end if;
end;
$$;
revoke all on function public.circle_action_before_plans(text, jsonb) from public, anon, authenticated;

create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  e public.events;
  v public.circle_venues;
  mail record;
  start_d date;
  start_t time;
  lo time; hi time;
begin
  if action = 'schedule' and nullif(payload->>'id', '') is not null and not public.circle_is_admin() then
    select * into e from public.events where id = (payload->>'id')::uuid;
    if e.id is not null and e.circle_week is not null then
      if e.circle_week <> 5 then
        raise exception 'Only week 5 is yours to plan. We book the other weeks.';
      end if;
      -- Week 5 keeps its day; the group chooses the start.
      start_d := (e.starts_at at time zone 'Europe/Amsterdam')::date;
      start_t := nullif(payload->>'time', '')::time;
      if start_t is null then
        null;
      -- A start in the group's part of the day.
      elsif extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 17 then
        lo := '18:00'; hi := '21:00';
        if start_t not between lo and hi then raise exception 'Choose a start between 18:00 and 21:00.'; end if;
      elsif extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 12 then
        lo := '12:00'; hi := '16:00';
        if start_t not between lo and hi then raise exception 'Choose a start between 12:00 and 16:00.'; end if;
      else
        lo := '09:00'; hi := '11:30';
        if start_t not between lo and hi then raise exception 'Choose a start between 09:00 and 11:30.'; end if;
      end if;
    end if;
  elsif action = 'admin_booking' then
    if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
    select * into e from public.events where id = nullif(payload->>'id', '')::uuid;
    if e.id is null or e.circle_id is null then raise exception 'Meetup not found.'; end if;
    if payload->>'step' = 'booked' then
      update public.events set booking_status = 'booked' where id = e.id;
    elsif payload->>'step' = 'clear' then
      update public.events set booking_status = null, booking_requested_at = null where id = e.id;
    elsif payload->>'step' = 'email' then
      if e.starts_at <= now() then raise exception 'This meetup has already started.'; end if;
      select vv.* into v from public.circle_venues vv
        join public.circles c on c.id = e.circle_id
       where vv.city = c.city and lower(vv.name) = lower(trim(coalesce(e.venue_name, '')));
      if v.booking_email is null then
        raise exception 'This place has no booking email. Book it online or by phone.';
      end if;
      if e.booking_requested_at is not null and coalesce((payload->>'again')::boolean, false) = false then
        raise exception 'A booking email was already sent for this week.';
      end if;
      select * into mail from public.circle_booking_email(e);
      insert into public.circle_venue_emails(event_id, to_email, subject, body, created_by)
      values (e.id, v.booking_email, mail.subject, mail.body, uid);
      update public.events set booking_status = 'requested', booking_requested_at = now() where id = e.id;
    else
      raise exception 'Unknown booking step.';
    end if;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, e.id);
    return;
  end if;
  perform public.circle_action_before_plans(action, payload);
  -- Week 5's chosen start, saved the same way in every database version.
  if start_t is not null and e.id is not null then
    update public.events
       set starts_at = (start_d + start_t) at time zone 'Europe/Amsterdam',
           ends_at = public.circle_window_end((start_d + start_t) at time zone 'Europe/Amsterdam')
     where id = e.id;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Organisers see how each place is booked, and each week's booking state.
do $$
declare d text := pg_get_functiondef('public.circle_admin_snapshot_core()'::regprocedure);
begin
  if position('''booking_status'',e.booking_status' in d) = 0 then
    if position('''venue'',e.venue_name,''attendees''' in d) = 0 then raise exception 'organiser meetup patch did not apply'; end if;
    execute replace(d, '''venue'',e.venue_name,''attendees''',
      '''venue'',e.venue_name,''booking_status'',e.booking_status,''booking_requested_at'',e.booking_requested_at,''included'',e.included,''starts_at'',e.starts_at,''ends_at'',e.ends_at,''attendees''');
  end if;
  d := pg_get_functiondef('public.circle_admin_snapshot_before_details()'::regprocedure);
  if position('''venues''' in d) = 0 then
    if position('''coffee_places'', coalesce(' in d) = 0 then raise exception 'organiser venues patch did not apply'; end if;
    execute replace(d, '''coffee_places'', coalesce(',
      '''venues'', coalesce((select jsonb_agg(to_jsonb(vv) order by vv.city, vv.name) from public.circle_venues vv), ''[]''::jsonb),
    ''coffee_places'', coalesce(');
  end if;
end;
$$;

-- 4. VriendTime messages in the group chat -------------------------------------------------
alter table public.messages add column if not exists kind text not null default 'member';
alter table public.messages alter column sender_id drop not null;
alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('member', 'system') and (kind = 'system') = (sender_id is null));

do $$
declare d text;
begin
  -- System messages skip the member checks; only SQL inside the app writes them.
  d := pg_get_functiondef('public.guard_circle_message()'::regprocedure);
  if position('new.kind' in d) = 0 then
    if position('  if cid is not null then' in d) = 0 then raise exception 'message guard patch did not apply'; end if;
    execute replace(d, '  if cid is not null then', '  if cid is not null and new.kind = ''member'' then');
  end if;
  -- Members' chat and older pages: VriendTime has no profile.
  d := pg_get_functiondef('public.circle_snapshot_core()'::regprocedure);
  if position('msg.kind' in d) = 0 then
    if position('''name'',coalesce(p.first_name,''Member''),''body'',msg.body,''own'',msg.sender_id=uid) item from public.messages msg join public.chat_threads t on t.id=msg.thread_id join public.profiles p on p.id=msg.sender_id' in d) = 0 then
      raise exception 'chat snapshot patch did not apply';
    end if;
    execute replace(d,
      '''name'',coalesce(p.first_name,''Member''),''body'',msg.body,''own'',msg.sender_id=uid) item from public.messages msg join public.chat_threads t on t.id=msg.thread_id join public.profiles p on p.id=msg.sender_id',
      '''name'',case when msg.kind=''system'' then ''VriendTime'' else coalesce(p.first_name,''Member'') end,''body'',msg.body,''own'',coalesce(msg.sender_id=uid,false),''system'',msg.kind=''system'') item from public.messages msg join public.chat_threads t on t.id=msg.thread_id left join public.profiles p on p.id=msg.sender_id');
  end if;
  d := pg_get_functiondef('public.circle_messages_before(timestamptz, uuid)'::regprocedure);
  if position('msg.kind' in d) = 0 then
    if position('''name'',p.first_name,''body'',msg.body,''own'',msg.sender_id=auth.uid()) item' in d) = 0
       or position('join public.profiles p on p.id=msg.sender_id' in d) = 0 then
      raise exception 'chat paging patch did not apply';
    end if;
    d := replace(d, '''name'',p.first_name,''body'',msg.body,''own'',msg.sender_id=auth.uid()) item',
      '''name'',case when msg.kind=''system'' then ''VriendTime'' else p.first_name end,''body'',msg.body,''own'',coalesce(msg.sender_id=auth.uid(),false),''system'',msg.kind=''system'') item');
    execute replace(d, 'join public.profiles p on p.id=msg.sender_id', 'left join public.profiles p on p.id=msg.sender_id');
  end if;
  d := pg_get_functiondef('public.circle_admin_messages(uuid)'::regprocedure);
  if position('msg.kind' in d) = 0 then
    if position('''name'', coalesce(p.first_name, ''Member''), ''body'', msg.body)' in d) = 0 then
      raise exception 'organiser chat patch did not apply';
    end if;
    execute replace(d, '''name'', coalesce(p.first_name, ''Member''), ''body'', msg.body)',
      '''name'', case when msg.kind = ''system'' then ''VriendTime'' else coalesce(p.first_name, ''Member'') end, ''body'', msg.body, ''system'', msg.kind = ''system'')');
  end if;
end;
$$;

-- Housekeeping: week 5 is the group's own; week 6 is ours -----------------------------------
create or replace function public.queue_meetup_housekeeping()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare n integer := 0; added integer;
begin
  update public.events
     set completed_at = ends_at
   where circle_id is not null and circle_week is not null
     and completed_at is null and status <> 'cancelled'
     and ends_at < now() - interval '24 hours';
  get diagnostics added = row_count; n := n + added;

  update public.circles c set status = 'completed'
   where c.status = 'active'
     and (select count(*) from public.events e
           where e.circle_id = c.id and e.circle_week is not null and e.completed_at is not null) >= 6
     -- The week after the last meetup is for one-to-ones; the Circle ends after it.
     and not exists (select 1 from public.events e
                      where e.circle_id = c.id and e.circle_week is not null and e.status <> 'cancelled'
                        and e.ends_at > now() - interval '7 days');

  -- A week we book that still has no place, three days ahead.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'A meetup has no place yet',
         c.name || ' · week ' || e.circle_week || ' on '
           || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': add the place so members know where to go.',
         'no-venue:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status in ('offered', 'active') and e.circle_week between 1 and 6 and e.circle_week <> 5
     and e.status <> 'cancelled' and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Week 5, a week ahead: it's the group's call.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, e.id, 'reminder', 'Week 5 is your call',
         'Week 5 of ' || c.name || ' is on ' || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || '. Choose together what to do, where, and a start between '
           || case when extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 17 then '18:00 and 21:00'
                   when extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 12 then '12:00 and 16:00'
                   else '09:00 and 11:30' end
           || '. Talk it over in the chat, then save it in the app.',
         'week5:' || e.id || ':' || m.profile_id,
         jsonb_build_object('open', 'meetup:' || e.id)
    from public.events e
    join public.circles c on c.id = e.circle_id
    join public.circle_memberships m on m.circle_id = e.circle_id and m.status = 'joined'
   where c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
     and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '7 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Five days ahead, still open: a word from VriendTime in the group chat.
  with due as (
    update public.events e set group_nudged_at = now()
      from public.circles c
     where c.id = e.circle_id and c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
       and e.group_nudged_at is null and coalesce(trim(e.venue_name), '') = ''
       and e.starts_at > now() and e.starts_at <= now() + interval '5 days'
    returning e.circle_id)
  insert into public.messages(thread_id, sender_id, body, kind)
  select t.id, null,
         'Week 5 is your call! Share ideas here, then tap “Plan it” on the week 5 card to set the place and the time.',
         'system'
    from due join public.chat_threads t on t.circle_id = due.circle_id and t.kind = 'group';
  get diagnostics added = row_count; n := n + added;

  -- Three days ahead, still open: the organiser books something.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'Week 5 has no plan yet',
         c.name || ' · week 5 on ' || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': the group hasn’t planned it. Check the chat, or book something for them.',
         'week5-open:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
     and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_meetup_housekeeping() from public, anon, authenticated;

-- The email worker also runs when a booking email waits.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron')
     and exists (select 1 from pg_namespace where nspname = 'net') then
    perform cron.schedule('vriendtime-send-emails', '*/10 * * * *', $cron$
      select net.http_post(
        url := 'https://sageyiqyvzgoayehahyq.supabase.co/functions/v1/send-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets
                             where name = 'notification_cron_secret')),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000)
      where exists (select 1 from public.notifications
                     where emailed_at is null and email_attempts < 5
                       and created_at > now() - interval '3 days'
                       and (email_retry_at is null or email_retry_at <= now()))
         or exists (select 1 from public.circle_venue_emails
                     where sent_at is null and attempts < 3);
    $cron$);
  end if;
end;
$$;
