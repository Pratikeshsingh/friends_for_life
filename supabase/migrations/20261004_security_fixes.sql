-- Security fixes from the 3 October 2026 audit
-- (kept privately, outside the repository).
--
-- Fixes SEC-01, 02, 03, 04, 05, the photo path and quota part of SEC-08,
-- and SEC-12. Nothing here changes what a member can do through the app;
-- it closes routes that skip the app and talk to the database directly.
-- The old app at /oldapp shares this database, so profile upserts and
-- marking notifications read keep working.
begin;

-- SEC-01: notifications. A member may only mark their own notification as
-- read. Title, body and the email delivery fields are written by the server.
revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- SEC-02: the profile email always equals the verified sign-in email, and
-- photo paths must point into the member's own folder.
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
  if new.secondary_photo_path is not null
     and new.secondary_photo_path !~ ('^' || new.id::text || '/[^/]+$') then
    raise exception 'Choose a photo from your own account.';
  end if;
  return new;
end;
$$;
revoke all on function public.circle_guard_profile() from public, anon, authenticated;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard
before insert or update on public.profiles
for each row execute function public.circle_guard_profile();

-- When someone confirms a new sign-in email, the profile follows.
create or replace function public.circle_sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email
   where id = new.id and email is distinct from new.email;
  return new;
end;
$$;
revoke all on function public.circle_sync_profile_email() from public, anon, authenticated;

drop trigger if exists auth_users_sync_profile_email on auth.users;
create trigger auth_users_sync_profile_email
after update of email on auth.users
for each row execute function public.circle_sync_profile_email();

-- SEC-03: chat. Messages go through circle_action('message') only, the
-- database sets the time, and one sender's messages are counted one at a
-- time so parallel requests cannot slip past the limit.
revoke insert, update, delete on public.messages from anon, authenticated;
drop policy if exists "participants can send messages" on public.messages;

create or replace function public.guard_circle_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare cid uuid;
begin
  new.created_at := now();
  select circle_id into cid from public.chat_threads where id = new.thread_id;
  if cid is not null then
    if not exists (
      select 1 from public.circle_memberships m
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
$$;

-- SEC-04: extra plans. Members get a fair share; organisers are not limited.
create or replace function public.circle_guard_extra_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.circle_id is null or new.circle_week is not null
     or new.status = 'cancelled' or public.circle_is_admin() then
    return new;
  end if;
  if new.starts_at > now() + interval '90 days' then
    raise exception 'Plan extras up to three months ahead.';
  end if;
  if tg_op = 'INSERT' then
    perform pg_advisory_xact_lock(hashtext('circle-extras:' || new.circle_id::text));
    if (select count(*) from public.events
         where circle_id = new.circle_id and circle_week is null
           and created_by = new.created_by
           and created_at > now() - interval '1 day') >= 5 then
      raise exception 'You have added a lot of plans today. Try again tomorrow.';
    end if;
    if (select count(*) from public.events
         where circle_id = new.circle_id and circle_week is null
           and created_by = new.created_by
           and status <> 'cancelled' and starts_at > now()) >= 3 then
      raise exception 'You already have three upcoming extra plans. Wait until one has happened, or cancel one.';
    end if;
    if (select count(*) from public.events
         where circle_id = new.circle_id and circle_week is null
           and status <> 'cancelled' and starts_at > now()) >= 10 then
      raise exception 'Your Circle already has ten upcoming extra plans.';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.circle_guard_extra_plan() from public, anon, authenticated;

drop trigger if exists events_guard_extra_plan on public.events;
create trigger events_guard_extra_plan
before insert or update of starts_at on public.events
for each row execute function public.circle_guard_extra_plan();

-- SEC-05: venues. For a Circle meetup the address is only for current, paid
-- members of an active Circle, not for anyone with an old attendance row.
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
    and (e.circle_id is null or exists (
      select 1 from public.circle_memberships m
      join public.circles c on c.id = m.circle_id
      where m.circle_id = e.circle_id and m.profile_id = current_profile_id
        and m.status = 'joined' and m.payment_status = 'paid'
        and c.status in ('active', 'completed')))
  order by e.starts_at;
end;
$$;
revoke all on function public.get_revealed_event_venues(uuid) from public;
grant execute on function public.get_revealed_event_venues(uuid) to authenticated;

-- Leaving a Circle by any route (leave, cancellation, refund) also removes
-- future attendance and the chat seat.
create or replace function public.circle_cleanup_after_leaving()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'left' and old.status is distinct from 'left' then
    delete from public.event_attendees ea using public.events e
     where ea.event_id = e.id and e.circle_id = new.circle_id
       and ea.profile_id = new.profile_id and e.starts_at > now();
    delete from public.chat_participants cp using public.chat_threads t
     where cp.thread_id = t.id and t.circle_id = new.circle_id
       and cp.profile_id = new.profile_id;
  end if;
  return new;
end;
$$;
revoke all on function public.circle_cleanup_after_leaving() from public, anon, authenticated;

drop trigger if exists circle_memberships_cleanup on public.circle_memberships;
create trigger circle_memberships_cleanup
after update of status on public.circle_memberships
for each row execute function public.circle_cleanup_after_leaving();

-- SEC-08 (part): photos live directly in the member's own folder, at most
-- 20 files each. The app keeps a handful; this stops direct API abuse.
create or replace function public.circle_photo_count(owner_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, storage
as $$
  select count(*)::integer from storage.objects
   where bucket_id = 'profile-photos' and name like owner_id::text || '/%';
$$;
revoke all on function public.circle_photo_count(uuid) from public, anon;
grant execute on function public.circle_photo_count(uuid) to authenticated;

drop policy if exists "users can upload own profile photos" on storage.objects;
create policy "users can upload own profile photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-photos'
  and name ~ ('^' || auth.uid()::text || '/[^/]+$')
  and public.circle_photo_count(auth.uid()) < 20
);

drop policy if exists "users can update own profile photos" on storage.objects;
create policy "users can update own profile photos"
on storage.objects for update to authenticated
using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'profile-photos' and name ~ ('^' || auth.uid()::text || '/[^/]+$'));

-- SEC-12: retry records hold copies of messages and reports. Retries happen
-- within minutes, so keep them for a week, then delete them daily.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'vriendtime-purge-action-requests',
      '30 3 * * *',
      $job$delete from public.circle_action_requests where created_at < now() - interval '7 days'$job$);
  end if;
end;
$$;

commit;
