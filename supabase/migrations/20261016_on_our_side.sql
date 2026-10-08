-- Leaving with care, organisers kept in the loop, and a daily chat summary.
--
-- 1. Leaving asks why first. A paid member can switch to another group and
--    keep their €19 (their one free switch) before the second meetup — also
--    before the first one. A refund stays possible until 48 hours before the
--    first meetup, as the terms say, but it is a request the organiser
--    reviews, with the reason attached. No promised timeframe.
-- 2. Organisers hear about refund requests and declined invitations; a
--    reporter hears when their report has been handled.
-- 3. Organisers can remove a member from a Circle.
-- 4. Members get one evening summary when their Circle chat had new messages.
-- 5. Extra data for the screens, and two text fixes (evening 18–22, the
--    week-3 title).
begin;

alter table public.circle_refund_requests add column if not exists reason text;
alter table public.circle_refund_requests add column if not exists note text;
alter table public.circle_audit add column if not exists details text;

-- Member actions ----------------------------------------------------------------
create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.circle_memberships;
  p public.circle_payments;
  cid uuid;
  tid uuid;
  cname text;
  v_reason text := nullif(trim(coalesce(payload->>'reason', '')), '');
  v_note text := nullif(trim(coalesce(payload->>'note', '')), '');
begin
  if action in ('join_again', 'stop_looking') then
    if uid is null then raise exception 'Sign in first.'; end if;
    select * into m from public.circle_memberships where profile_id = uid and status <> 'left';
    if m.circle_id is null or m.status <> 'joined'
       or not exists (select 1 from public.circles where id = m.circle_id and status = 'completed') then
      raise exception 'You can look for a new Circle once your six weeks are finished.';
    end if;
    if action = 'join_again' then
      update public.circle_applications
         set status = 'waiting', submitted_at = now(), updated_at = now()
       where profile_id = uid and status <> 'waiting';
    else
      update public.circle_applications set status = 'joined', updated_at = now()
       where profile_id = uid and status = 'waiting';
    end if;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, m.circle_id);
    return;

  elsif action = 'past_message' then
    if uid is null then raise exception 'Sign in first.'; end if;
    cid := nullif(payload->>'circle_id', '')::uuid;
    if not exists (select 1 from public.circle_memberships_all
                    where circle_id = cid and profile_id = uid and archived_at is not null
                      and status = 'joined' and payment_status = 'paid') then
      raise exception 'This is not one of your Circles.';
    end if;
    if length(trim(coalesce(payload->>'body', ''))) not between 1 and 2000 then
      raise exception 'Write a message of 1–2000 characters.';
    end if;
    select id into tid from public.chat_threads where circle_id = cid;
    insert into public.messages(thread_id, sender_id, body) values (tid, uid, trim(payload->>'body'));
    return;

  elsif action = 'switch_group' then
    -- Keep the €19 and be matched again: the one free switch, possible
    -- until the second meetup starts.
    if uid is null then raise exception 'Sign in first.'; end if;
    perform 1 from public.profiles where id = uid for update;
    select * into m from public.circle_memberships where profile_id = uid and status <> 'left' for update;
    if m.circle_id is null or m.status <> 'joined' or m.payment_status <> 'paid' then
      raise exception 'Only members with a confirmed place can switch groups.';
    end if;
    if not exists (select 1 from public.circles where id = m.circle_id and status in ('offered', 'active')) then
      raise exception 'This Circle is not running.';
    end if;
    if exists (select 1 from public.events where circle_id = m.circle_id and circle_week = 2 and starts_at <= now()) then
      raise exception 'A switch is possible until your second meetup starts.';
    end if;
    if exists (select 1 from public.circle_moves where profile_id = uid and to_circle_id = m.circle_id)
       or exists (select 1 from public.circle_moves where profile_id = uid and outcome is null) then
      raise exception 'You have already used your free switch. A new Circle means joining and paying again.';
    end if;
    v_reason := coalesce(v_reason, 'No reason given');
    select * into p from public.circle_payments where profile_id = uid and circle_id = m.circle_id and status = 'paid';
    select name into cname from public.circles where id = m.circle_id;
    insert into public.circle_moves(profile_id, from_circle_id, payment_id, reason)
    values (uid, m.circle_id, p.id, left(v_reason || coalesce(' — ' || v_note, ''), 2000));
    update public.circle_memberships set status = 'left' where circle_id = m.circle_id and profile_id = uid;
    -- Back on the waiting list, keeping their original place in the queue.
    update public.circle_applications set status = 'waiting', updated_at = now() where profile_id = uid;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select cm.profile_id, 'update', 'A change in your Circle',
           'Someone has stepped away. Your remaining meetups are unchanged.',
           'circle-left:' || m.circle_id || ':' || uid
      from public.circle_memberships cm
     where cm.circle_id = m.circle_id and cm.status = 'joined' and cm.profile_id <> uid
    on conflict do nothing;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select a.profile_id, 'support', 'A member is switching groups',
           coalesce((select first_name from public.profiles where id = uid), 'A member') || ' left ' || coalesce(cname, 'their Circle')
             || ' and keeps their €19 for a new group. Reason: ' || left(v_reason || coalesce(' — ' || v_note, ''), 400),
           'circle-switch-admin:' || m.circle_id || ':' || uid
      from public.circle_admins a
    on conflict do nothing;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    values (uid, 'update', 'You’re switching groups',
            'Your €19 carries over to your next Circle. We’ll invite you when a group fits your times.',
            'circle-switch:' || m.circle_id || ':' || uid)
    on conflict do nothing;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, m.circle_id);
    return;

  elsif action = 'rejoin' then
    -- After leaving a Circle: back on the waiting list with the saved answers.
    if uid is null then raise exception 'Sign in first.'; end if;
    if exists (select 1 from public.circle_memberships where profile_id = uid and status <> 'left') then
      raise exception 'You are already in a Circle.';
    end if;
    update public.circle_applications
       set status = 'waiting', submitted_at = now(), updated_at = now()
     where profile_id = uid and status = 'withdrawn';
    if not found then raise exception 'Fill in your application first.'; end if;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, uid);
    return;

  elsif action = 'cancel_agreement' then
    if uid is null then raise exception 'Sign in first.'; end if;
    -- The app always asks why; older app versions send no reason.
    v_reason := coalesce(v_reason, 'No reason given');
    perform public.circle_action_before_second_circle(action, payload);
    update public.circle_refund_requests r
       set reason = left(v_reason, 200), note = left(v_note, 2000)
     where r.id = (select id from public.circle_refund_requests
                    where profile_id = uid order by requested_at desc limit 1)
       and r.reason is null;
    update public.notifications
       set title = 'You’ve left the Circle',
           body = case when body like '%€19%'
                       then 'Your place is released and your refund request is with the organiser. We’ll be in touch about it.'
                       else 'Your place and your unpaid agreement are cancelled.' end
     where recipient_profile_id = uid and title = 'Programme cancelled'
       and dedupe_key in (select 'cancel-final:' || id from public.circle_payments where profile_id = uid);
    return;
  end if;
  perform public.circle_action_before_second_circle(action, payload);
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Organisers hear about refund requests (with the reason) -----------------------
create or replace function public.circle_notify_refund_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.circle_is_admin() then return null; end if;  -- an organiser's own action
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select a.profile_id, 'support', 'A member asked for a refund',
         coalesce((select first_name from public.profiles where id = new.profile_id), 'A member')
           || ' left ' || coalesce((select name from public.circles where id = new.circle_id), 'their Circle')
           || ' and asked for their €19 back. Open the organiser panel to review it.',
         'refund-request-admin:' || new.id
    from public.circle_admins a
  on conflict do nothing;
  return null;
