-- Small wins from the 17 October review.
--
-- 1. City: every profile has one (Alkmaar for now), ready for more cities.
-- 2. Friday mornings: one-to-ones can be on a Friday morning too.
-- 3. "Something else": both matching questions take it, with an optional
--    short note; "Other parents" is a new thing to look for.
-- 4. Notifications about something that has passed (a coffee, a meetup)
--    stop counting as new and are not emailed late.
-- 5. WhatsApp group, opt-in: after week 2 members are asked whether they'd
--    like one; only those who say yes (with a number) are listed for the
--    organiser, who makes the group by hand.
-- 6. Waiting applicants are asked every four weeks whether their times still
--    fit (this used to be a card on Home).
-- Every statement can run again safely.

-- 1. City -------------------------------------------------------------------------------
update public.profiles set city = 'Alkmaar' where city is null;
alter table public.profiles alter column city set default 'Alkmaar';

-- 2 and 3. Friday mornings; "Something else" -------------------------------------------
do $$
declare
  fixes text[][] := array[
    ['circle_coffee_slot(uuid, uuid, uuid, date, date)',
     'when dy in (''fri'', ''sat'', ''sun'') then array[''afternoon'', ''evening'']',
     'when dy = ''fri'' then array[''morning'', ''afternoon'', ''evening''] when dy in (''sat'', ''sun'') then array[''afternoon'', ''evening'']'],
    ['circle_action_before_hardening(text, jsonb)',
     'g.value not in (''Regular plans'',''Shared hobbies'',''Local friends'')',
     'g.value not in (''Regular plans'',''Shared hobbies'',''Local friends'',''Other parents'',''Something else'')'],
    ['circle_action_before_hardening(text, jsonb)',
     '''Friends moved away'',''A fresh start'',''More free time now'')',
     '''Friends moved away'',''A fresh start'',''More free time now'',''Something else'')'],
    ['circle_action_before_hardening(text, jsonb)',
     '''other_times'',nullif(trim(coalesce(payload->>''other_times'','''')),''''));',
     '''other_times'',nullif(trim(coalesce(payload->>''other_times'','''')),''''),''goals_other'',nullif(left(trim(coalesce(payload->>''goals_other'','''')),80),''''),''life_context_other'',nullif(left(trim(coalesce(payload->>''life_context_other'','''')),80),''''));']];
  d text;
begin
  for i in 1 .. array_length(fixes, 1) loop
    d := pg_get_functiondef(('public.' || fixes[i][1])::regprocedure);
    if position(fixes[i][3] in d) = 0 then
      if position(fixes[i][2] in d) = 0 then
        raise exception 'small-wins patch % did not apply: %', i, fixes[i][1];
      end if;
      execute replace(d, fixes[i][2], fixes[i][3]);
    end if;
  end loop;
end;
$$;

-- 4. Notifications that expire ----------------------------------------------------------
alter table public.notifications add column if not exists expires_at timestamptz;

-- About a meetup or a coffee still to come: no longer new once it is over.
-- (A check-in written after the meetup gets no end: it is about the past.)
create or replace function public.notification_expiry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ref uuid;
  ends timestamptz;
begin
  if new.expires_at is not null then return new; end if;
  if new.event_id is not null then
    select e.ends_at into ends from public.events e where e.id = new.event_id;
  elsif new.dedupe_key ~ '^(coffee|coffee-on|coffee-nudge|coffee-today|late):[0-9a-f-]{36}' then
    ref := substring(new.dedupe_key from ':([0-9a-f-]{36})')::uuid;
    select k.starts_at + interval '2 hours' into ends from public.circle_coffees k where k.id = ref;
    if ends is null then
      select e.ends_at into ends from public.events e where e.id = ref;
    end if;
  end if;
  if ends > now() then new.expires_at := ends; end if;
  return new;
end;
$$;
revoke all on function public.notification_expiry() from public, anon, authenticated;
drop trigger if exists notification_expiry on public.notifications;
create trigger notification_expiry before insert on public.notifications
  for each row execute function public.notification_expiry();

-- The ones already there, written before what they are about.
update public.notifications n set expires_at = e.ends_at
  from public.events e
 where n.expires_at is null and n.event_id = e.id and n.created_at < e.starts_at;
update public.notifications n set expires_at = k.starts_at + interval '2 hours'
  from public.circle_coffees k
 where n.expires_at is null and n.event_id is null
   and n.dedupe_key ~ '^(coffee|coffee-on|coffee-nudge|coffee-today|late):[0-9a-f-]{36}'
   and k.id = substring(n.dedupe_key from ':([0-9a-f-]{36})')::uuid
   and n.created_at < k.starts_at;

-- No late emails about something that is over.
do $$
declare d text := pg_get_functiondef('public.notifications_pending_email_v2(integer)'::regprocedure);
begin
  if position('n.expires_at' in d) = 0 then
    if position('and p.email is not null' in d) = 0 then
      raise exception 'small-wins patch did not apply: notifications_pending_email_v2';
    end if;
    execute replace(d, 'and p.email is not null',
                       'and p.email is not null and (n.expires_at is null or n.expires_at > now())');
  end if;
end;
$$;

-- 5. WhatsApp group, opt-in -------------------------------------------------------------
create table if not exists public.circle_whatsapp (
  circle_id uuid not null references public.circles(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  answer text not null check (answer in ('yes', 'no')),
  answered_at timestamptz not null default now(),
  primary key (circle_id, profile_id)
);
alter table public.circle_whatsapp enable row level security;
revoke all on public.circle_whatsapp from public, anon, authenticated;

-- Asked once week 2 is over, while the Circle runs.
create or replace function public.circle_whatsapp_due(target uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (select 1 from public.circles c
                  where c.id = target and c.status in ('active', 'completed') and c.started_at is not null)
     and exists (select 1 from public.events e
                  where e.circle_id = target and e.circle_week = 2 and e.status <> 'cancelled' and e.ends_at < now());
$$;
revoke all on function public.circle_whatsapp_due(uuid) from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_action_before_extras') then
    alter function public.circle_action(text, jsonb) rename to circle_action_before_extras;
  end if;
end;
$$;
revoke all on function public.circle_action_before_extras(text, jsonb) from public, anon, authenticated;

create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare
  uid uuid := auth.uid();
  m public.circle_memberships;
  phone text;
  yes_count int;
begin
  if action = 'whatsapp' then
    if uid is null then raise exception 'Sign in first.'; end if;
    select * into m from public.circle_memberships where profile_id = uid and status = 'joined';
    if m.circle_id is null or not public.circle_whatsapp_due(m.circle_id) then
      raise exception 'This question comes after your second meetup.';
    end if;
    if coalesce(payload->>'answer', '') not in ('yes', 'no') then raise exception 'Choose yes or no.'; end if;
    if payload->>'answer' = 'yes' then
      phone := regexp_replace(coalesce(nullif(payload->>'phone', ''),
                 (select answers->>'phone' from public.circle_applications where profile_id = uid), ''), '[\s().-]', '', 'g');
      if phone like '00%' then phone := '+' || substr(phone, 3); end if;
      if phone ~ '^06\d{8}$' then phone := '+31' || substr(phone, 2); end if;
      if phone = '' or phone !~ '^\+[1-9]\d{7,14}$' then
        raise exception 'Add a valid WhatsApp number, for example 06 12345678.';
      end if;
      update public.circle_applications set answers = answers || jsonb_build_object('phone', phone) where profile_id = uid;
    end if;
    insert into public.circle_whatsapp(circle_id, profile_id, answer)
    values (m.circle_id, uid, payload->>'answer')
    on conflict (circle_id, profile_id) do update set answer = excluded.answer, answered_at = now();
    -- Two yeses make a group worth creating.
    select count(*) into yes_count from public.circle_whatsapp w
      join public.circle_memberships cm on cm.circle_id = w.circle_id and cm.profile_id = w.profile_id and cm.status = 'joined'
     where w.circle_id = m.circle_id and w.answer = 'yes';
    if yes_count >= 2 then
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
      select a.profile_id, 'support', 'A WhatsApp group can be made',
             coalesce((select name from public.circles where id = m.circle_id), 'A Circle')
               || ' has people who’d like a WhatsApp group. Their numbers are on the Circles tab.',
             'whatsapp-ready:' || m.circle_id
        from public.circle_admins a
      on conflict do nothing;
    end if;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, m.circle_id);
    return;
  end if;
  perform public.circle_action_before_extras(action, payload);
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Members: what's still new, and the WhatsApp question.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_snapshot_before_extras') then
    alter function public.circle_snapshot() rename to circle_snapshot_before_extras;
  end if;
end;
$$;
revoke all on function public.circle_snapshot_before_extras() from public, anon, authenticated;

create or replace function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_extras();
  m public.circle_memberships;
begin
  result := result || jsonb_build_object('unread_notifications', (
    select count(*) from public.notifications
     where recipient_profile_id = uid and read_at is null
       and (expires_at is null or expires_at > now())));
  select * into m from public.circle_memberships where profile_id = uid and status = 'joined';
  if m.circle_id is not null and public.circle_whatsapp_due(m.circle_id) then
    result := result || jsonb_build_object('whatsapp', jsonb_build_object(
      'answer', (select answer from public.circle_whatsapp where circle_id = m.circle_id and profile_id = uid),
      'has_phone', coalesce((select answers->>'phone' from public.circle_applications where profile_id = uid), '') <> ''));
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- The organiser: who said yes, with their number, per Circle.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_admin_snapshot_before_extras') then
    alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_extras;
  end if;
end;
$$;
revoke all on function public.circle_admin_snapshot_before_extras() from public, anon, authenticated;

create or replace function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb := public.circle_admin_snapshot_before_extras();
begin
  return result || jsonb_build_object('circles', coalesce((
    select jsonb_agg(c || jsonb_build_object('whatsapp', coalesce((
      select jsonb_agg(jsonb_build_object(
               'profile_id', w.profile_id,
               'name', coalesce(p.first_name, 'Member'),
               'answer', w.answer,
               'phone', case when w.answer = 'yes' then a.answers->>'phone' end) order by w.answered_at)
        from public.circle_whatsapp w
        join public.circle_memberships cm on cm.circle_id = w.circle_id and cm.profile_id = w.profile_id and cm.status = 'joined'
        left join public.profiles p on p.id = w.profile_id
        left join public.circle_applications a on a.profile_id = w.profile_id
       where w.circle_id = (c->>'id')::uuid), '[]'::jsonb)) order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- 6. The hourly prompts -----------------------------------------------------------------
create or replace function public.queue_circle_prompts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer := 0;
  added integer;
begin
  -- After week 2: would you like a WhatsApp group? Once, and only once.
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
  select cm.profile_id, 'update', 'A WhatsApp group for your Circle?',
         'If you like, we’ll make a WhatsApp group for your Circle, next to the app. Answer in the app: only people who say yes are added.',
         'whatsapp-ask:' || cm.circle_id || ':' || cm.profile_id, jsonb_build_object('open', 'home')
    from public.circle_memberships cm
   where cm.status = 'joined' and public.circle_whatsapp_due(cm.circle_id)
     and not exists (select 1 from public.circle_whatsapp w where w.circle_id = cm.circle_id and w.profile_id = cm.profile_id)
     and exists (select 1 from public.circles c where c.id = cm.circle_id and c.status = 'active')
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Waiting four weeks since the times were last confirmed: still right?
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
  select a.profile_id, 'reminder', 'Still free at your times?',
         'A quick check every four weeks, so we only match you when you can come. Confirm your times in your profile, or add more to be matched sooner.',
         'still-free:' || a.profile_id || ':' || to_char(a.updated_at, 'YYYYMMDDHH24MI'), jsonb_build_object('open', 'profile')
    from public.circle_applications a
   where a.status = 'waiting' and a.updated_at < now() - interval '28 days'
     and a.answers ? 'availability_slots'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_circle_prompts() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-circle-prompts', '50 * * * *', 'select public.queue_circle_prompts();');
  end if;
end;
$$;
