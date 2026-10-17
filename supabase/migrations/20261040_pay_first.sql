-- Pay first, then meet the group.
--
-- 1. A new Circle starts "filling": the organiser picks 5–6 people for a time
--    slot, as before, and they are asked to pay €39 within 7 days. Until the
--    organiser starts the Circle, members see only that seats are filled and
--    how many are confirmed: no names, photos, dates, places or chat.
--    Circles made before this keep the old flow (they count as started).
-- 2. Starting: the organiser chooses the first date (the group's own
--    weekday, at least 3 days ahead). The six weeks move to it, paid members
--    hear the date, and the group, dates, places and chat open.
--    Until then the planned dates are only a placeholder: when one comes
--    within 3 days it moves on a week, so nothing is reminded or booked early.
-- 3. Seven days without paying: the seat is open again and the person is
--    back on the waiting list. They can still pay until the first meetup:
--    with a seat free they are in; with the group full their €39 becomes a
--    credit for their next group (the same credit as a group switch).
-- 4. Refunds: before the start on request (the existing cancel option);
--    after the start no refund, but the free switch to another group.
--    Nothing here offers a refund in a message.
-- 5. The organiser hears when a group has 5 paid places, and after 14 days
--    of waiting; paid members get a calm "it's taking a little longer" note.
-- Every statement can run again safely.

-- 0. Columns ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'circles' and column_name = 'pay_first') then
    alter table public.circles add column pay_first boolean not null default true,
                               add column started_at timestamptz;
    -- Circles made before this keep the old flow: already started.
    update public.circles set pay_first = false, started_at = created_at;
  end if;
end;
$$;
-- Tests of the old flow set vriendtime.pay_first to 'off' for their session;
-- the app never does, so every new Circle pays first.
alter table public.circles
  alter column pay_first set default (coalesce(current_setting('vriendtime.pay_first', true), 'on') <> 'off'),
  alter column started_at set default (case when coalesce(current_setting('vriendtime.pay_first', true), 'on') = 'off' then now() end);

