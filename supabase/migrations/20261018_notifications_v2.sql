-- Notifications that lead somewhere, in the member's language, with
-- separate email settings.
--
-- 1. profiles.language ('en' or 'nl'), kept up to date by the app, so emails
--    can be sent in the language the member uses.
-- 2. Email categories: Circle updates (existing email_enabled), reminders,
--    the daily chat summary, and organiser alerts.
-- 3. A new kind 'chat' for the chat summary.
-- 4. One place for all notification wording and destinations: a trigger
--    rewrites known titles into clearer copy and stores where the
--    notification should open (metadata.open), e.g. 'checkin:<meetup id>'.
-- 5. notifications_pending_email_v2 for the email worker: respects the
--    categories and returns language and destination. The old function
--    stays until the new worker is deployed.
begin;

alter table public.profiles add column if not exists language text
  check (language is null or language in ('en', 'nl'));
grant update (language) on public.profiles to authenticated;

alter table public.notification_settings add column if not exists email_reminders boolean not null default true;
alter table public.notification_settings add column if not exists email_chat boolean not null default true;
alter table public.notification_settings add column if not exists email_organiser boolean not null default true;

alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('address', 'reminder', 'update', 'support', 'chat'));

-- Wording and destination ------------------------------------------------------
create or replace function public.circle_notification_copy()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  dest text;
  ev text := coalesce(new.event_id::text, '');
begin
  case new.title
    when 'Your Circle is ready' then
      new.title := 'You’re invited to a Circle';
      new.body := 'Meet your group and see all six dates. Accept and pay by the date shown in the app to keep your place.';
      dest := 'home';
    when 'Your place is confirmed' then
      new.title := 'You’re in! Your place is confirmed';
      new.body := case when new.body like '%previous Circle%'
        then 'Your €19 from your previous Circle covers this one. Say hello to your new Circle in the chat.'
        else 'We’ve received your €19. Say hello to your Circle in the chat and look at the details of your first meetup.' end;
      dest := 'home';
    when 'Payment needs verification' then
      new.title := 'Someone says they paid';
      new.body := 'A member says they’ve paid. Check Tikkie or your bank, then confirm the payment on the To do tab.';
      dest := 'organiser:todo';
    when 'See your Circle tomorrow' then
      new.body := replace(new.body, ' · Open your Circle for the plan.', ' · Open the app for the time and place.');
      dest := case when ev <> '' then 'meetup:' || ev else 'home' end;
    when 'How did tonight feel?' then
      new.title := 'How was your meetup?';
      new.body := 'Pick how it felt and, if you like, who you’d enjoy seeing more of. It stays private: only you and the organiser see it.';
      dest := case when ev <> '' then 'checkin:' || ev else 'home' end;
    when 'Your Circle is now yours' then
      new.title := 'Six weeks together: well done!';
      new.body := 'Your Circle and its chat stay open, so keep making plans together. Want to meet new people as well? You can join a new Circle in the app.';
      dest := 'outcome';
    when '90 days on: how is your Circle?' then
      new.title := 'How is your Circle doing?';
      new.body := 'It’s been three months since your Circle started. Answer four quick yes-or-not-yet questions about whether you’re still in touch. It helps us make better groups.';
      dest := 'outcome';
    when 'Cancellation received' then
      new.body := 'Your cancellation is with the organiser. We’ll be in touch about your €19.';
      dest := 'home';
    when 'Your Circle has been cancelled' then
      new.body := 'We’re sorry, this Circle can’t go ahead. If you paid, your €19 will be returned. Reply to this email if you have any questions.';
      dest := 'home';
    when 'New messages in your Circle' then
      new.kind := 'chat';
      dest := 'messages';
    else
      dest := case
        when new.title in ('Your Circle plan changed', 'Extra plan cancelled', 'Your Circle has a plan update')
          then case when ev <> '' then 'meetup:' || ev else 'home' end
        when new.title in ('Your refund is complete', 'We’ll refund your €19') then 'payments'
        when new.title in ('A member asked for a refund', 'A member reported a concern') then 'organiser:todo'
        when new.title = 'Circles can be formed' then 'organiser:form'
        when new.kind = 'support' then 'organiser:circles'
        else 'home' end;
  end case;
  new.metadata := coalesce(new.metadata, '{}'::jsonb) || jsonb_build_object('open', dest);
  return new;
