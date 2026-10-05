-- Fixes from the 4–5 October 2026 go-live review (kept privately).
--
-- GL-16  Photo uploads were refused for everyone: the photo-limit helper's
--        argument is called owner_id, and so is a column of storage.objects,
--        so it counted every photo in the bucket instead of the member's own.
-- GL-06  Service-only functions no longer carry public execute rights, and
--        three small functions get a fixed search path.
-- GL-10  A new safety report notifies the organisers.
-- GL-09  The member data export also covers moves, matching choices,
--        email preferences, notifications and refund requests.
-- GL-02  Error records older than 30 days are deleted daily.
begin;

-- GL-16 ----------------------------------------------------------------------
create or replace function public.circle_photo_count(owner_id uuid)
returns integer
language sql
stable
security definer
set search_path = public, storage
as $$
  -- $1, not owner_id: storage.objects has its own owner_id column, which
  -- would otherwise take precedence inside this query.
  select count(*)::integer
    from storage.objects as photo
   where photo.bucket_id = 'profile-photos'
     and photo.name like $1::text || '/%';
$$;

-- GL-06 ----------------------------------------------------------------------
-- Run only by the scheduler (as the database owner).
revoke all on function public.queue_circle_notifications() from public, anon, authenticated;
-- Trigger functions are never called directly; the grants were defaults.
revoke all on function public.guard_circle_attendance() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.refresh_event_confirmed_count() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.validate_profile_age() from public, anon, authenticated;
-- Used by signed-in members' rules only.
revoke all on function public.circle_is_admin() from public, anon;
grant execute on function public.circle_is_admin() to authenticated;
revoke all on function public.is_chat_participant(uuid) from public, anon;
grant execute on function public.is_chat_participant(uuid) to authenticated;

alter function public.circle_name_case(text) set search_path = public;
alter function public.set_updated_at() set search_path = public;
alter function public.validate_profile_age() set search_path = public;

-- GL-10 ----------------------------------------------------------------------
create or replace function public.circle_notify_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No details of the report or the reporter in the notification itself;
  -- the organiser reads it in the organiser panel.
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support', 'A member reported a concern',
         'Open the organiser panel to read and handle it.',
         'circle-report:' || new.id
    from public.circle_admins a
  on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.circle_notify_report() from public, anon, authenticated;

drop trigger if exists circle_reports_notify on public.circle_reports;
create trigger circle_reports_notify
after insert on public.circle_reports
for each row execute function public.circle_notify_report();

-- GL-09 ----------------------------------------------------------------------
alter function public.circle_export_data() rename to circle_export_data_before_go_live;
revoke all on function public.circle_export_data_before_go_live() from public, anon, authenticated;

create function public.circle_export_data()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Sign in first.'; end if;
  return public.circle_export_data_before_go_live() || jsonb_build_object(
    'moves', coalesce((select jsonb_agg(jsonb_build_object(
        'requested_at', m.requested_at, 'reason', m.reason,
        'placed_at', m.placed_at, 'outcome', m.outcome) order by m.requested_at)
      from public.circle_moves m where m.profile_id = uid), '[]'::jsonb),
    -- Your own "not in my next Circle" choices, by first name only.
    'not_matched_again', coalesce((select jsonb_agg(jsonb_build_object(
        'first_name', p.first_name, 'since', x.created_at) order by x.created_at)
      from public.circle_exclusions x
      left join public.profiles p on p.id = x.excluded_profile_id
      where x.profile_id = uid), '[]'::jsonb),
    'email_notifications', (select s.email_enabled from public.notification_settings s where s.profile_id = uid),
    'notifications', coalesce((select jsonb_agg(jsonb_build_object(
        'created_at', n.created_at, 'kind', n.kind, 'title', n.title,
        'body', n.body, 'read_at', n.read_at) order by n.created_at)
      from public.notifications n where n.recipient_profile_id = uid), '[]'::jsonb),
    'refund_requests', coalesce((select jsonb_agg(jsonb_build_object(
        'requested_at', r.requested_at, 'status', r.status) order by r.requested_at)
      from public.circle_refund_requests r where r.profile_id = uid), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_export_data() from public, anon;
grant execute on function public.circle_export_data() to authenticated;

-- GL-02 ----------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'vriendtime-purge-error-events',
      '40 3 * * *',
      $job$delete from public.app_error_events where created_at < now() - interval '30 days'$job$);
  end if;
end;
$$;

commit;