-- A Circle that is still finding its people.
create or replace function public.circle_unstarted(target uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (select 1 from public.circles
                  where id = target and pay_first and started_at is null and status = 'offered');
$$;
revoke all on function public.circle_unstarted(uuid) from public, anon, authenticated;

-- 1. Deadlines --------------------------------------------------------------------------
-- Seven days to pay; a late invitation still gets until the end of the next
-- day, and never past the day before the first meetup.
create or replace function public.circle_pay_by(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select least(start_date - 1,
               greatest((invited_at at time zone 'Europe/Amsterdam')::date + 1,
                        least((invited_at at time zone 'Europe/Amsterdam')::date + 7, start_date - 1)));
$$;
revoke all on function public.circle_pay_by(timestamptz, date) from public, anon, authenticated;

-- Paying late is possible until the day before the first meetup.
create or replace function public.circle_accept_until(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select greatest(public.circle_pay_by(invited_at, start_date), start_date - 1);
$$;
revoke all on function public.circle_accept_until(timestamptz, date) from public, anon, authenticated;

-- Refunds: in the old flow until 48 hours before the first meetup; in the
-- new flow until the organiser starts the Circle.
create or replace function public.circle_refund_until(target uuid)
returns timestamptz
language sql
stable
set search_path = public
as $$
  select case when c.pay_first then coalesce(c.started_at, 'infinity'::timestamptz)
              else (select e.starts_at - interval '48 hours' from public.events e
                     where e.circle_id = target and e.circle_week = 1) end
    from public.circles c where c.id = target;
$$;
revoke all on function public.circle_refund_until(uuid) from public, anon, authenticated;

-- A seat counts while it is paid, or invited within its 7 days.
create or replace function public.circle_seats_taken(target uuid)
returns integer
language sql
stable
set search_path = public
as $$
  select count(*)::int from public.circle_memberships m join public.circles c on c.id = m.circle_id
   where m.circle_id = target
     and (m.status = 'joined'
          or (m.status = 'invited'
              and (now() at time zone 'Europe/Amsterdam')::date <= public.circle_pay_by(m.created_at, c.start_date)));
$$;
revoke all on function public.circle_seats_taken(uuid) from public, anon, authenticated;

-- An expired invitation elsewhere gives way when the person is invited again.
create or replace function public.circle_release_expired(member uuid, keep uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.circle_memberships m
               join public.circle_payments p on p.profile_id = m.profile_id and p.circle_id = m.circle_id
              where m.profile_id = member and m.status = 'invited' and m.circle_id is distinct from keep
                and p.status = 'awaiting_payment' and p.payment_reported_at is not null) then
    raise exception 'This person says they’ve paid for another Circle. Check that payment first.';
  end if;
  update public.circle_payments p set status = 'cancelled'
    from public.circle_memberships m
   where m.profile_id = member and m.status = 'invited' and m.circle_id is distinct from keep
     and p.profile_id = m.profile_id and p.circle_id = m.circle_id and p.status = 'awaiting_payment';
  update public.circle_memberships set status = 'left'
   where profile_id = member and status = 'invited' and circle_id is distinct from keep;
end;
$$;
revoke all on function public.circle_release_expired(uuid, uuid) from public, anon, authenticated;

-- 2. A filling Circle is not "active" yet ------------------------------------------------
-- Payment confirmations used to make a Circle active; now only starting it does,
-- so reminders, one-to-ones and booking alerts wait for the real dates.
do $$
declare
  fixes text[][] := array[
    ['circle_action_release(text, jsonb)',
     'update public.circles set status=''active'' where id=p.circle_id and status=''offered'';',
     'update public.circles set status=''active'' where id=p.circle_id and status=''offered'' and not (pay_first and started_at is null);'],
    ['circle_action_before_second_circle(text, jsonb)',
     'update public.circles set status = ''active'' where id = m.circle_id and status = ''offered'';',
     'update public.circles set status = ''active'' where id = m.circle_id and status = ''offered'' and not (pay_first and started_at is null);'],
    -- A seat counts while it is paid or within its 7 days.
    ['circle_admin_invite_before_deadline(uuid, uuid)',
     'if (select count(*) from public.circle_memberships where circle_id = target_circle and status <> ''left'') >= 6 then',
     'if public.circle_seats_taken(target_circle) >= 6 then']];
  d text;
begin
  for i in 1 .. array_length(fixes, 1) loop
    d := pg_get_functiondef(('public.' || fixes[i][1])::regprocedure);
    if position(fixes[i][3] in d) = 0 then
      if position(fixes[i][2] in d) = 0 then
        raise exception 'pay-first patch did not apply: %', fixes[i][1];
      end if;
      execute replace(d, fixes[i][2], fixes[i][3]);
    end if;
  end loop;
  -- Booking alerts only for Circles with real dates.
  d := pg_get_functiondef('public.queue_meetup_housekeeping()'::regprocedure);
  if position('and c.started_at is not null' in d) = 0 then
    if position('where c.status in (''offered'', ''active'') and e.circle_week between 1 and 6 and e.circle_week <> 5' in d) = 0 then
      raise exception 'pay-first patch did not apply: queue_meetup_housekeeping';
    end if;
    execute replace(d, 'where c.status in (''offered'', ''active'') and e.circle_week between 1 and 6 and e.circle_week <> 5',
                       'where c.status in (''offered'', ''active'') and e.circle_week between 1 and 6 and e.circle_week <> 5 and c.started_at is not null');
  end if;
end;
$$;

-- 3. Members' view ----------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_snapshot_before_payfirst') then
    alter function public.circle_snapshot() rename to circle_snapshot_before_payfirst;
  end if;
end;
$$;
revoke all on function public.circle_snapshot_before_payfirst() from public, anon, authenticated;

create or replace function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_payfirst();
  m public.circle_memberships;
  c public.circles;
  today date := (now() at time zone 'Europe/Amsterdam')::date;
  paid boolean;
begin
  select * into m from public.circle_memberships where profile_id = uid and status <> 'left';
  if m.circle_id is null then return result; end if;
  select * into c from public.circles where id = m.circle_id;
  if not c.pay_first then return result; end if;
  paid := exists (select 1 from public.circle_payments p
                   where p.profile_id = uid and p.circle_id = c.id and p.status = 'paid')
          or m.status = 'joined';
  result := result || jsonb_build_object('pay_first', jsonb_build_object(
    'started', c.started_at is not null,
    'seats', 6,
    'found', least(6, public.circle_seats_taken(c.id)),
    'confirmed', (select count(*) from public.circle_memberships
                   where circle_id = c.id and status = 'joined'),
    -- Past the 7 days and not paid: the seat may have gone to someone else.
    'expired', m.status = 'invited' and not paid
               and today > public.circle_pay_by(m.created_at, c.start_date)));
  if c.started_at is null then
    -- Still finding people: the programme, but not who, when or where.
    result := result - 'refund_until' - 'coffees' || jsonb_build_object(
      'members', '[]'::jsonb,
      'messages', '[]'::jsonb,
      'circle', (result->'circle') - 'start_date',
      'meetups', coalesce((
        select jsonb_agg(jsonb_build_object('id', x->'id', 'week', x->'week', 'title', x->'title',
                                            'included', x->'included', 'cost_notes', x->'cost_notes')
                         order by (x->>'week')::int)
          from jsonb_array_elements(coalesce(result->'meetups', '[]'::jsonb)) x
         where x->>'week' is not null), '[]'::jsonb));
    if m.status = 'joined' then
      result := result || jsonb_build_object('stage', 'confirmed');
    end if;
  elsif m.status = 'invited' then
    -- Started, not paid yet: the dates, but who is in it once they've paid.
    result := result || jsonb_build_object('members', '[]'::jsonb, 'messages', '[]'::jsonb);
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- 4. Actions ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_action_before_payfirst') then
    alter function public.circle_action(text, jsonb) rename to circle_action_before_payfirst;
  end if;
end;
$$;
revoke all on function public.circle_action_before_payfirst(text, jsonb) from public, anon, authenticated;

create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare
  uid uuid := auth.uid();
  c public.circles;
  m public.circle_memberships;
  p public.circle_payments;
  cid uuid;
  first_d date;
  delta int;
  first_at timestamptz;
  when_text text;
  before_ids uuid[] := '{}';
  n_paid int;
  late boolean;
begin
  if action = 'admin_start' then
    if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
    select * into c from public.circles where id = nullif(payload->>'id', '')::uuid for update;
    if c.id is null or not (c.pay_first and c.started_at is null and c.status = 'offered') then
      raise exception 'This Circle has already started.';
    end if;
    first_d := nullif(payload->>'start_date', '')::date;
    if first_d is null or first_d < (now() at time zone 'Europe/Amsterdam')::date + 3 then
      raise exception 'Choose a first meetup at least 3 days from today, so everyone hears in time.';
    end if;
    if extract(isodow from first_d) <> extract(isodow from c.start_date) then
      raise exception 'Keep the group’s own weekday: everyone chose it.';
    end if;
    select count(*) into n_paid from public.circle_memberships where circle_id = c.id and status = 'joined';
    if n_paid = 0 then raise exception 'Nobody has paid yet.'; end if;
    delta := first_d - c.start_date;
    -- Same local times, on the new dates.
    update public.events
       set starts_at = ((starts_at at time zone 'Europe/Amsterdam') + make_interval(days => delta)) at time zone 'Europe/Amsterdam',
           ends_at = ((ends_at at time zone 'Europe/Amsterdam') + make_interval(days => delta)) at time zone 'Europe/Amsterdam'
     where circle_id = c.id and status <> 'cancelled';
    update public.circles set start_date = first_d, started_at = now(), status = 'active' where id = c.id;
    select starts_at into first_at from public.events where circle_id = c.id and circle_week = 1;
    when_text := to_char(first_at at time zone 'Europe/Amsterdam', 'Dy DD Mon') || ' at '
              || to_char(first_at at time zone 'Europe/Amsterdam', 'HH24:MI');
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
    select cm.profile_id, 'update', 'Your Circle is booked',
           'Your first meetup is on ' || when_text || '. Open the app to meet your group and see all six dates.',
           'circle-started:' || c.id || ':' || cm.profile_id, jsonb_build_object('open', 'home')
      from public.circle_memberships cm
     where cm.circle_id = c.id and cm.status = 'joined'
    on conflict do nothing;
    insert into public.messages(thread_id, sender_id, body, kind)
    select t.id, null, 'Welcome, everyone! Your six weeks start on ' || when_text || '. Say hello and introduce yourselves.', 'system'
      from public.chat_threads t where t.circle_id = c.id and t.kind = 'group';
    insert into public.circle_audit(actor, action, target_id) values (uid, action, c.id);
    return;
  end if;

  select * into m from public.circle_memberships where profile_id = uid and status <> 'left';

  if action in ('message', 'running_late') and m.circle_id is not null and public.circle_unstarted(m.circle_id) then
    raise exception 'Your group chat opens once your group is booked.';
  end if;

  if action = 'cancel_agreement' and m.circle_id is not null and m.status = 'joined' then
    select * into c from public.circles where id = m.circle_id;
    if c.pay_first and c.started_at is not null then
      raise exception 'Your group is booked, so your €39 can’t be returned any more. Until your second meetup you can switch to another group once, free of charge.';
    end if;
  end if;

  if action = 'admin_create' and public.circle_is_admin() then
    perform public.circle_release_expired(x.value::uuid)
       from jsonb_array_elements_text(coalesce(payload->'members', '[]'::jsonb)) x;
    select coalesce(array_agg(id), '{}') into before_ids from public.notifications
     where title = 'You’re invited to a Circle'
       and recipient_profile_id in (select value::uuid from jsonb_array_elements_text(coalesce(payload->'members', '[]'::jsonb)));
    perform public.circle_action_before_payfirst(action, payload);
    select ca.target_id into cid from public.circle_audit ca
     where ca.actor = uid and ca.action = 'admin_create' order by ca.created_at desc limit 1;
    if public.circle_unstarted(cid) then
      update public.notifications n
         set title = 'We’ve found people for your times',
             body = 'Pay your €39 within 7 days to confirm your place. We’ll tell you the dates and introduce your group as soon as it’s booked.'
       where n.title = 'You’re invited to a Circle' and not (n.id = any(before_ids))
         and n.recipient_profile_id in (select profile_id from public.circle_memberships where circle_id = cid);
    end if;
    return;
  end if;

  if action = 'admin_confirm_payment' and public.circle_is_admin() then
    select * into p from public.circle_payments where id = nullif(payload->>'id', '')::uuid for update;
    -- Paid after their 7 days: a seat only if nobody within their 7 days needs it.
    late := exists (select 1 from public.circle_memberships cm join public.circles cc on cc.id = cm.circle_id
                     where cm.circle_id = p.circle_id and cm.profile_id = p.profile_id and cc.pay_first
                       and (now() at time zone 'Europe/Amsterdam')::date > public.circle_pay_by(cm.created_at, cc.start_date));
    if p.id is not null and p.status = 'awaiting_payment' and (payload->>'received') = 'true'
       and exists (select 1 from public.circle_memberships where circle_id = p.circle_id and profile_id = p.profile_id and status = 'invited')
       and ((select count(*) from public.circle_memberships where circle_id = p.circle_id and status = 'joined') >= 6
            or (late and public.circle_seats_taken(p.circle_id) >= 6)) then
      -- Paid after the group filled up: the €39 holds a place in their next group.
      if exists (select 1 from public.circle_moves where profile_id = p.profile_id and outcome is null) then
        raise exception 'This person already has a €39 credit. Return this payment instead.';
      end if;
      update public.circle_payments set status = 'paid', received_at = now(), received_by = uid where id = p.id;
      update public.circle_memberships set status = 'left' where circle_id = p.circle_id and profile_id = p.profile_id;
      update public.circle_applications set status = 'waiting', updated_at = now() where profile_id = p.profile_id;
      insert into public.circle_moves(profile_id, from_circle_id, payment_id, reason)
      values (p.profile_id, p.circle_id, p.id, 'Paid after the group was full');
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
      values (p.profile_id, 'update', 'Your €39 has arrived',
              coalesce((select name from public.circles where id = p.circle_id), 'Your group')
                || ' filled up before your payment arrived, so your €39 holds your place in the next group for your times. We’ll invite you as soon as one fits.',
              'paid-into-credit:' || p.id)
      on conflict do nothing;
      insert into public.circle_audit(actor, action, target_id) values (uid, 'paid_into_credit', p.circle_id);
      return;
    end if;
    select coalesce(array_agg(id), '{}') into before_ids from public.notifications where recipient_profile_id = p.profile_id;
    perform public.circle_action_before_payfirst(action, payload);
    if p.id is not null and public.circle_unstarted(p.circle_id) then
      update public.notifications n
         set body = 'We’ve received your €39, so your place is confirmed. We’ll tell you the dates and introduce your group as soon as it’s booked.'
       where n.recipient_profile_id = p.profile_id and not (n.id = any(before_ids))
         and n.title = 'You’re in! Your place is confirmed';
      perform public.circle_ready_alert(p.circle_id);
    end if;
    return;
  end if;

  if action = 'join' and m.status = 'invited' and public.circle_unstarted(m.circle_id)
     and exists (select 1 from public.circle_moves where profile_id = uid and outcome is null) then
    -- Joining with a credit: no group to say hello to yet.
    select coalesce(array_agg(id), '{}') into before_ids from public.notifications where recipient_profile_id = uid;
    perform public.circle_action_before_payfirst(action, payload);
    update public.notifications n
       set body = 'Your €39 from before covers this one, so your place is confirmed. We’ll tell you the dates and introduce your group as soon as it’s booked.'
     where n.recipient_profile_id = uid and not (n.id = any(before_ids))
       and n.title = 'You’re in! Your place is confirmed';
    perform public.circle_ready_alert(m.circle_id);
    return;
  end if;

  perform public.circle_action_before_payfirst(action, payload);
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Five paid places: the group can start.
create or replace function public.circle_ready_alert(target uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support', 'A group is ready to start',
         c.name || ' has ' || n.paid || ' paid places. Choose the first date on the Circles tab.',
         'ready-start:' || c.id
    from public.circles c
    cross join lateral (select count(*) paid from public.circle_memberships
                         where circle_id = c.id and status = 'joined') n
    cross join public.circle_admins a
   where c.id = target and c.pay_first and c.started_at is null and c.status = 'offered' and n.paid >= 5
  on conflict do nothing;
$$;
revoke all on function public.circle_ready_alert(uuid) from public, anon, authenticated;

-- Inviting someone into a seat: an expired invitation elsewhere gives way,
-- and a filling Circle's invitation says what happens next.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_admin_invite_before_payfirst') then
    alter function public.circle_admin_invite(uuid, uuid) rename to circle_admin_invite_before_payfirst;
  end if;
end;
$$;
revoke all on function public.circle_admin_invite_before_payfirst(uuid, uuid) from public, anon, authenticated;

create or replace function public.circle_admin_invite(target_circle uuid, member uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  before_ids uuid[];
begin
  if public.circle_is_admin() then
    perform public.circle_release_expired(member, target_circle);
  end if;
  select coalesce(array_agg(id), '{}') into before_ids from public.notifications where recipient_profile_id = member;
  perform public.circle_admin_invite_before_payfirst(target_circle, member);
  if public.circle_unstarted(target_circle) then
    update public.notifications n
       set title = 'We’ve found people for your times',
           body = 'Pay your €39 within 7 days to confirm your place. We’ll tell you the dates and introduce your group as soon as it’s booked.'
     where n.recipient_profile_id = member and not (n.id = any(before_ids))
       and n.title = 'You’re invited to a Circle';
  end if;
end;
$$;
revoke all on function public.circle_admin_invite(uuid, uuid) from public, anon;
grant execute on function public.circle_admin_invite(uuid, uuid) to authenticated;

-- 5. The hourly job ---------------------------------------------------------------------
create or replace function public.queue_pay_by_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'Europe/Amsterdam')::date;
  n integer := 0;
  added integer;
  fc record;
  shift int;
begin
  -- The day before the pay-by date.
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, 'reminder',
         case when p.id is not null then 'Your €39 has not arrived yet' else 'Your invitation is waiting' end,
         case when p.id is not null
                then 'Your place in ' || c.name || ' is confirmed once your €39 arrives. Pay by the end of tomorrow to keep it.'
              when mv.id is not null
                then 'Reply to your invitation to ' || c.name || ' by the end of tomorrow to keep your place. Your fee is already paid.'
              else 'Accept and pay for ' || c.name || ' by the end of tomorrow to keep your place.' end,
         'pay-by-reminder:' || m.circle_id || ':' || m.profile_id,
         jsonb_build_object('open', 'home')
    from public.circle_memberships m
    join public.circles c on c.id = m.circle_id
    left join public.circle_payments p
      on p.profile_id = m.profile_id and p.circle_id = m.circle_id and p.status = 'awaiting_payment'
    left join public.circle_moves mv on mv.profile_id = m.profile_id and mv.outcome is null
   where m.status = 'invited' and c.status in ('offered', 'active')
     and public.circle_pay_by(m.created_at, c.start_date) = today + 1
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Seven days without paying, new flow: the seat opens and they are back on
  -- the waiting list (paying late stays possible, see circle_action).
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select m.profile_id, 'update', 'Your seat is open again',
         'We didn’t receive your €39 for ' || c.name || ' within 7 days, so your seat is now open for someone else. You’re back on the waiting list, and we’ll invite you when a group fits your times.',
         'seat-expired:' || m.circle_id || ':' || m.profile_id
    from public.circle_memberships m
    join public.circles c on c.id = m.circle_id
   where m.status = 'invited' and c.pay_first and c.status in ('offered', 'active')
     and today > public.circle_pay_by(m.created_at, c.start_date)
     and not exists (select 1 from public.circle_payments p
                      where p.profile_id = m.profile_id and p.circle_id = m.circle_id
                        and (p.status = 'paid' or p.payment_reported_at is not null))
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  update public.circle_applications a set status = 'waiting', updated_at = now()
    from public.circle_memberships m join public.circles c on c.id = m.circle_id
   where a.profile_id = m.profile_id and a.status = 'invited'
     and m.status = 'invited' and c.pay_first and c.status in ('offered', 'active')
     and today > public.circle_pay_by(m.created_at, c.start_date)
     and not exists (select 1 from public.circle_payments p
                      where p.profile_id = m.profile_id and p.circle_id = m.circle_id
                        and (p.status = 'paid' or p.payment_reported_at is not null));

  -- The organiser: an open seat to fill (new flow) or an overdue place (old flow).
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support',
         case when c.pay_first then 'A seat is open' else 'A place is overdue' end,
         coalesce(pr.first_name, 'A member')
           || case when c.pay_first
                     then ' didn’t pay for ' || c.name || ' within 7 days. Their seat is open: invite someone from the waiting list.'
                   when exists (select 1 from public.circle_payments p
                                 where p.profile_id = m.profile_id and p.circle_id = m.circle_id
                                   and p.status = 'awaiting_payment')
                     then ' has not paid for ' || c.name || ' by the pay-by date. Check Tikkie, then confirm the payment or release the place.'
                   else ' has not said yes to ' || c.name || ' by the pay-by date. Send a reminder, or release the place to invite someone else.' end,
         'pay-by-overdue:' || m.circle_id || ':' || m.profile_id
    from public.circle_memberships m
    join public.circles c on c.id = m.circle_id
    left join public.profiles pr on pr.id = m.profile_id
    cross join public.circle_admins a
   where m.status = 'invited' and c.status in ('offered', 'active')
     and today > public.circle_pay_by(m.created_at, c.start_date)
     and not exists (select 1 from public.circle_payments p
                      where p.profile_id = m.profile_id and p.circle_id = m.circle_id and p.status = 'paid')
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  for fc in select * from public.circles where pay_first and started_at is null and status = 'offered' loop
    -- Five paid: ready to start.
    perform public.circle_ready_alert(fc.id);
    -- Waiting two weeks since the first payment: a calm word, no promises.
    if (select min(p.received_at) from public.circle_payments p
         where p.circle_id = fc.id and p.status = 'paid') <= now() - interval '14 days' then
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
      select cm.profile_id, 'update', 'Your group needs a little longer',
             'We’re still finding the last people for your group. Your place is safe, and we’ll let you know as soon as it’s booked.',
             'long-wait:' || fc.id || ':' || cm.profile_id
        from public.circle_memberships cm
       where cm.circle_id = fc.id and cm.status = 'joined'
      on conflict do nothing;
      get diagnostics added = row_count; n := n + added;
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
      select a.profile_id, 'support', 'A group is waiting',
             fc.name || ' has had paid members for two weeks. Fill the last seats, or start with who you have.',
             'long-wait-org:' || fc.id
        from public.circle_admins a
      on conflict do nothing;
    end if;
    -- The planned dates are a placeholder until the start: keep them at
    -- least 4 days away, a week at a time, so nothing is reminded early.
    if fc.start_date <= today + 3 then
      shift := 7 * ceil((today + 4 - fc.start_date) / 7.0)::int;
      update public.events
         set starts_at = ((starts_at at time zone 'Europe/Amsterdam') + make_interval(days => shift)) at time zone 'Europe/Amsterdam',
             ends_at = ((ends_at at time zone 'Europe/Amsterdam') + make_interval(days => shift)) at time zone 'Europe/Amsterdam'
       where circle_id = fc.id and status <> 'cancelled';
      update public.circles set start_date = start_date + shift where id = fc.id;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.queue_pay_by_reminders() from public, anon, authenticated;
