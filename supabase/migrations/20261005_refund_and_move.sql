-- Refunds and moving to another group.
--
-- The rules members agree to:
--   * Until 48 hours before the first meetup: cancel for a full €19 refund.
--   * Between the first and second meetup: no refund, but you can move to
--     another group once, free of charge. Your €19 carries over. Only in
--     that window, so nobody can sit through most of a programme and then
--     start a second one for free.
--   * After that one free move, joining another Circle means paying again.
--   * If VriendTime cancels a Circle, received fees are always refunded.
-- The old "refund within 48 hours after the first meetup" rule is retired.
begin;

-- One row per move. While placed_at and outcome are empty, the member is
-- waiting for a new group and their payment is a credit.
create table if not exists public.circle_moves (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  from_circle_id uuid references public.circles(id) on delete set null,
  payment_id uuid references public.circle_payments(id) on delete set null,
  reason text check (length(coalesce(reason, '')) <= 2000),
  requested_at timestamptz not null default now(),
  to_circle_id uuid references public.circles(id) on delete set null,
  placed_at timestamptz,
  outcome text check (outcome in ('placed', 'refunded'))
);
create unique index if not exists circle_moves_one_open
  on public.circle_moves (profile_id) where outcome is null;
alter table public.circle_moves enable row level security;
revoke all on public.circle_moves from anon, authenticated;

