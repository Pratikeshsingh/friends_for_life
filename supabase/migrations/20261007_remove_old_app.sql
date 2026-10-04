-- Remove the old meetup app from the database.
--
-- VriendTime is now only Friendship Circles. The old app (open meetups you
-- could reserve) is retired, so its data, functions, jobs and access rules
-- go. Circle meetups also live in public.events and public.event_attendees;
-- those rows and the shared pieces they need are kept.
begin;

-- 1. The daily reminder job for old meetups.
do $$
begin
  if to_regclass('cron.job') is not null then
    execute $q$select cron.unschedule(jobid) from cron.job
               where jobname = 'queue-due-event-notifications-daily'$q$;
  end if;
end;
$$;

-- 2. Old meetups, their reservations and notifications (cascade from events).
delete from public.events where circle_id is null;

-- 3. Old access rules. Members never read or write these tables directly;
--    the Circle app goes through circle_snapshot and circle_action. The read
--    rule also exposed every Circle venue address to any signed-in user.
drop policy if exists "authenticated can read open events" on public.events;
drop policy if exists "users can join themselves to events" on public.event_attendees;
drop policy if exists "users can read own event attendance" on public.event_attendees;
drop policy if exists "users can update own event attendance" on public.event_attendees;
revoke insert, update, delete on public.events, public.event_attendees from anon, authenticated;

-- 4. Old triggers and functions.
drop trigger if exists event_attendees_queue_due_notifications on public.event_attendees;
drop trigger if exists event_attendees_cleanup_due_notifications on public.event_attendees;
-- Dropped by name, whatever their argument lists are.
do $$
declare f regprocedure;
begin
  for f in
    select p.oid::regprocedure from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname = any (array[
         'reserve_event', 'cancel_event_reservation',
         'get_revealed_event_venues', 'queue_due_event_notifications',
         'queue_due_notifications_for_joined_attendee',
         'cleanup_notifications_for_unjoined_attendee',
         'queue_event_notifications', 'event_venue_release_at',
         'notification_target_day_bounds', 'notification_release_anchor',
         'has_attended_meetup', 'email_exists',
         'notifications_pending_email_legacy', 'mark_notifications_emailed'])
  loop
    execute 'drop function ' || f;
  end loop;
end;
$$;

-- 5. Old lookup tables and the old meetup list.
drop view if exists public.event_catalog;
drop table if exists public.city_options;
drop table if exists public.interest_options;

-- 6. Columns only the old app used.
alter table public.events
  drop column if exists subtitle,
  drop column if exists host_profile_id,
  drop column if exists description,
  drop column if exists vibe,
  drop column if exists minimum_attendees,
  drop column if exists tags,
  drop column if exists languages,
  drop column if exists price_note,
  drop column if exists reveal_venue_at,
  drop column if exists image_url,
  drop column if exists is_featured;

-- New profiles: only what Circles use. Name, email and photo come later
-- from the Circle application.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, first_name)
  values (new.id, new.email, nullif(trim(new.raw_user_meta_data ->> 'first_name'), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

-- The photo guard no longer needs to check the old second photo.
create or replace function public.circle_guard_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare verified text;
begin
  select email into verified from auth.users where id = new.id;
  if found then
    new.email := verified;
  end if;
  if new.profile_photo_path is not null
     and new.profile_photo_path !~ ('^' || new.id::text || '/[^/]+$') then
    raise exception 'Choose a photo from your own account.';
  end if;
  return new;
end;
$$;

alter table public.profiles
  drop column if exists phone,
  drop column if exists address,
  drop column if exists gender,
  drop column if exists language,
  drop column if exists availability,
  drop column if exists energy,
  drop column if exists group_preference,
  drop column if exists time_preference,
  drop column if exists conversation_goals,
  drop column if exists dietary_notes,
  drop column if exists interests,
  drop column if exists selected_event_ids,
  drop column if exists secondary_photo_path,
  drop column if exists secondary_photo_name;

-- 7. Old details stored on the sign-in accounts. First name, display name
--    and the accepted terms and privacy versions stay.
update auth.users
   set raw_user_meta_data = raw_user_meta_data
       - 'last_name' - 'phone' - 'address' - 'city' - 'date_of_birth'
       - 'gender' - 'language' - 'availability' - 'energy'
       - 'group_preference' - 'conversation_goals' - 'dietary_notes'
       - 'interests' - 'selected_event_ids' - 'profile_photo_path'
       - 'profile_photo_name' - 'secondary_photo_path'
       - 'secondary_photo_name' - 'has_profile_photo'
       - 'has_ever_reserved_meetup'
 where raw_user_meta_data ?| array[
       'last_name','phone','address','city','date_of_birth','gender',
       'language','availability','energy','group_preference',
       'conversation_goals','dietary_notes','interests','selected_event_ids',
       'profile_photo_path','profile_photo_name','secondary_photo_path',
       'secondary_photo_name','has_profile_photo','has_ever_reserved_meetup'];

commit;