end;
$$;
revoke all on function public.circle_notify_refund_request() from public, anon, authenticated;
drop trigger if exists circle_refund_requests_notify on public.circle_refund_requests;
create trigger circle_refund_requests_notify
after insert on public.circle_refund_requests
for each row execute function public.circle_notify_refund_request();

-- Organisers hear when an invitation is declined (a place opened) --------------
create or replace function public.circle_notify_place_opened()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'invited' and new.status = 'left' and not public.circle_is_admin() then
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select a.profile_id, 'support', 'A place opened in a Circle',
           coalesce((select first_name from public.profiles where id = new.profile_id), 'Someone')
             || ' declined the invitation to ' || coalesce((select name from public.circles where id = new.circle_id), 'a Circle')
             || '. Invite someone from the Circles tab.',
           'place-opened:' || new.circle_id || ':' || new.profile_id
      from public.circle_admins a
    on conflict do nothing;
  end if;
  return null;
end;
$$;
revoke all on function public.circle_notify_place_opened() from public, anon, authenticated;
drop trigger if exists circle_place_opened_notify on public.circle_memberships_all;
create trigger circle_place_opened_notify
after update of status on public.circle_memberships_all
for each row execute function public.circle_notify_place_opened();

-- The reporter hears that their report was handled -----------------------------
create or replace function public.circle_notify_report_resolved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'resolved' and old.status is distinct from 'resolved' and new.profile_id is not null then
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    values (new.profile_id, 'support', 'Thanks for your report',
            'The organiser has looked into it. If anything else happens, report it again or email support@vriendtime.com.',
            'report-resolved:' || new.id)
    on conflict do nothing;
  end if;
  return null;
