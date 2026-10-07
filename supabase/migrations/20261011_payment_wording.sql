-- Clearer member messages about the pay-by date: a place is only ever held
-- back or released because the €19 has not arrived, never for anything else.
begin;

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
  values (member, 'update', 'Your place was released: payment not received',
          'We did not receive your €19 for ' || coalesce(circle_name, 'your Circle') || ' by your pay-by date, so your place has been released. That is the only reason. You are back on the waiting list, keeping your place in the queue, and we will invite you to another Circle.',
          'place-released:' || target_circle || ':' || member)
  on conflict do nothing;
  insert into public.circle_audit(actor, action, target_id) values (auth.uid(), 'release_place', target_circle);
end;
$$;
revoke all on function public.circle_admin_release_place(uuid, uuid) from public, anon;
grant execute on function public.circle_admin_release_place(uuid, uuid) to authenticated;

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
  select m.profile_id, 'reminder', 'Your €19 has not arrived yet',
         'Your place in ' || c.name || ' is confirmed once your €19 arrives. Pay by the end of tomorrow to keep it.',
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

commit;