end;
$$;
revoke all on function public.circle_notification_copy() from public, anon, authenticated;
drop trigger if exists circle_notification_copy on public.notifications;
create trigger circle_notification_copy
before insert on public.notifications
for each row execute function public.circle_notification_copy();

-- The chat summary is its own kind, so it has its own email switch.
create or replace function public.queue_chat_digests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare added integer;
begin
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select m.profile_id, 'chat', 'New messages in your Circle',
         count(*) || case when count(*) = 1 then ' new message in ' else ' new messages in ' end
           || c.name || '. Open VriendTime to read and reply.',
         'chat-digest:' || m.profile_id || ':' || (now() at time zone 'Europe/Amsterdam')::date
    from public.circle_memberships_all m
    join public.circles c on c.id = m.circle_id
    join public.chat_threads t on t.circle_id = m.circle_id
    join public.messages msg on msg.thread_id = t.id
   where m.status = 'joined' and c.status in ('active', 'completed')
     and msg.sender_id <> m.profile_id
     and msg.created_at > now() - interval '24 hours'
   group by m.profile_id, c.name
  on conflict do nothing;
  get diagnostics added = row_count;
  return added;
end;
$$;
revoke all on function public.queue_chat_digests() from public, anon, authenticated;

-- Email queue for the new worker ------------------------------------------------
create or replace function public.notifications_pending_email_v2(max_rows integer default 50)
returns table(id uuid, email text, first_name text, kind text, title text, body text,
              lease_token uuid, language text, open text)
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications set email_error = 'Delivery needs manual review: retry window expired.'
   where emailed_at is null and email_first_claimed_at < now() - interval '23 hours';
  return query
  with candidates as (
    select n.id
      from public.notifications n
      join public.profiles p on p.id = n.recipient_profile_id
      left join public.notification_settings s on s.profile_id = n.recipient_profile_id
     where n.emailed_at is null and n.email_attempts < 5 and n.created_at > now() - interval '3 days'
       and (n.email_first_claimed_at is null or n.email_first_claimed_at > now() - interval '23 hours')
       and (n.email_lease_until is null or n.email_lease_until < now())
       and (n.email_retry_at is null or n.email_retry_at <= now())
       and p.email is not null
       and case n.kind
             when 'reminder' then coalesce(s.email_reminders, true)
             when 'chat' then coalesce(s.email_chat, true)
             when 'support' then coalesce(s.email_organiser, true)
             else coalesce(s.email_enabled, true) end
     order by n.created_at
     limit greatest(1, least(coalesce(max_rows, 50), 50))
     for update of n skip locked
  ), claimed as (
    update public.notifications n
       set email_lease_until = now() + interval '5 minutes', email_lease_token = gen_random_uuid(),
           email_first_claimed_at = coalesce(n.email_first_claimed_at, now()),
           email_attempts = n.email_attempts + 1,
           email_snapshot = coalesce(n.email_snapshot, jsonb_build_object(
             'email', p.email, 'first_name', p.first_name, 'kind', n.kind,
             'title', n.title, 'body', n.body,
             'language', coalesce(p.language, 'en'),
             'open', coalesce(n.metadata->>'open', 'home')))
      from candidates c, public.profiles p
     where n.id = c.id and p.id = n.recipient_profile_id
    returning n.*
  )
  select c.id, c.email_snapshot->>'email', c.email_snapshot->>'first_name', c.email_snapshot->>'kind',
         c.email_snapshot->>'title', c.email_snapshot->>'body', c.email_lease_token,
         coalesce(c.email_snapshot->>'language', 'en'), coalesce(c.email_snapshot->>'open', 'home')
    from claimed c;
end;
$$;
revoke all on function public.notifications_pending_email_v2(integer) from public, anon, authenticated;
grant execute on function public.notifications_pending_email_v2(integer) to service_role;

commit;
