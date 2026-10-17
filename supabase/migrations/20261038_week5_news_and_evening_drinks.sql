-- Week 5 news in the chat, and evening one-to-ones called what they are.
--
-- 1. When the group plans (or changes) week 5, VriendTime says so in the
--    group chat ("Anna planned week 5: Pub quiz at Jonas, starting 20:30."),
--    and the others get that same line as a notification instead of the
--    generic "Your Circle has a plan update".
-- 2. A one-to-one in the evening is a drink (whatever someone likes to
--    drink), never "coffee" at 20:00: the evening invitation, the morning-of
--    reminder ("A drink with Anna tonight"), the call-off note and the free
--    week note say so.
-- Can run again safely.

-- 1. Week 5 news (the 20261036 top of circle_action, plus the news) ------------------
create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.circle_memberships;
  closes date;
  w5 public.events;
  now5 public.events;
  news text;
  first_plan boolean;
  before_ids uuid[] := '{}';
begin
  if action = 'join' then
    select * into m from public.circle_memberships where profile_id = uid and status = 'invited';
    if m.circle_id is not null and not exists (
         select 1 from public.circle_payments p
          where p.profile_id = uid and p.circle_id = m.circle_id and p.status in ('awaiting_payment', 'paid')) then
      select public.circle_accept_until(m.created_at, c.start_date) into closes
        from public.circles c where c.id = m.circle_id;
      if (now() at time zone 'Europe/Amsterdam')::date > closes then
        raise exception 'This invitation has closed. Message us if you would still like to join.';
      end if;
    end if;
  elsif action = 'admin_booking' and payload->>'step' = 'email' and public.circle_is_admin()
        and exists (select 1 from public.circle_venue_emails v
                     where v.event_id = nullif(payload->>'id', '')::uuid
                       and v.sent_at is null and v.attempts < 3) then
    raise exception 'The booking email for this week is still on its way.';
  elsif action = 'schedule' and nullif(payload->>'id', '') is not null and not public.circle_is_admin() then
    select * into w5 from public.events where id = (payload->>'id')::uuid and circle_week = 5;
    if w5.id is not null then
      select coalesce(array_agg(n.id), '{}') into before_ids
        from public.notifications n where n.event_id = w5.id;
    end if;
  end if;
  perform public.circle_action_before_deadline(action, payload);
  -- Booked again, or not booked after all: the note about the old booking is done.
  if action = 'admin_booking' and payload->>'step' in ('booked', 'clear') then
    update public.events set booking_previous = null where id = nullif(payload->>'id', '')::uuid;
  end if;
  -- The group planned week 5: news in the chat, and a note to the others.
  if w5.id is not null then
    select * into now5 from public.events where id = w5.id;
    first_plan := coalesce(trim(w5.venue_name), '') = '';
    news := coalesce((select nullif(trim(p.first_name), '') from public.profiles p where p.id = uid), 'Someone')
         || case when first_plan then ' planned week 5: ' else ' changed week 5: ' end
         || coalesce(nullif(trim(now5.title), ''), 'a plan')
         || coalesce(' at ' || nullif(trim(now5.venue_name), ''), '')
         || ', starting ' || to_char(now5.starts_at at time zone 'Europe/Amsterdam', 'HH24:MI') || '.';
    insert into public.messages(thread_id, sender_id, body, kind)
    select t.id, null, news, 'system'
      from public.chat_threads t where t.circle_id = w5.circle_id and t.kind = 'group';
    -- Only the generic notices this save just queued.
    delete from public.notifications n
     where n.event_id = w5.id and not (n.id = any(before_ids))
       and n.title in ('Your Circle has a plan update', 'Your Circle plan changed');
    insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
    select cm.profile_id, w5.id, 'update',
           case when first_plan then 'Week 5 is planned' else 'Week 5 changed' end, news,
           'week5-plan:' || w5.id || ':' || cm.profile_id || ':' || coalesce(now5.plan_version, 0),
           jsonb_build_object('open', 'meetup:' || w5.id)
      from public.circle_memberships cm
     where cm.circle_id = w5.circle_id and cm.status = 'joined' and cm.profile_id <> uid
    on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- 2. Evening one-to-ones are a drink -------------------------------------------------
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
  select p.id, 'reminder',
         case when extract(hour from k.starts_at at time zone 'Europe/Amsterdam') >= 17
              then 'A drink with ' || coalesce(o.first_name, 'your match') || ' tonight'
              else 'Coffee with ' || coalesce(o.first_name, 'your match') || ' today' end,
         to_char(k.starts_at at time zone 'Europe/Amsterdam', 'HH24:MI') || ' at ' || k.place
           || '. Running late? Let them know in the app.',
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

-- The evening invitation, the call-off and the free week (patched in place).
do $$
declare
  fixes text[][] := array[
    ['circle_coffee_ask(uuid, integer, uuid, uuid, date, date, uuid, uuid)',
     '. An evening coffee or drink, just as friends. Can you make it? Answer in the app. Not for you? No reason needed.',
     '. A drink in the evening, just as friends: whatever you like to drink. Can you make it? Answer in the app. Not for you? No reason needed.'],
    ['circle_coffees_call_off(uuid, uuid, uuid, boolean)',
     'Your coffee on ',
     'Your one-to-one on '],
    ['queue_circle_coffees()',
     'No one-to-one coffee for you this time. See you with the whole group!',
     'No one-to-one for you this time. See you with the whole group!']];
  d text;
begin
  for i in 1 .. array_length(fixes, 1) loop
    d := pg_get_functiondef(('public.' || fixes[i][1])::regprocedure);
    if position(fixes[i][3] in d) = 0 then
      if position(fixes[i][2] in d) = 0 then
        raise exception 'one-to-one wording patch did not apply: %', fixes[i][1];
      end if;
      execute replace(d, fixes[i][2], fixes[i][3]);
    end if;
  end loop;
end;
$$;