-- When the refund window closes for a Circle: 48 hours before week 1.
create or replace function public.circle_refund_until(target uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select starts_at - interval '48 hours' from public.events
   where circle_id = target and circle_week = 1;
$$;
revoke all on function public.circle_refund_until(uuid) from public, anon, authenticated;

-- A refund for someone who moved in points at the payment they made for
-- their first Circle.
create or replace function public.link_circle_refund_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select id into new.payment_id from public.circle_payments
   where profile_id = new.profile_id and circle_id = new.circle_id and status = 'paid';
  if new.payment_id is null then
    select payment_id into new.payment_id from public.circle_moves
     where profile_id = new.profile_id and to_circle_id = new.circle_id;
  end if;
  return new;
end;
$$;

-- Actions ------------------------------------------------------------------
alter function public.circle_action(text, jsonb) rename to circle_action_before_moves;
revoke all on function public.circle_action_before_moves(text, jsonb) from public, anon, authenticated;

create function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare
  uid uuid := auth.uid();
  m public.circle_memberships;
  p public.circle_payments;
  mv public.circle_moves;
  until timestamptz;
begin
  if uid is null then raise exception 'Sign in first.'; end if;

  if action = 'refund' then
    raise exception 'Refunds are possible until 48 hours before your first meetup. Between your first and second meetup you can move to another group once, free of charge.';

  elsif action = 'cancel_agreement' then
    perform 1 from public.profiles where id = uid for update;
    select * into p from public.circle_payments
     where profile_id = uid
       and (payload->>'id' is null or id = (payload->>'id')::uuid)
       and status in ('paid', 'awaiting_payment')
     order by agreed_at desc limit 1 for update;
    if not found then raise exception 'No agreement to cancel. Contact the organiser for help.'; end if;
    if exists (select 1 from public.circle_refund_requests where payment_id = p.id) then
      raise exception 'Your cancellation is already being handled.';
    end if;
    until := public.circle_refund_until(p.circle_id);
    if p.status = 'paid' and (until is null or now() >= until) then
      raise exception 'The refund window closed 48 hours before your first meetup. Between your first and second meetup you can move to another group once, free of charge.';
    end if;
    if p.status = 'paid' then
      insert into public.circle_refund_requests(profile_id, circle_id) values (uid, p.circle_id) on conflict do nothing;
    else
      update public.circle_payments set status = 'cancelled' where id = p.id;
    end if;
    update public.circle_memberships set status = 'left' where circle_id = p.circle_id and profile_id = uid;
    update public.circle_applications set status = 'withdrawn', updated_at = now() where profile_id = uid;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    values (uid, 'update', 'Programme cancelled',
            case when p.status = 'paid' then 'Your place is released. The organiser will return your €19; follow it in Profile.'
                 else 'Your place and unpaid agreement are cancelled.' end,
            'cancel-final:' || p.id)
    on conflict do nothing;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, p.id);
    return;

  elsif action = 'request_move' then
    perform 1 from public.profiles where id = uid for update;
    select * into m from public.circle_memberships where profile_id = uid and status <> 'left' for update;
    if m.circle_id is null or m.status <> 'joined' or m.payment_status <> 'paid' then
      raise exception 'Only members of an active Circle can move.';
    end if;
    if not exists (select 1 from public.circles where id = m.circle_id and status = 'active') then
      raise exception 'This Circle is not active.';
    end if;
    if not exists (select 1 from public.events where circle_id = m.circle_id and circle_week = 1 and starts_at <= now()) then
      raise exception 'Meet your Circle first. Before the first meetup you can still cancel for a refund.';
    end if;
    if not exists (select 1 from public.events where circle_id = m.circle_id and circle_week = 2 and starts_at > now()) then
      raise exception 'A move is possible until your second meetup starts.';
    end if;
    if exists (select 1 from public.circle_moves where profile_id = uid and to_circle_id = m.circle_id) then
      raise exception 'You have already used your free move. A new Circle means joining and paying again.';
    end if;
    if coalesce(length(payload->>'reason'), 0) > 2000 then raise exception 'Please shorten your note.'; end if;
    select * into p from public.circle_payments where profile_id = uid and circle_id = m.circle_id and status = 'paid';
    insert into public.circle_moves(profile_id, from_circle_id, payment_id, reason)
    values (uid, m.circle_id,
            coalesce(p.id, (select payment_id from public.circle_moves where profile_id = uid and to_circle_id = m.circle_id)),
            nullif(trim(payload->>'reason'), ''));
    update public.circle_memberships set status = 'left' where circle_id = m.circle_id and profile_id = uid;
    update public.circle_applications set status = 'waiting', updated_at = now() where profile_id = uid;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select cm.profile_id, 'update', 'A change in your Circle',
           'Someone has stepped away. Your remaining meetups are unchanged.',
           'circle-left:' || m.circle_id || ':' || uid
      from public.circle_memberships cm
     where cm.circle_id = m.circle_id and cm.status = 'joined' and cm.profile_id <> uid
    on conflict do nothing;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select a.profile_id, 'support', 'A member wants to move to another group',
           coalesce(nullif(trim(payload->>'reason'), ''), 'No reason given.') || ' They have already paid; their next Circle is free.',
           'circle-move-admin:' || m.circle_id || ':' || uid
      from public.circle_admins a
    on conflict do nothing;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    values (uid, 'update', 'You’re moving to a new group',
            'We’ll match you with a new Circle. Your €19 carries over, so you won’t pay again.',
            'circle-move:' || m.circle_id || ':' || uid)
    on conflict do nothing;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, m.circle_id);
    return;

  elsif action = 'join' then
    select * into mv from public.circle_moves where profile_id = uid and outcome is null for update;
    if found then
      select * into m from public.circle_memberships where profile_id = uid and status = 'invited' for update;
      if m.circle_id is null then raise exception 'An invitation is required.'; end if;
      if not exists (select 1 from public.circles where id = m.circle_id and status in ('offered', 'active') and start_date > current_date) then
        raise exception 'This invitation is no longer accepting responses. Contact the organiser.';
      end if;
      update public.circle_moves set to_circle_id = m.circle_id, placed_at = now(), outcome = 'placed' where id = mv.id;
      update public.circle_memberships set status = 'joined', payment_status = 'paid' where circle_id = m.circle_id and profile_id = uid;
      update public.circle_applications set status = 'joined', updated_at = now() where profile_id = uid;
      update public.circles set status = 'active' where id = m.circle_id and status = 'offered';
      insert into public.chat_participants(thread_id, profile_id)
      select id, uid from public.chat_threads where circle_id = m.circle_id on conflict do nothing;
      insert into public.notifications(recipient_profile_id, kind, title, body)
      values (uid, 'update', 'Your place is confirmed', 'Your €19 from your previous Circle covers this one. Open your Circle to meet the group.');
      insert into public.circle_audit(actor, action, target_id) values (uid, 'joined_with_move_credit', m.circle_id);
      return;
    end if;

  elsif action = 'admin_refund_move' then
    if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
    select * into mv from public.circle_moves where id = (payload->>'id')::uuid and outcome is null for update;
    if not found then raise exception 'This move is already settled.'; end if;
    if exists (select 1 from public.circle_memberships where profile_id = mv.profile_id and status = 'invited') then
      raise exception 'This member has an open invitation. Wait for their answer first.';
    end if;
    insert into public.circle_refund_requests(profile_id, circle_id) values (mv.profile_id, mv.from_circle_id) on conflict do nothing;
    update public.circle_moves set outcome = 'refunded', placed_at = now() where id = mv.id;
    update public.circle_applications set status = 'withdrawn', updated_at = now() where profile_id = mv.profile_id;
    insert into public.notifications(recipient_profile_id, kind, title, body)
    values (mv.profile_id, 'update', 'We’ll refund your €19',
            'We couldn’t find a new group in time, so the organiser will return your €19.');
    insert into public.circle_audit(actor, action, target_id) values (uid, action, mv.id);
    return;
  end if;

  perform public.circle_action_before_moves(action, payload);
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Leaving: while a refund is still possible, cancelling is the right route.
alter function public.circle_leave(text) rename to circle_leave_before_moves;
revoke all on function public.circle_leave_before_moves(text) from public, anon, authenticated;

