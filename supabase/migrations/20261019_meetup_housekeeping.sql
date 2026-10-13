-- Meetups that look after themselves.
--
-- 1. A meetup counts as done three hours after it ends, without the organiser
--    having to tap "Mark completed"; after the sixth, the Circle is finished.
--    (Check-ins, the week counter and graduation all depend on this.)
-- 2. Organisers hear when one of the weeks they plan (1–3) has no place yet,
--    three days before.
-- 3. Members hear when week 4, 5 or 6 has no plan yet, six days before.
-- 4. The organiser panel shows how many are coming to each meetup.
-- 5. Notifications may bring their own destination.
begin;

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
     and ends_at < now() - interval '3 hours';
  get diagnostics added = row_count; n := n + added;

  update public.circles c set status = 'completed'
   where c.status = 'active'
     and (select count(*) from public.events e
           where e.circle_id = c.id and e.circle_week is not null and e.completed_at is not null) >= 6;

  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'A meetup has no place yet',
         c.name || ' · week ' || e.circle_week || ' on '
           || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': add the place so members can see it the day before.',
         'no-venue:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status in ('offered', 'active') and e.circle_week between 1 and 3
     and e.status <> 'cancelled' and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, e.id, 'reminder', 'Week ' || e.circle_week || ' needs a plan',
         'Nobody has planned week ' || e.circle_week || ' of ' || c.name
           || ' yet. Pick an activity and a place together in the app.',
         'needs-plan:' || e.id || ':' || m.profile_id,
         jsonb_build_object('open', 'meetup:' || e.id)
    from public.events e
    join public.circles c on c.id = e.circle_id
    join public.circle_memberships m on m.circle_id = e.circle_id and m.status = 'joined'
   where c.status = 'active' and e.circle_week between 4 and 6
     and e.status <> 'cancelled' and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '6 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_meetup_housekeeping() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-meetup-housekeeping', '5 * * * *',
                          'select public.queue_meetup_housekeeping();');
  end if;
end;
$$;

-- A destination given by the sender wins over the default one.
do $$
declare d text := pg_get_functiondef('public.circle_notification_copy()'::regprocedure);
begin
  d := replace(d,
    'new.metadata := coalesce(new.metadata, ''{}''::jsonb) || jsonb_build_object(''open'', dest);',
    'new.metadata := jsonb_build_object(''open'', dest) || coalesce(new.metadata, ''{}''::jsonb);');
  if position('jsonb_build_object(''open'', dest) || coalesce' in d) = 0 then
    raise exception 'notification copy patch did not apply';
  end if;
  execute d;
end;
$$;

-- Organiser snapshot: how many are coming to each meetup.
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_going;
revoke all on function public.circle_admin_snapshot_before_going() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_admin_snapshot_before_going();
begin
  return result || jsonb_build_object('circles', coalesce((
    select jsonb_agg(c || jsonb_build_object('meetups', coalesce((
             select jsonb_agg(m || jsonb_build_object('going', (
                      select count(*) from public.event_attendees ea
                       where ea.event_id = (m->>'id')::uuid and ea.status = 'joined'))
                    order by mo)
               from jsonb_array_elements(coalesce(c->'meetups', '[]'::jsonb)) with ordinality t2(m, mo)),
             '[]'::jsonb)) order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)),
    '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

commit;