end;
$$;
revoke all on function public.circle_notify_report_resolved() from public, anon, authenticated;
drop trigger if exists circle_reports_resolved_notify on public.circle_reports;
create trigger circle_reports_resolved_notify
after update of status on public.circle_reports
for each row execute function public.circle_notify_report_resolved();

-- Organisers can remove a member ------------------------------------------------
create or replace function public.circle_admin_remove_member(target_circle uuid, member uuid, reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.circle_memberships;
  cname text;
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  if coalesce(length(trim(reason)), 0) < 3 then raise exception 'Note why, for your own records.'; end if;
  select * into m from public.circle_memberships where circle_id = target_circle and profile_id = member for update;
  if not found or m.status = 'left' then raise exception 'This person is not in the Circle.'; end if;
  select name into cname from public.circles where id = target_circle;
  update public.circle_memberships set status = 'left' where circle_id = target_circle and profile_id = member;
  update public.circle_payments set status = 'cancelled'
   where profile_id = member and circle_id = target_circle and status = 'awaiting_payment';
  -- Not put back on the waiting list automatically.
  update public.circle_applications set status = 'withdrawn', updated_at = now() where profile_id = member;
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  values (member, 'update', 'You’re no longer in ' || coalesce(cname, 'the Circle'),
          'The organiser has removed you from this Circle. If you think this is a mistake, email support@vriendtime.com.',
          'removed:' || target_circle || ':' || member)
  on conflict do nothing;
  if m.status = 'joined' then
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select cm.profile_id, 'update', 'A change in your Circle',
           'Someone has stepped away. Your remaining meetups are unchanged.',
           'circle-left:' || target_circle || ':' || member
      from public.circle_memberships cm
     where cm.circle_id = target_circle and cm.status = 'joined' and cm.profile_id <> member
    on conflict do nothing;
  end if;
  insert into public.circle_audit(actor, action, target_id, details)
  values (auth.uid(), 'remove_member', target_circle, member || ': ' || left(trim(reason), 1900));
end;
$$;
revoke all on function public.circle_admin_remove_member(uuid, uuid, text) from public, anon;
grant execute on function public.circle_admin_remove_member(uuid, uuid, text) to authenticated;

-- One evening summary of new chat messages --------------------------------------
create or replace function public.queue_chat_digests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare added integer;
begin
  insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
  select m.profile_id, 'update', 'New messages in your Circle',
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

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-chat-digest', '0 17 * * *', 'select public.queue_chat_digests();');
  end if;
end;
$$;

-- Retention, as the privacy policy says: notifications for a year, resolved
-- reports for a year after they were resolved. (Error logs: 30 days, already
-- scheduled; payment and refund records: seven years, not purged here.)
create or replace function public.purge_old_records()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare n integer := 0; added integer;
begin
  delete from public.notifications where created_at < now() - interval '1 year';
  get diagnostics added = row_count; n := n + added;
  delete from public.circle_reports where status = 'resolved' and resolved_at < now() - interval '1 year';
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.purge_old_records() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-purge-old-records', '50 3 * * *', 'select public.purge_old_records();');
  end if;
end;
$$;

-- Member snapshot: switching, and a clear state after leaving -------------------
create or replace function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_second_circle();
  cid uuid := nullif(result->'circle'->>'id', '')::uuid;
  last_left record;
begin
  if result->>'stage' = 'completed' then
    result := result || jsonb_build_object(
      'looking_again', exists (select 1 from public.circle_applications
                                where profile_id = uid and status = 'waiting'),
      'members', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', mm.profile_id,
                 'name', coalesce(mp.first_name, ma.answers->>'name', 'Member'),
                 'photo_path', mp.profile_photo_path,
                 'bio', coalesce(nullif(ma.answers->>'intro', ''), 'Looking forward to meeting the Circle.'),
                 'interests', ma.answers->'interests') order by mm.created_at)
          from public.circle_memberships_all mm
          join public.profiles mp on mp.id = mm.profile_id
          left join public.circle_applications ma on ma.profile_id = mm.profile_id
         where mm.circle_id = cid and mm.status = 'joined'), result->'members'));
  end if;
  if cid is not null then
    result := result || jsonb_build_object('switch', jsonb_build_object(
      'available',
        exists (select 1 from public.circle_memberships where circle_id = cid and profile_id = uid and status = 'joined' and payment_status = 'paid')
        and exists (select 1 from public.circles where id = cid and status in ('offered', 'active'))
        and not exists (select 1 from public.events where circle_id = cid and circle_week = 2 and starts_at <= now())
        and not exists (select 1 from public.circle_moves where profile_id = uid and (to_circle_id = cid or outcome is null))));
  elsif result->>'stage' = 'apply' then
    -- Left a Circle recently: say so, instead of restarting the application.
    select c.name, r.status as refund, a.status as app
      into last_left
      from public.circle_memberships_all m
      join public.circles c on c.id = m.circle_id
      left join public.circle_refund_requests r on r.profile_id = uid and r.circle_id = m.circle_id
      join public.circle_applications a on a.profile_id = uid
     where m.profile_id = uid and m.status = 'left' and a.status = 'withdrawn'
     order by coalesce(r.requested_at, m.created_at) desc
     limit 1;
    if found then
      result := result || jsonb_build_object('left_circle',
        jsonb_build_object('name', last_left.name, 'refund', last_left.refund));
    end if;
  end if;
  return result || jsonb_build_object('past_circles', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', c.id,
             'name', c.name,
             'members', coalesce((
               select jsonb_agg(coalesce(p.first_name, 'Member') order by o.created_at)
                 from public.circle_memberships_all o join public.profiles p on p.id = o.profile_id
                where o.circle_id = c.id and o.status = 'joined' and o.profile_id <> uid), '[]'::jsonb),
             'messages', coalesce((
               select jsonb_agg(x.item order by x.created_at) from (
                 select msg.created_at, jsonb_build_object(
                          'id', msg.id, 'created_at', msg.created_at,
                          'name', coalesce(p.first_name, 'Member'),
                          'body', msg.body, 'own', msg.sender_id = uid) item
                   from public.messages msg
                   join public.chat_threads t on t.id = msg.thread_id
                   join public.profiles p on p.id = msg.sender_id
                  where t.circle_id = c.id
                  order by msg.created_at desc limit 100) x), '[]'::jsonb))
           order by m.archived_at desc)
      from public.circle_memberships_all m join public.circles c on c.id = m.circle_id
     where m.profile_id = uid and m.archived_at is not null and m.status = 'joined'), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