create function public.circle_leave(reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare cid uuid;
begin
  select m.circle_id into cid from public.circle_memberships m
   where m.profile_id = auth.uid() and m.status = 'joined';
  if cid is not null
     and exists (select 1 from public.circle_payments p where p.profile_id = auth.uid() and p.circle_id = cid and p.status = 'paid')
     and now() < public.circle_refund_until(cid) then
    raise exception 'You can still cancel for a refund. Use Cancel my programme agreement in Profile.';
  end if;
  -- The older wrapper refused anyone within 14 days of paying; that rule
  -- is replaced by the one above, so go one layer further down.
  perform public.circle_leave_before_hardening(reason);
  delete from public.chat_participants cp using public.chat_threads t
   where cp.thread_id = t.id and cp.profile_id = auth.uid() and t.circle_id is not null
     and not exists (select 1 from public.circle_memberships
                      where profile_id = auth.uid() and circle_id = t.circle_id and status = 'joined');
end;
$$;
revoke all on function public.circle_leave(text) from public, anon;
grant execute on function public.circle_leave(text) to authenticated;

-- Member snapshot ----------------------------------------------------------
alter function public.circle_snapshot() rename to circle_snapshot_before_moves;
revoke all on function public.circle_snapshot_before_moves() from public, anon, authenticated;

create function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare
  result jsonb := public.circle_snapshot_before_moves();
  uid uuid := auth.uid();
  cid uuid := (result->'circle'->>'id')::uuid;
  until timestamptz;
  moved_in boolean;
begin
  result := result || jsonb_build_object(
    'refund_eligible', false,
    'move_credit', exists (select 1 from public.circle_moves where profile_id = uid and outcome is null),
    'payment_history', coalesce((
      select jsonb_agg(h || jsonb_build_object('can_cancel',
        (h->>'refund') is null and (
          h->>'status' = 'awaiting_payment'
          or (h->>'status' = 'paid' and now() < public.circle_refund_until((h->>'circle_id')::uuid)))))
      from jsonb_array_elements(coalesce(result->'payment_history', '[]'::jsonb)) h), '[]'::jsonb));
  if cid is not null then
    until := public.circle_refund_until(cid);
    moved_in := exists (select 1 from public.circle_moves where profile_id = uid and to_circle_id = cid);
    result := result || jsonb_build_object(
      'refund_until', until,
      -- Someone who moved in has no agreement of their own for this Circle;
      -- the layer below then returns null, which must stay an object.
      'payment_agreement', (case when jsonb_typeof(result->'payment_agreement') = 'object'
                                 then result->'payment_agreement' else '{}'::jsonb end) || jsonb_build_object(
        'can_cancel', not moved_in and exists (
          select 1 from public.circle_payments p
           where p.profile_id = uid and p.circle_id = cid
             and not exists (select 1 from public.circle_refund_requests r where r.payment_id = p.id)
             and (p.status = 'awaiting_payment' or (p.status = 'paid' and now() < until)))),
      'move', jsonb_build_object(
        'used', moved_in,
        'available', not moved_in
          and exists (select 1 from public.circle_memberships where circle_id = cid and profile_id = uid and status = 'joined' and payment_status = 'paid')
          and exists (select 1 from public.circles where id = cid and status = 'active')
          and exists (select 1 from public.events where circle_id = cid and circle_week = 1 and starts_at <= now())
          and exists (select 1 from public.events where circle_id = cid and circle_week = 2 and starts_at > now())));
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Organiser snapshot: who is moving, so they can be placed first ------------
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_moves;
revoke all on function public.circle_admin_snapshot_before_moves() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb := public.circle_admin_snapshot_before_moves();
begin
  return result || jsonb_build_object(
    'applications', coalesce((
      select jsonb_agg(a || jsonb_build_object('moving', mv.id is not null, 'move_id', mv.id) order by ord)
        from jsonb_array_elements(coalesce(result->'applications', '[]'::jsonb)) with ordinality t(a, ord)
        left join public.circle_moves mv on mv.profile_id = (a->>'profile_id')::uuid and mv.outcome is null),
      '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

commit;
