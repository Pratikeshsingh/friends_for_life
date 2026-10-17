-- Paying a week ahead, bookings that say what is really happening, what
-- members actually paid, and Rozey's price.
--
-- 1. Pay a week ahead, so the organiser books for the final group.
--    The pay-by date is five days after the invitation, but no later than a
--    week before the first meetup (it was three days). A late invitation
--    (someone filling a free place) still gets until the end of the next
--    day, but never past the day before the first meetup.
--    Saying yes closes at the end of the pay-by date or a week before the
--    first meetup, whichever is later. Until then an overdue place can still
--    be taken up, unless the organiser has released it. Someone who already
--    said yes can still pay; the organiser confirms the money as before.
--    No new invitations on the day of the first meetup.
-- 2. Bookings:
--    * organisers see whether a booking email is waiting to go, sent or
--      failed; a failed one is flagged to them, and a second one can't be
--      sent while the first is still waiting;
--    * a booked (or asked-for) week that changes place or time is no longer
--      shown as booked; the old booking stays as a note until the new one
--      is booked, so it can be cancelled, and an unsent email is withdrawn;
--    * a week we book that isn't booked two weeks ahead is flagged to the
--      organiser, so it is in their To do list and digest;
--    * the organiser's meetups carry their week number again.
-- 3. Members see what they actually paid in their payment history (older
--    Circles cost €19).
-- 4. Rozey's dinner: about €38, or €43 from Friday to Sunday.
-- Every statement can run again safely.

