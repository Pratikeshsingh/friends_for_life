-- Release hardening migration for VriendTime.
-- Run this after supabase/schema.sql in the Supabase SQL editor.

-- Exact venues always release at 10:00 Europe/Amsterdam on the calendar day
-- before starts_at. events.reveal_venue_at is retained for compatibility but
-- is intentionally not consulted by any release or notification function.
create or replace function public.event_venue_release_at(
  event_starts_at timestamptz
)
returns timestamptz
language sql
stable
strict
set search_path = pg_catalog
as $$
  select (
    ((event_starts_at at time zone 'Europe/Amsterdam')::date - 1)
      + time '10:00'
  ) at time zone 'Europe/Amsterdam';
$$;

revoke all on function public.event_venue_release_at(timestamptz) from public;
grant execute on function public.event_venue_release_at(timestamptz) to service_role;

-- 1) Expose event catalog data without exact venue address fields.
create or replace view public.event_catalog as
select
  id,
  title,
  subtitle,
  description,
  city,
  venue_area,
  reveal_venue_at,
  starts_at,
  ends_at,
  status,
  activity_type,
  vibe,
  minimum_attendees,
  confirmed_count,
  capacity,
  image_url,
  tags,
  languages
from public.events
where status in ('open', 'full', 'closed');

grant select on public.event_catalog to anon, authenticated;
revoke select on public.events from public, anon, authenticated;

-- 2) Stop exposing account-existence checks to public clients.
revoke execute on function public.email_exists(text) from anon, authenticated;

-- 3) Helper used by the app instead of joining through public.events.
create or replace function public.has_attended_meetup()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events e
    join public.event_attendees attendee
      on attendee.event_id = e.id
    where attendee.profile_id = auth.uid()
      and attendee.status = 'joined'
      and e.starts_at < timezone('utc', now())
  );
$$;

revoke all on function public.has_attended_meetup() from public;
grant execute on function public.has_attended_meetup() to authenticated;

