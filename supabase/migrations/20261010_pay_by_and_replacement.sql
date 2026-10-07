-- A deadline to accept and pay, and filling a place that is not taken up.
--
-- Pay-by date: five days after the invitation, but never later than three
-- days before the first meetup (and always at least the day after the
-- invitation). It counts to the end of that day, Netherlands time.
-- After it, the place shows as overdue for the organiser, who can release it
-- and invite someone else. Places are not released automatically: payments
-- are confirmed by hand, so the app cannot know whether an overdue member has
-- in fact paid.
begin;

create or replace function public.circle_pay_by(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select greatest(
    (invited_at at time zone 'Europe/Amsterdam')::date + 1,
    least((invited_at at time zone 'Europe/Amsterdam')::date + 5, start_date - 3));
$$;
revoke all on function public.circle_pay_by(timestamptz, date) from public, anon, authenticated;

-- Member snapshot: the pay-by date for an open invitation ----------------------
alter function public.circle_snapshot() rename to circle_snapshot_before_pay_by;
revoke all on function public.circle_snapshot_before_pay_by() from public, anon, authenticated;

create function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_snapshot_before_pay_by();
  due date;
begin
  select public.circle_pay_by(m.created_at, c.start_date) into due
    from public.circle_memberships m join public.circles c on c.id = m.circle_id
   where m.profile_id = auth.uid() and m.status = 'invited';
  if due is not null then
    result := result || jsonb_build_object('pay_by', due);
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Organiser snapshot: members per Circle, and pay-by on each payment ---------
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_pay_by;
revoke all on function public.circle_admin_snapshot_before_pay_by() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_admin_snapshot_before_pay_by();
  today date := (now() at time zone 'Europe/Amsterdam')::date;
begin
  return result || jsonb_build_object(
    'circles', coalesce((
      select jsonb_agg(c || jsonb_build_object('members', coalesce((
        select jsonb_agg(jsonb_build_object(
            'profile_id', m.profile_id,
            'name', coalesce(p.first_name, 'Member'),
            'languages', coalesce(ma.answers->'languages', '[]'::jsonb),
            'status', m.status,
            'payment_status', m.payment_status,
            'invited_at', m.created_at,
            'accepted', exists (select 1 from public.circle_payments pay
                                 where pay.profile_id = m.profile_id and pay.circle_id = m.circle_id
                                   and pay.status in ('awaiting_payment', 'paid')),
            'pay_by', case when m.status = 'invited' then public.circle_pay_by(m.created_at, cc.start_date) end,
            'overdue', m.status = 'invited' and today > public.circle_pay_by(m.created_at, cc.start_date))
          order by m.created_at)
          from public.circle_memberships m
          join public.circles cc on cc.id = m.circle_id
          left join public.profiles p on p.id = m.profile_id
          left join public.circle_applications ma on ma.profile_id = m.profile_id
         where m.circle_id = (c->>'id')::uuid and m.status <> 'left'), '[]'::jsonb))
        order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(pay || coalesce((
        select jsonb_build_object(
            'pay_by', public.circle_pay_by(m.created_at, cc.start_date),
            'overdue', today > public.circle_pay_by(m.created_at, cc.start_date))
          from public.circle_memberships m join public.circles cc on cc.id = m.circle_id
         where m.profile_id = (pay->>'profile_id')::uuid and m.circle_id = (pay->>'circle_id')::uuid
           and m.status = 'invited'), '{}'::jsonb)
        order by ord)
      from jsonb_array_elements(coalesce(result->'payments', '[]'::jsonb)) with ordinality t(pay, ord)), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- Release an unpaid place ------------------------------------------------------
create or replace function public.circle_admin_release_place(target_circle uuid, member uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.circle_memberships;
  circle_name text;
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  select * into m from public.circle_memberships
   where circle_id = target_circle and profile_id = member for update;
  if not found or m.status <> 'invited' then
    raise exception 'Only an unpaid place can be released.';
  end if;
  select name into circle_name from public.circles where id = target_circle;
  update public.circle_memberships set status = 'left' where circle_id = target_circle and profile_id = member;
  update public.circle_payments set status = 'cancelled'
   where profile_id = member and circle_id = target_circle and status = 'awaiting_payment';
  -- Back on the waiting list, keeping their original place in the queue.
  update public.circle_applications set status = 'waiting', updated_at = now() where profile_id = member;
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  values (member, 'update', 'Your place has been released',
          'Your place in ' || coalesce(circle_name, 'the Circle') || ' was held until the pay-by date. You are back on the waiting list and we will invite you to another Circle.',
          'place-released:' || target_circle || ':' || member)
  on conflict do nothing;
  insert into public.circle_audit(actor, action, target_id) values (auth.uid(), 'release_place', target_circle);
end;
$$;
revoke all on function public.circle_admin_release_place(uuid, uuid) from public, anon;
grant execute on function public.circle_admin_release_place(uuid, uuid) to authenticated;

-- Invite a waiting applicant into an existing Circle ---------------------------
create or replace function public.circle_admin_invite(target_circle uuid, member uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.circles;
  a public.circle_applications;
  slot text;
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  select * into c from public.circles where id = target_circle for update;
  if not found or c.status not in ('offered', 'active') then
    raise exception 'Only an upcoming or active Circle can take a new member.';
  end if;
  if exists (select 1 from public.events where circle_id = target_circle and circle_week = 1 and starts_at <= now()) then
    raise exception 'This Circle has already had its first meetup.';
  end if;
  if (select count(*) from public.circle_memberships where circle_id = target_circle and status <> 'left') >= 6 then
    raise exception 'This Circle is full (6 people).';
  end if;
  select * into a from public.circle_applications where profile_id = member for update;
  if not found or a.status <> 'waiting' then raise exception 'This applicant is no longer waiting. Refresh first.'; end if;
  if exists (select 1 from public.profiles p where p.id = member
              and (p.date_of_birth is null or not public.circle_has_profile_photo(p.id)))
     or not a.answers ? 'availability_slots' or coalesce(a.answers->>'phone', '') = '' then
    raise exception 'Ask this applicant to finish their birthday, photo, times and WhatsApp number first.';
  end if;
  slot := trim(to_char(c.start_date, 'Day')) || ' ' || public.circle_time_period(c.local_time);
  if not (coalesce(a.answers->'availability', '[]'::jsonb) ? slot) then
    raise exception 'This applicant is not free on the Circle''s day and time.';
  end if;
  if exists (
    select 1 from public.circle_memberships o
      join public.circle_applications oa on oa.profile_id = o.profile_id
     where o.circle_id = target_circle and o.status <> 'left'
       and not exists (select 1 from jsonb_array_elements_text(coalesce(a.answers->'languages', '[]'::jsonb)) l
                        where oa.answers->'languages' ? l.value)) then
    raise exception 'This applicant does not share a language with everyone in the Circle.';
  end if;
  if exists (
    select 1 from public.circle_exclusions x
      join public.circle_memberships o on o.circle_id = target_circle and o.status <> 'left'
     where (x.profile_id = member and x.excluded_profile_id = o.profile_id)
        or (x.profile_id = o.profile_id and x.excluded_profile_id = member)) then
    raise exception 'Someone in this Circle asked not to be matched with this applicant.';
  end if;
  insert into public.circle_memberships(circle_id, profile_id, status, payment_status, created_at)
  values (target_circle, member, 'invited', 'unpaid', now())
  on conflict (circle_id, profile_id) do update
    set status = 'invited', payment_status = 'unpaid', created_at = now();
  update public.circle_applications set status = 'invited', updated_at = now() where profile_id = member;
  insert into public.notifications(recipient_profile_id, kind, title, body)
  values (member, 'update', 'Your Circle is ready', 'Your Circle invitation and six-week schedule are ready to review.');
  insert into public.circle_audit(actor, action, target_id) values (auth.uid(), 'invite_to_circle', target_circle);
end;
$$;
revoke all on function public.circle_admin_invite(uuid, uuid) from public, anon;
grant execute on function public.circle_admin_invite(uuid, uuid) to authenticated;

-- Reminders: the member the day before, the organiser once overdue ------------
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
begin
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select m.profile_id, 'reminder', 'Your place is held until tomorrow',
         'Accept and pay for ' || c.name || ' by the end of tomorrow to keep your place.',
         'pay-by-reminder:' || m.circle_id || ':' || m.profile_id
    from public.circle_memberships m join public.circles c on c.id = m.circle_id
   where m.status = 'invited' and c.status in ('offered', 'active')
     and public.circle_pay_by(m.created_at, c.start_date) = today + 1
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support', 'A place is overdue',
         coalesce(p.first_name, 'A member') || ' has not paid for ' || c.name || ' by the pay-by date. Check Tikkie, then confirm the payment or release the place.',
         'pay-by-overdue:' || m.circle_id || ':' || m.profile_id
    from public.circle_memberships m
    join public.circles c on c.id = m.circle_id
    left join public.profiles p on p.id = m.profile_id
    cross join public.circle_admins a
   where m.status = 'invited' and c.status in ('offered', 'active')
     and today > public.circle_pay_by(m.created_at, c.start_date)
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_pay_by_reminders() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-pay-by-reminders', '30 * * * *',
                          'select public.queue_pay_by_reminders();');
  end if;
end;
$$;

commit;