-- 1. Pay a week ahead ------------------------------------------------------------------
create or replace function public.circle_pay_by(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select least(start_date - 1,
               greatest((invited_at at time zone 'Europe/Amsterdam')::date + 1,
                        least((invited_at at time zone 'Europe/Amsterdam')::date + 5, start_date - 7)));
$$;
revoke all on function public.circle_pay_by(timestamptz, date) from public, anon, authenticated;

-- The last day to say yes (to the end of that day, Netherlands time).
create or replace function public.circle_accept_until(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select greatest(public.circle_pay_by(invited_at, start_date), start_date - 7);
$$;
revoke all on function public.circle_accept_until(timestamptz, date) from public, anon, authenticated;

-- Members: the last day to say yes, and what each payment was for.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_snapshot_before_deadline') then
    alter function public.circle_snapshot() rename to circle_snapshot_before_deadline;
  end if;
end;
$$;
revoke all on function public.circle_snapshot_before_deadline() from public, anon, authenticated;

create or replace function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_snapshot_before_deadline();
  closes date;
begin
  select public.circle_accept_until(m.created_at, c.start_date) into closes
    from public.circle_memberships m join public.circles c on c.id = m.circle_id
   where m.profile_id = auth.uid() and m.status = 'invited';
  if closes is not null then
    result := result || jsonb_build_object('accept_until', closes);
  end if;
  if jsonb_typeof(result->'payment_history') = 'array' then
    result := jsonb_set(result, '{payment_history}', coalesce((
      select jsonb_agg(h || jsonb_build_object('amount_cents', p.amount_cents) order by ord)
        from jsonb_array_elements(result->'payment_history') with ordinality t(h, ord)
        left join public.circle_payments p on p.id = (h->>'id')::uuid and p.profile_id = auth.uid()), '[]'::jsonb));
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Saying yes after it closed, and a second booking email while one waits.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_action_before_deadline') then
    alter function public.circle_action(text, jsonb) rename to circle_action_before_deadline;
  end if;
end;
$$;
revoke all on function public.circle_action_before_deadline(text, jsonb) from public, anon, authenticated;

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
  end if;
  perform public.circle_action_before_deadline(action, payload);
  -- Booked again, or not booked after all: the note about the old booking is done.
  if action = 'admin_booking' and payload->>'step' in ('booked', 'clear') then
    update public.events set booking_previous = null where id = nullif(payload->>'id', '')::uuid;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- No new invitations on the day of the first meetup: there'd be no time to say yes.
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'circle_admin_invite_before_deadline') then
    alter function public.circle_admin_invite(uuid, uuid) rename to circle_admin_invite_before_deadline;
  end if;
end;
$$;
revoke all on function public.circle_admin_invite_before_deadline(uuid, uuid) from public, anon, authenticated;

create or replace function public.circle_admin_invite(target_circle uuid, member uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.circle_is_admin() and exists (
       select 1 from public.circles c
        where c.id = target_circle and c.start_date <= (now() at time zone 'Europe/Amsterdam')::date) then
    raise exception 'It’s too late to invite someone new: the first meetup is today or has passed.';
  end if;
  perform public.circle_admin_invite_before_deadline(target_circle, member);
end;
$$;
revoke all on function public.circle_admin_invite(uuid, uuid) from public, anon;
grant execute on function public.circle_admin_invite(uuid, uuid) to authenticated;

-- 2. Bookings -------------------------------------------------------------------------
alter table public.events add column if not exists booking_previous jsonb;

-- A new place or time undoes "booked" and "asked". A booking the place knows
-- about is kept as a note, so the organiser can cancel it.
create or replace function public.circle_booking_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.booking_status is not null
     and new.booking_status is not distinct from old.booking_status
     and (new.venue_name is distinct from old.venue_name or new.starts_at is distinct from old.starts_at) then
    if old.booking_status = 'booked' or exists (
         select 1 from public.circle_venue_emails v
          where v.event_id = old.id and v.sent_at is not null
            and v.created_at >= coalesce(old.booking_requested_at, '-infinity'::timestamptz)) then
      new.booking_previous := coalesce(old.booking_previous, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'status', old.booking_status, 'venue', old.venue_name, 'starts_at', old.starts_at));
    end if;
    new.booking_status := null;
    new.booking_requested_at := null;
    delete from public.circle_venue_emails v where v.event_id = old.id and v.sent_at is null;
  end if;
  return new;
end;
$$;
revoke all on function public.circle_booking_changed() from public, anon, authenticated;
drop trigger if exists circle_booking_changed on public.events;
create trigger circle_booking_changed
  before update of venue_name, starts_at on public.events
  for each row execute function public.circle_booking_changed();

-- Organisers see each meetup's week (missing until now, so week 5 never
-- showed as the group's), the latest booking email (waiting, sent or
-- failed) and the old booking.
do $$
declare d text := pg_get_functiondef('public.circle_admin_snapshot_core()'::regprocedure);
begin
  if position('booking_previous' in d) = 0 then
    if position('''booking_requested_at'',e.booking_requested_at,' in d) = 0 then
      raise exception 'organiser booking patch did not apply';
    end if;
    execute replace(d, '''booking_requested_at'',e.booking_requested_at,',
      '''booking_requested_at'',e.booking_requested_at,''week'',e.circle_week,''booking_previous'',e.booking_previous,'
      || '''booking_email'',(select jsonb_build_object(''created_at'',ve.created_at,''sent_at'',ve.sent_at,'
      || '''failed'',ve.sent_at is null and ve.attempts>=3,''error'',ve.last_error) '
      || 'from public.circle_venue_emails ve where ve.event_id=e.id order by ve.created_at desc limit 1),');
  end if;
end;
$$;

-- The worker reports back; after the last try, the organiser hears it failed.
create or replace function public.ack_venue_email(email_id uuid, failure text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v public.circle_venue_emails;
begin
  update public.circle_venue_emails
     set sent_at = case when failure is null then now() end,
         last_error = left(failure, 300), leased_at = null
   where id = email_id
  returning * into v;
  if failure is not null and v.attempts >= 3 then
    insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
    select a.profile_id, e.id, 'support', 'A booking email failed',
           c.name || ' · week ' || e.circle_week || ': the booking email to '
             || coalesce(e.venue_name, v.to_email) || ' could not be sent. Book it another way.',
           'booking-failed:' || v.id,
           jsonb_build_object('open', 'organiser:todo')
      from public.events e
      join public.circles c on c.id = e.circle_id
      cross join public.circle_admins a
     where e.id = v.event_id
    on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.ack_venue_email(uuid, text) from public, anon, authenticated;
grant execute on function public.ack_venue_email(uuid, text) to service_role;

-- Housekeeping, as in 20261035, plus: a week we book that isn't booked two
-- weeks ahead (one alert per week, again if it changes after booking).
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
     and ends_at < now() - interval '24 hours';
  get diagnostics added = row_count; n := n + added;

  update public.circles c set status = 'completed'
   where c.status = 'active'
     and (select count(*) from public.events e
           where e.circle_id = c.id and e.circle_week is not null and e.completed_at is not null) >= 6
     -- The week after the last meetup is for one-to-ones; the Circle ends after it.
     and not exists (select 1 from public.events e
                      where e.circle_id = c.id and e.circle_week is not null and e.status <> 'cancelled'
                        and e.ends_at > now() - interval '7 days');

  -- A week we book that still has no place, three days ahead.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'A meetup has no place yet',
         c.name || ' · week ' || e.circle_week || ' on '
           || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': add the place so members know where to go.',
         'no-venue:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status in ('offered', 'active') and e.circle_week between 1 and 6 and e.circle_week <> 5
     and e.status <> 'cancelled' and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- A week we book, two weeks ahead, not booked yet.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
  select a.profile_id, e.id, 'support', 'A week to book',
         c.name || ' · week ' || e.circle_week || ' on '
           || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ' at ' || e.venue_name || ': not booked yet.',
         'to-book:' || e.id || ':' || coalesce(jsonb_array_length(e.booking_previous), 0),
         jsonb_build_object('open', 'organiser:todo')
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status in ('offered', 'active') and e.circle_week between 1 and 6 and e.circle_week <> 5
     and e.status <> 'cancelled' and e.booking_status is null
     and coalesce(trim(e.venue_name), '') <> ''
     and e.starts_at > now() and e.starts_at <= now() + interval '14 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Week 5, a week ahead: it's the group's call.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, e.id, 'reminder', 'Week 5 is your call',
         'Week 5 of ' || c.name || ' is on ' || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || '. Choose together what to do, where, and a start between '
           || case when extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 17 then '18:00 and 21:00'
                   when extract(hour from e.starts_at at time zone 'Europe/Amsterdam') >= 12 then '12:00 and 16:00'
                   else '09:00 and 11:30' end
           || '. Talk it over in the chat, then save it in the app.',
         'week5:' || e.id || ':' || m.profile_id,
         jsonb_build_object('open', 'meetup:' || e.id)
    from public.events e
    join public.circles c on c.id = e.circle_id
    join public.circle_memberships m on m.circle_id = e.circle_id and m.status = 'joined'
   where c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
     and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '7 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Five days ahead, still open: a word from VriendTime in the group chat.
  with due as (
    update public.events e set group_nudged_at = now()
      from public.circles c
     where c.id = e.circle_id and c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
       and e.group_nudged_at is null and coalesce(trim(e.venue_name), '') = ''
       and e.starts_at > now() and e.starts_at <= now() + interval '5 days'
    returning e.circle_id)
  insert into public.messages(thread_id, sender_id, body, kind)
  select t.id, null,
         'Week 5 is your call! Share ideas here, then tap “Plan it” on the week 5 card to set the place and the time.',
         'system'
    from due join public.chat_threads t on t.circle_id = due.circle_id and t.kind = 'group';
  get diagnostics added = row_count; n := n + added;

  -- Three days ahead, still open: the organiser books something.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'Week 5 has no plan yet',
         c.name || ' · week 5 on ' || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': the group hasn’t planned it. Check the chat, or book something for them.',
         'week5-open:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status = 'active' and e.circle_week = 5 and e.status <> 'cancelled'
     and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_meetup_housekeeping() from public, anon, authenticated;

-- Tidy: the coffee trigger functions were executable by anyone. Triggers can't
-- be called directly, so this changed nothing in practice; triggers still fire.
revoke all on function public.circle_coffees_on_circle() from public, anon, authenticated;
revoke all on function public.circle_coffees_on_exclusion() from public, anon, authenticated;
revoke all on function public.circle_coffees_on_membership() from public, anon, authenticated;
revoke all on function public.circle_coffees_on_profile_delete() from public, anon, authenticated;

-- 4. Rozey's dinner price ----------------------------------------------------------------
update public.circle_programme_template
   set cost = 'About €38 per person, or €43 from Friday to Sunday: dinner and drinks, all you can eat.'
 where venue = 'Rozey Alkmaar'
   and cost = 'About €40 per person: dinner and drinks, all you can eat.';
update public.events
   set cost_notes = 'About €38 per person, or €43 from Friday to Sunday: dinner and drinks, all you can eat.'
 where venue_name = 'Rozey Alkmaar' and starts_at > now()
   and cost_notes = 'About €40 per person: dinner and drinks, all you can eat.';
