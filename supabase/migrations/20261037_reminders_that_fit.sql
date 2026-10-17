-- Pay-by reminders that fit the person.
--
-- The day before the pay-by date, everyone invited heard "Your €39 has not
-- arrived yet", also people who hadn't said yes, and people who moved here
-- with their fee already paid. Now:
--   * said yes, not paid yet: "Your €39 has not arrived yet" (as before);
--   * not answered yet: "Your invitation is waiting";
--   * moved here with their fee already paid: "Your invitation is waiting",
--     with nothing to pay.
-- When saying yes stays open after the pay-by date (20261036), one last
-- reminder the day before it closes. The organiser's overdue alert says
-- whether the person hasn't paid or hasn't said yes.
-- Each reminder opens Home. Can run again safely.
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

  -- Still open after the pay-by date: one last word the day before it closes.
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, 'reminder', 'Last chance to say yes',
         'Saying yes to ' || c.name || ' closes at the end of tomorrow, so the places can be booked for the group.',
         'accept-closing:' || m.circle_id || ':' || m.profile_id,
         jsonb_build_object('open', 'home')
    from public.circle_memberships m
    join public.circles c on c.id = m.circle_id
   where m.status = 'invited' and c.status in ('offered', 'active')
     and public.circle_accept_until(m.created_at, c.start_date) = today + 1
     and public.circle_accept_until(m.created_at, c.start_date) > public.circle_pay_by(m.created_at, c.start_date)
     and not exists (select 1 from public.circle_payments p
                      where p.profile_id = m.profile_id and p.circle_id = m.circle_id
                        and p.status in ('awaiting_payment', 'paid'))
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support', 'A place is overdue',
         coalesce(pr.first_name, 'A member')
           || case when exists (select 1 from public.circle_payments p
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
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_pay_by_reminders() from public, anon, authenticated;

-- After paying, members were told "Your six programme meetups are included",
-- which reads as if the meals were included too (patched in place).
do $$
declare
  d text := pg_get_functiondef('public.circle_action_before_moves(text, jsonb)'::regprocedure);
  old_text text := 'Your €39 payment has been received. Your six programme meetups are included. Open your Circle to meet the group.';
  new_text text := 'Your €39 payment has been received, so your place is confirmed. Open your Circle to meet the group and see the six weeks.';
begin
  if position(new_text in d) = 0 then
    if position(old_text in d) = 0 then raise exception 'payment message patch did not apply'; end if;
    execute replace(d, old_text, new_text);
  end if;
end;
$$;