-- Organiser snapshot: who left each Circle, fuller refund and report cards ------
create or replace function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb := public.circle_admin_snapshot_before_second_circle();
begin
  return result || jsonb_build_object(
    'exclusions',
      coalesce(result->'exclusions', '[]'::jsonb) || coalesce((
        select jsonb_agg(jsonb_build_array(x.profile_id::text, y.profile_id::text))
          from public.circle_memberships_all x
          join public.circle_memberships_all y
            on y.circle_id = x.circle_id and x.profile_id < y.profile_id
          join public.circle_applications ax on ax.profile_id = x.profile_id and ax.status = 'waiting'
          join public.circle_applications ay on ay.profile_id = y.profile_id and ay.status = 'waiting'
         where x.status = 'joined' and y.status = 'joined'), '[]'::jsonb),
    'circles', coalesce((
      select jsonb_agg(c || jsonb_build_object('left_ids', coalesce((
               select jsonb_agg(l.profile_id) from public.circle_memberships_all l
                where l.circle_id = (c->>'id')::uuid and l.status = 'left'), '[]'::jsonb))
             order by ord)
        from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)), '[]'::jsonb),
    'refunds', coalesce((
      select jsonb_agg(r || coalesce((
               select jsonb_build_object(
                        'reason', rr.reason, 'note', rr.note,
                        'circle_name', c.name,
                        'amount_cents', pay.amount_cents,
                        'paid_at', pay.received_at)
                 from public.circle_refund_requests rr
                 left join public.circles c on c.id = rr.circle_id
                 left join public.circle_payments pay on pay.id = rr.payment_id
                where rr.id = (r->>'id')::uuid), '{}'::jsonb)
             order by ord)
        from jsonb_array_elements(coalesce(result->'refunds', '[]'::jsonb)) with ordinality t(r, ord)), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(r || jsonb_build_object('email',
               (select email from public.profiles where id = (r->>'profile_id')::uuid))
             order by ord)
        from jsonb_array_elements(coalesce(result->'reports', '[]'::jsonb)) with ordinality t(r, ord)), '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- Text fixes inside the core function (copied from the live definition) --------
do $$
declare d text := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
begin
  d := replace(d, 'evening 17–22', 'evening 18–22');
  d := replace(d, 'Find out who’s secretly competitive.''', 'Find out who’s secretly competitive''');
  execute d;
end;
$$;

commit;