-- 4) Queue exact-address notifications after release. This is safe to call
-- repeatedly: the recipient + dedupe_key unique index makes it idempotent.
create or replace function public.queue_event_notifications(
  target_event_id uuid,
  run_at timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  effective_run_at timestamptz := coalesce(run_at, now());
  queued_count integer := 0;
begin
  with due_event as (
    select
      e.id,
      e.title,
      e.city,
      e.starts_at,
      public.event_venue_release_at(e.starts_at) as released_at,
      nullif(btrim(e.venue_name), '') as venue_name,
      nullif(btrim(e.venue_address), '') as venue_address
    from public.events e
    where e.id = target_event_id
      and e.status in ('open', 'full', 'closed')
      and e.starts_at > effective_run_at
      and public.event_venue_release_at(e.starts_at) <= effective_run_at
  ),
  inserted as (
    insert into public.notifications (
      recipient_profile_id,
      event_id,
      kind,
      title,
      body,
      dedupe_key,
      metadata
    )
    select
      attendee.profile_id,
      due_event.id,
      'address',
      'Address ready: ' || due_event.title,
      'Your VriendTime meetup address is ready.' || E'\n' ||
        coalesce(due_event.venue_name || E'\n', '') ||
        due_event.venue_address,
      'event:' || due_event.id::text || ':address',
      jsonb_build_object(
        'venue_name', due_event.venue_name,
        'address', due_event.venue_address,
        'city', due_event.city,
        'starts_at', due_event.starts_at,
        'released_at', due_event.released_at
      )
    from due_event
    join public.event_attendees attendee
      on attendee.event_id = due_event.id
    where attendee.status = 'joined'
      and due_event.venue_address is not null
    on conflict do nothing
    returning 1
  )
  select count(*)::integer
  into queued_count
  from inserted;

  return queued_count;
end;
$$;

create or replace function public.queue_due_event_notifications(
  run_at timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  effective_run_at timestamptz := coalesce(run_at, now());
  event_row record;
  queued_count integer := 0;
begin
  for event_row in
    select e.id
    from public.events e
    where e.status in ('open', 'full', 'closed')
      and e.starts_at > effective_run_at
      and nullif(btrim(e.venue_address), '') is not null
      and public.event_venue_release_at(e.starts_at) <= effective_run_at
  loop
    queued_count := queued_count
      + public.queue_event_notifications(event_row.id, effective_run_at);
  end loop;

  return queued_count;
end;
$$;

create or replace function public.queue_due_notifications_for_joined_attendee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'joined'
    and (
      tg_op = 'INSERT'
      or old.status is distinct from new.status
    ) then
    perform public.queue_event_notifications(new.event_id, now());
  end if;

  return new;
end;
$$;

-- Secure address read path. The catalog never exposes exact venue columns;
-- this RPC returns them only to a joined attendee after the release instant.
create or replace function public.get_revealed_event_venues(
  target_event_id uuid default null
)
returns table (
  event_id uuid,
  venue_name text,
  venue_address text,
  city text,
  released_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_profile_id uuid := auth.uid();
begin
  if current_profile_id is null then
    raise exception 'Not authenticated.';
  end if;

  return query
  select
    e.id,
    nullif(btrim(e.venue_name), ''),
    btrim(e.venue_address),
    e.city,
    public.event_venue_release_at(e.starts_at)
  from public.events e
  join public.event_attendees attendee
    on attendee.event_id = e.id
  where attendee.profile_id = current_profile_id
    and attendee.status = 'joined'
    and e.status in ('open', 'full', 'closed')
    and e.starts_at > now()
    and (target_event_id is null or e.id = target_event_id)
    and nullif(btrim(e.venue_address), '') is not null
    and public.event_venue_release_at(e.starts_at) <= now()
  order by e.starts_at;
end;
$$;

revoke all on function public.queue_event_notifications(uuid, timestamptz) from public;
revoke all on function public.queue_due_event_notifications(timestamptz) from public;
revoke all on function public.queue_due_notifications_for_joined_attendee() from public;
revoke all on function public.get_revealed_event_venues(uuid) from public;
grant execute on function public.queue_event_notifications(uuid, timestamptz) to service_role;
grant execute on function public.queue_due_event_notifications(timestamptz) to service_role;
grant execute on function public.queue_due_notifications_for_joined_attendee() to service_role;
grant execute on function public.get_revealed_event_venues(uuid) to authenticated;

drop trigger if exists event_attendees_queue_due_notifications on public.event_attendees;
create trigger event_attendees_queue_due_notifications
after insert or update on public.event_attendees
for each row
execute function public.queue_due_notifications_for_joined_attendee();

-- Deployment: invoke queue_due_event_notifications(now()) at least every five
-- minutes from Supabase Cron. The timezone calculation remains DST-safe.

-- 5) Transactional reservation entry point.
create or replace function public.reserve_event(target_event_id uuid)
returns public.event_attendees
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile_id uuid := auth.uid();
  event_row public.events%rowtype;
  joined_count integer;
  active_reservation_count integer;
  attendee_row public.event_attendees%rowtype;
begin
  if current_profile_id is null then
    raise exception 'Not authenticated.';
  end if;

  select *
  into event_row
  from public.events
  where id = target_event_id
  for update;

  if not found then
    raise exception 'Meetup not found.';
  end if;

  if event_row.status <> 'open' then
    raise exception 'This meetup is not open for reservations.';
  end if;

  if event_row.starts_at <= timezone('utc', now()) then
    raise exception 'This meetup has already started.';
  end if;

  select count(*)::integer
  into joined_count
  from public.event_attendees
  where event_id = target_event_id
    and status = 'joined';

  if joined_count >= event_row.capacity then
    update public.events
    set status = 'full'
    where id = target_event_id
      and status = 'open';

    raise exception 'This meetup is full.';
  end if;

  if exists (
    select 1
    from public.event_attendees attendee
    join public.events existing_event
      on existing_event.id = attendee.event_id
    where attendee.profile_id = current_profile_id
      and attendee.status = 'joined'
      and existing_event.id <> target_event_id
      and existing_event.starts_at > timezone('utc', now())
      and existing_event.starts_at::date = event_row.starts_at::date
  ) then
    raise exception 'You already have a meetup on this day.';
  end if;

  if exists (
    select 1
    from public.event_attendees attendee
    join public.events existing_event
      on existing_event.id = attendee.event_id
    where attendee.profile_id = current_profile_id
      and attendee.status = 'joined'
      and existing_event.id <> target_event_id
      and existing_event.starts_at > timezone('utc', now())
      and existing_event.starts_at < coalesce(event_row.ends_at, event_row.starts_at + interval '2 hours')
      and event_row.starts_at < coalesce(existing_event.ends_at, existing_event.starts_at + interval '2 hours')
  ) then
    raise exception 'This meetup overlaps with one you already chose.';
  end if;

  select count(*)::integer
  into active_reservation_count
  from public.event_attendees attendee
  join public.events existing_event
    on existing_event.id = attendee.event_id
  where attendee.profile_id = current_profile_id
    and attendee.status = 'joined'
    and existing_event.starts_at > timezone('utc', now())
    and existing_event.id <> target_event_id;

  if active_reservation_count >= 3 then
    raise exception 'You can choose up to three upcoming meetups.';
  end if;

  insert into public.event_attendees (
    event_id,
    profile_id,
    status,
    joined_at
  )
  values (
    target_event_id,
    current_profile_id,
    'joined',
    timezone('utc', now())
  )
  on conflict (event_id, profile_id) do update
  set
    status = 'joined',
    joined_at = excluded.joined_at
  returning * into attendee_row;

  select count(*)::integer
  into joined_count
  from public.event_attendees
  where event_id = target_event_id
    and status = 'joined';

  if joined_count >= event_row.capacity then
    update public.events
    set status = 'full'
    where id = target_event_id
      and status = 'open';
  end if;

  -- The attendee trigger handles new joins. This second idempotent call also
  -- repairs a missing notification when an already-joined member retries.
  perform public.queue_event_notifications(target_event_id, now());

  return attendee_row;
end;
$$;

revoke all on function public.reserve_event(uuid) from public;
grant execute on function public.reserve_event(uuid) to authenticated;

-- 6) Transactional cancellation entry point.
create or replace function public.cancel_event_reservation(target_event_id uuid)
returns public.event_attendees
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile_id uuid := auth.uid();
  event_row public.events%rowtype;
  attendee_row public.event_attendees%rowtype;
begin
  if current_profile_id is null then
    raise exception 'Not authenticated.';
  end if;

  select *
  into event_row
  from public.events
  where id = target_event_id
  for update;

  if not found then
    raise exception 'Meetup not found.';
  end if;

  if event_row.starts_at <= timezone('utc', now()) + interval '12 hours' then
    raise exception 'Cancellations close 12 hours before the meetup starts.';
  end if;

  update public.event_attendees
  set status = 'cancelled'
  where event_id = target_event_id
    and profile_id = current_profile_id
    and status = 'joined'
  returning * into attendee_row;

  if not found then
    raise exception 'No active reservation found.';
  end if;

  update public.events
  set status = 'open'
  where id = target_event_id
    and status = 'full'
    and starts_at > timezone('utc', now());

  return attendee_row;
end;
$$;

revoke all on function public.cancel_event_reservation(uuid) from public;
grant execute on function public.cancel_event_reservation(uuid) to authenticated;

-- The RPCs above are the only authenticated write path for attendance.
revoke insert, update, delete on public.event_attendees from public, anon, authenticated;

-- 7) Fix chat participant policy qualification.
drop policy if exists "participants can read chat participants" on public.chat_participants;

create or replace function public.is_chat_participant(target_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_participants participant
    where participant.thread_id = target_thread_id
      and participant.profile_id = auth.uid()
  );
$$;

revoke all on function public.is_chat_participant(uuid) from public;
grant execute on function public.is_chat_participant(uuid) to authenticated;

create policy "participants can read chat participants"
on public.chat_participants
for select
to authenticated
using (
  profile_id = auth.uid()
  or public.is_chat_participant(chat_participants.thread_id)
);

-- 8) Enforce profile photo file type and size at the bucket level.
update storage.buckets
set
  public = false,
  file_size_limit = 8388608,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'profile-photos';
