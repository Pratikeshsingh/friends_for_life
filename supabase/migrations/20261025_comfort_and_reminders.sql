-- Small things that make showing up easier.
--
-- 1. A reminder on the morning of a one-to-one coffee (08:00, Netherlands
--    time): "Coffee with Anna today".
-- 2. The name a table is booked under, per week ("VriendTime" by default),
--    shown to members on the meetup.
-- 3. One optional tap in the existing check-in: "Would you go back to this
--    place?" Organisers see the tally per meetup.
-- 4. The daytime week-2 suggestion is a café, not a walk.
begin;

-- 1. Coffee reminders ------------------------------------------------------------------
create or replace function public.queue_coffee_reminders(force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare added integer;
begin
  if not force and extract(hour from now() at time zone 'Europe/Amsterdam') <> 8 then return 0; end if;
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
  select p.id, 'reminder', 'Coffee with ' || coalesce(o.first_name, 'your match') || ' today',
         to_char(k.starts_at at time zone 'Europe/Amsterdam', 'HH24:MI') || ' at ' || k.place
           || '. Running late? Say so in the group chat.',
         'coffee-today:' || k.id || ':' || p.id, jsonb_build_object('open', 'home')
    from public.circle_coffees k
    cross join lateral (values (k.a, k.b), (k.b, k.a)) v(me, other)
    join public.profiles p on p.id = v.me
    join public.profiles o on o.id = v.other
   where k.status = 'confirmed'
     and (k.starts_at at time zone 'Europe/Amsterdam')::date = (now() at time zone 'Europe/Amsterdam')::date
     and k.starts_at > now()
  on conflict do nothing;
  get diagnostics added = row_count;
  return added;
end;
$$;
revoke all on function public.queue_coffee_reminders(boolean) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-coffee-reminders', '0 * * * *', 'select public.queue_coffee_reminders();');
  end if;
end;
$$;

-- 2. Booking name -------------------------------------------------------------------------
alter table public.events add column if not exists booking_name text
  check (booking_name is null or length(booking_name) <= 120);
alter table public.circle_programme_template add column if not exists booking_name text
  check (booking_name is null or length(booking_name) <= 120);
update public.circle_programme_template set booking_name = 'VriendTime' where booking_name is null;

do $$
declare d text := pg_get_functiondef('public.circle_action_before_coffee(text, jsonb)'::regprocedure);
begin
  -- Creating a Circle: the plan carries the booking name per week.
  d := replace(d, 'cost_notes = nullif(left(trim(coalesce(w->>''cost'', '''')), 300), ''''), updated_by = uid',
                  'cost_notes = nullif(left(trim(coalesce(w->>''cost'', '''')), 300), ''''),
           booking_name = nullif(left(trim(coalesce(w->>''booking'', '''')), 120), ''''), updated_by = uid');
  -- The saved suggestions carry it too.
  d := replace(d, '''title'', t.title, ''venue'', t.venue, ''address'', t.address, ''cost'', t.cost)',
                  '''title'', t.title, ''venue'', t.venue, ''address'', t.address, ''cost'', t.cost, ''booking'', t.booking_name)');
  d := replace(d, 'insert into public.circle_programme_template(city, kind, week, title, venue, address, cost)',
                  'insert into public.circle_programme_template(city, kind, week, title, venue, address, cost, booking_name)');
  d := replace(d, 'nullif(left(trim(coalesce(w->>''cost'', '''')), 300), '''')
      from jsonb_array_elements',
                  'nullif(left(trim(coalesce(w->>''cost'', '''')), 300), ''''),
           nullif(left(trim(coalesce(w->>''booking'', '''')), 120), '''')
      from jsonb_array_elements');
  d := replace(d, 'set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost;',
                  'set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost,
          booking_name = excluded.booking_name;');
  if (length(d) - length(replace(d, 'booking', ''))) / length('booking') < 7 then
    raise exception 'booking name patch did not apply';
  end if;
  execute d;
end;
$$;

-- 3. "Would you go back?" ----------------------------------------------------------------
alter table public.circle_check_ins add column if not exists go_back boolean;

-- Editing a week's booking name, and the optional answer in the check-in.
alter function public.circle_action(text, jsonb) rename to circle_action_before_details;
revoke all on function public.circle_action_before_details(text, jsonb) from public, anon, authenticated;

create function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  perform public.circle_action_before_details(action, payload - 'go_back' - 'booking');
  if action = 'check_in' and jsonb_typeof(payload->'go_back') = 'boolean' then
    update public.circle_check_ins set go_back = (payload->>'go_back')::boolean
     where profile_id = uid and event_id = nullif(payload->>'id', '')::uuid;
  elsif action = 'admin_schedule' and payload ? 'booking' and public.circle_is_admin() then
    update public.events set booking_name = nullif(left(trim(payload->>'booking'), 120), '')
     where id = nullif(payload->>'id', '')::uuid and circle_id is not null;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Members see the booking name on their meetups.
alter function public.circle_snapshot() rename to circle_snapshot_before_details;
revoke all on function public.circle_snapshot_before_details() from public, anon, authenticated;

create function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb := public.circle_snapshot_before_details();
begin
  if jsonb_typeof(result->'meetups') <> 'array' then return result; end if;
  return result || jsonb_build_object('meetups', coalesce((
    select jsonb_agg(m || jsonb_build_object('booking_name', e.booking_name) order by ord)
      from jsonb_array_elements(result->'meetups') with ordinality t(m, ord)
      left join public.events e on e.id::text = m->>'id'), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Organisers see the booking name and the "would go back" tally per meetup.
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_details;
revoke all on function public.circle_admin_snapshot_before_details() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb := public.circle_admin_snapshot_before_details();
begin
  return result || jsonb_build_object('circles', coalesce((
    select jsonb_agg(c || jsonb_build_object('meetups', coalesce((
             select jsonb_agg(m || jsonb_build_object(
                      'booking_name', e.booking_name,
                      'go_back_yes', (select count(*) from public.circle_check_ins ci where ci.event_id = e.id and ci.go_back),
                      'go_back_no', (select count(*) from public.circle_check_ins ci where ci.event_id = e.id and not ci.go_back))
                    order by mo)
               from jsonb_array_elements(coalesce(c->'meetups', '[]'::jsonb)) with ordinality t2(m, mo)
               left join public.events e on e.id::text = m->>'id'),
             '[]'::jsonb)) order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)),
    '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- 4. A café, not a walk ------------------------------------------------------------------
update public.circle_programme_template
   set title = 'Coffee and a good conversation'
 where kind = 'daytime' and week = 2 and title = 'Coffee and a walk';

commit;
