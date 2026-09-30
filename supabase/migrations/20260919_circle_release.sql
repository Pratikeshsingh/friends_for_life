begin;
-- Manual payments: an agreement never counts as money received.
create table public.circle_payments (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid references public.profiles(id) on delete set null,
 circle_id uuid references public.circles(id) on delete set null,
 amount_cents integer not null default 1900 check(amount_cents=1900),
 currency text not null default 'EUR' check(currency='EUR'),
 contact_email text,
 agreement_version text not null default 'founding-19-eur-v1',
 agreed_at timestamptz not null default now(),
 status text not null default 'awaiting_payment' check(status in ('awaiting_payment','paid','cancelled','refunded')),
 received_at timestamptz,
 received_by uuid references public.profiles(id) on delete set null,
 refunded_at timestamptz,
 refunded_by uuid references public.profiles(id) on delete set null,
 unique(profile_id,circle_id)
);
alter table public.circle_refund_requests drop constraint circle_refund_requests_profile_id_fkey;
alter table public.circle_refund_requests alter column profile_id drop not null;
alter table public.circle_refund_requests add foreign key(profile_id) references public.profiles(id) on delete set null;
alter table public.circle_refund_requests add column payment_id uuid references public.circle_payments(id) on delete set null;
create function public.link_circle_refund_payment() returns trigger language plpgsql security definer set search_path=public as $$
begin
 select id into new.payment_id from public.circle_payments where profile_id=new.profile_id and circle_id=new.circle_id and status='paid';
 return new;
end;$$;
revoke all on function public.link_circle_refund_payment() from public,anon,authenticated;
create trigger link_circle_refund before insert on public.circle_refund_requests for each row execute function public.link_circle_refund_payment();
create function public.close_circle_account() returns trigger language plpgsql security definer set search_path=public as $$
begin
 update public.circle_payments set status='cancelled' where profile_id=old.id and status='awaiting_payment';
 return old;
end;$$;
revoke all on function public.close_circle_account() from public,anon,authenticated;
create trigger close_circle_account before delete on public.profiles for each row execute function public.close_circle_account();
alter table public.circle_payments enable row level security;
revoke all on public.circle_payments from anon,authenticated;
grant all on public.circle_payments to service_role;
create table public.circle_reports (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid references public.profiles(id) on delete set null,
 circle_id uuid references public.circles(id) on delete cascade,
 message_id uuid references public.messages(id) on delete set null,
 reason text not null check(length(reason) between 5 and 2000),
 status text not null default 'open' check(status in ('open','resolved')),
 created_at timestamptz not null default now(),
 resolved_at timestamptz
);
alter table public.circle_reports enable row level security;
revoke all on public.circle_reports from anon,authenticated;
grant all on public.circle_reports to service_role;
create index circle_events_start_idx on public.events(circle_id,starts_at) where circle_id is not null;
create index circle_reports_open_idx on public.circle_reports(created_at) where status='open';

alter function public.circle_action(text,jsonb) rename to circle_action_core;
revoke all on function public.circle_action_core(text,jsonb) from public,anon,authenticated;
create function public.circle_action(action text,payload jsonb default '{}') returns void
language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); m public.circle_memberships; p public.circle_payments; r public.circle_refund_requests; cid uuid; target uuid; tid uuid;
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 if octet_length(payload::text)>16000 then raise exception 'This request is too large.'; end if;
 -- Lock the membership so consent, payment confirmation and declines cannot race.
 select * into m from public.circle_memberships where profile_id=uid and status<>'left' for update;
 if action='join' then
  if m.circle_id is null or m.status<>'invited' then raise exception 'An invitation is required.'; end if;
  if (payload->>'agree_to_pay') is distinct from 'true' then raise exception 'Please agree to the one-off €19 programme fee.'; end if;
  if not exists(select 1 from public.circles where id=m.circle_id and status in ('offered','active') and start_date>current_date) then raise exception 'This invitation is no longer accepting responses. Contact the organiser.'; end if;
  insert into public.circle_payments(profile_id,circle_id,contact_email) select uid,m.circle_id,email from public.profiles where id=uid on conflict(profile_id,circle_id) do nothing;
  insert into public.circle_audit(actor,action,target_id) values(uid,'agreed_to_pay_19_eur',m.circle_id);
  return;
 elsif action='cancel_agreement' then
  select * into p from public.circle_payments where profile_id=uid and circle_id=m.circle_id for update;
  if not found or p.agreed_at<now()-interval '14 days' then raise exception 'Contact the organiser for cancellation help.'; end if;
  if p.status='paid' then
   insert into public.circle_refund_requests(profile_id,circle_id) values(uid,m.circle_id) on conflict do nothing;
   insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key) values(uid,'update','Cancellation received','Your cancellation has been received. The organiser will arrange your €19 refund.','circle-cancel-'||p.id) on conflict do nothing;
  elsif p.status='awaiting_payment' then
   update public.circle_payments set status='cancelled' where id=p.id;
   update public.circle_memberships set status='left' where profile_id=uid and circle_id=m.circle_id;
   update public.circle_applications set status='withdrawn',updated_at=now() where profile_id=uid;
  end if;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,p.id); return;
 elsif action='decline' then
  if m.status is distinct from 'invited' then raise exception 'Only an unpaid invitation can be declined.'; end if;
  update public.circle_payments set status='cancelled' where profile_id=uid and circle_id=m.circle_id and status='awaiting_payment';
  update public.circle_memberships set status='left' where profile_id=uid and circle_id=m.circle_id;
  update public.circle_applications set status='waiting',updated_at=now() where profile_id=uid;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,m.circle_id); return;
 elsif action in ('admin_confirm_payment','admin_confirm_refund','admin_cancel_circle','admin_resolve_report','admin_hide_message') then
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  target:=(payload->>'id')::uuid;
  if action='admin_confirm_payment' then
   select * into p from public.circle_payments where id=target;
   if not found then raise exception 'Payment agreement not found.'; end if;
   perform 1 from public.circle_memberships where circle_id=p.circle_id and profile_id=p.profile_id for update;
   select * into p from public.circle_payments where id=target for update;
   if p.status='paid' then return; end if;
   if p.status<>'awaiting_payment' or not exists(select 1 from public.circle_memberships cm join public.circles c on c.id=cm.circle_id where cm.profile_id=p.profile_id and cm.circle_id=p.circle_id and cm.status='invited' and c.status in ('offered','active')) then raise exception 'This invitation is no longer payable.'; end if;
   if (payload->>'received') is distinct from 'true' then raise exception 'Confirm that you have received €19.'; end if;
   update public.circle_payments set status='paid',received_at=now(),received_by=uid where id=p.id;
   update public.circle_memberships set status='joined',payment_status='paid' where circle_id=p.circle_id and profile_id=p.profile_id;
   update public.circle_applications set status='joined',updated_at=now() where profile_id=p.profile_id;
   update public.circles set status='active' where id=p.circle_id and status='offered';
   insert into public.chat_participants(thread_id,profile_id) select id,p.profile_id from public.chat_threads where circle_id=p.circle_id on conflict do nothing;
   insert into public.notifications(recipient_profile_id,kind,title,body) values(p.profile_id,'update','Your place is confirmed','Your €19 payment has been received. Open your Circle to meet the group and RSVP.');
  elsif action='admin_confirm_refund' then
   select * into r from public.circle_refund_requests where id=target for update;
   if not found then raise exception 'Refund request not found.'; end if;
   if r.status='refunded' then return; end if;
   if (payload->>'returned') is distinct from 'true' then raise exception 'Confirm that the €19 has been returned.'; end if;
   update public.circle_payments set status='refunded',refunded_at=now(),refunded_by=uid where id=r.payment_id and status='paid';
   if not found then raise exception 'No received payment to refund.'; end if;
   update public.circle_refund_requests set status='refunded' where id=r.id;
   update public.circle_memberships set payment_status='refunded' where circle_id=r.circle_id and profile_id=r.profile_id;
   delete from public.chat_participants cp using public.chat_threads t where cp.thread_id=t.id and t.circle_id=r.circle_id and cp.profile_id=r.profile_id;
   if r.profile_id is not null then insert into public.notifications(recipient_profile_id,kind,title,body) values(r.profile_id,'update','Your refund is complete','The organiser has confirmed that your €19 has been returned. Contact us if it has not arrived.'); end if;
  elsif action='admin_cancel_circle' then
   perform 1 from public.circles where id=target and status in ('offered','active') for update;
   if not found then raise exception 'Only an upcoming or active Circle can be cancelled.'; end if;
   update public.circles set status='cancelled' where id=target;
   delete from public.chat_participants cp using public.chat_threads t where cp.thread_id=t.id and t.circle_id=target;
   update public.events set status='cancelled' where circle_id=target and completed_at is null;
   insert into public.circle_refund_requests(profile_id,circle_id) select profile_id,circle_id from public.circle_memberships where circle_id=target and payment_status='paid' on conflict do nothing;
   update public.circle_payments set status='cancelled' where circle_id=target and status='awaiting_payment';
   insert into public.notifications(recipient_profile_id,kind,title,body) select profile_id,'update','Your Circle has been cancelled','We’re sorry this Circle cannot go ahead. Received programme fees will be returned. Please contact the organiser for help.' from public.circle_memberships where circle_id=target and status<>'left';
  elsif action='admin_resolve_report' then
   update public.circle_reports set status='resolved',resolved_at=now() where id=target;
   if not found then raise exception 'Report not found.'; end if;
  else
   update public.messages msg set body='[Message removed by the organiser]' from public.chat_threads t where msg.id=target and t.id=msg.thread_id and t.circle_id is not null;
   if not found then raise exception 'Circle message not found.'; end if;
  end if;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,target);return;
 elsif action='report' then
  if m.circle_id is null then raise exception 'A Circle is required.'; end if;
  if coalesce(length(trim(payload->>'reason')),0) not between 5 and 2000 then raise exception 'Please describe the concern in 5–2000 characters.'; end if;
  target:=(payload->>'message_id')::uuid;
  if target is not null and not exists(select 1 from public.messages msg join public.chat_threads t on t.id=msg.thread_id where msg.id=target and t.circle_id=m.circle_id) then raise exception 'Message not found in your Circle.'; end if;
  if (select count(*) from public.circle_reports where profile_id=uid and created_at>now()-interval '1 hour')>=10 then raise exception 'Your reports have been received. Contact support for urgent help.'; end if;
  insert into public.circle_reports(profile_id,circle_id,message_id,reason) values(uid,m.circle_id,target,trim(payload->>'reason')); return;
 elsif action='leave_closed_circle' then
  if m.circle_id is null or not (m.payment_status='refunded' or (m.payment_status='unpaid' and exists(select 1 from public.circles where id=m.circle_id and status='cancelled'))) then raise exception 'Contact the organiser before leaving.'; end if;
  update public.circle_memberships set status='left' where circle_id=m.circle_id and profile_id=uid;
  update public.circle_applications set status='waiting',updated_at=now() where profile_id=uid; return;
 end if;
 if m.circle_id is not null and action not like 'admin_%' and action<>'complete_meetup' and exists(select 1 from public.circles where id=m.circle_id and status='cancelled') then raise exception 'This Circle has been cancelled. Contact the organiser for help.'; end if;
 if action='message' and (select count(*) from public.messages where sender_id=uid and created_at>now()-interval '1 minute')>=12 then raise exception 'Please wait a moment before sending more messages.'; end if;
 perform public.circle_action_core(action,payload);
end;$$;

alter function public.circle_snapshot() rename to circle_snapshot_core;
revoke all on function public.circle_snapshot_core() from public,anon,authenticated;
create function public.circle_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb:=public.circle_snapshot_core(); cid uuid:=(result->'circle'->>'id')::uuid;
begin
 result:=result||jsonb_build_object('payment_agreement',(select jsonb_build_object('id',id,'status',status,'agreed_at',agreed_at,'received_at',received_at,'amount_cents',amount_cents,'can_cancel',agreed_at>=now()-interval '14 days' and status in ('paid','awaiting_payment')) from public.circle_payments where profile_id=auth.uid() and circle_id=cid), 'unread_notifications',(select count(*) from public.notifications where recipient_profile_id=auth.uid() and read_at is null));
 if result->>'payment'='refunded' then result:=result||jsonb_build_object('stage','refunded','messages','[]'::jsonb);
 elsif result->'circle'->>'status'='cancelled' then result:=result||jsonb_build_object('stage','cancelled','messages','[]'::jsonb); end if;
 return result;
end;$$;
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_core;
revoke all on function public.circle_admin_snapshot_core() from public,anon,authenticated;
create function public.circle_admin_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb:=public.circle_admin_snapshot_core();
begin
 return result||jsonb_build_object(
 'refunds',coalesce((select jsonb_agg(to_jsonb(r)||jsonb_build_object('name',coalesce(p.first_name,'Deleted account'),'email',pay.contact_email)) from public.circle_refund_requests r left join public.profiles p on p.id=r.profile_id left join public.circle_payments pay on pay.id=r.payment_id),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg(to_jsonb(pay)||jsonb_build_object('name',p.first_name,'email',coalesce(p.email,pay.contact_email),'circle_name',c.name) order by pay.agreed_at desc) from public.circle_payments pay left join public.profiles p on p.id=pay.profile_id left join public.circles c on c.id=pay.circle_id),'[]'::jsonb),
 'reports',coalesce((select jsonb_agg(to_jsonb(r)||jsonb_build_object('name',p.first_name,'message',msg.body,'circle_name',c.name) order by r.created_at) from public.circle_reports r left join public.profiles p on p.id=r.profile_id left join public.messages msg on msg.id=r.message_id left join public.circles c on c.id=r.circle_id where r.status='open'),'[]'::jsonb));
end;$$;
revoke all on function public.circle_action(text,jsonb),public.circle_snapshot(),public.circle_admin_snapshot() from public,anon;
grant execute on function public.circle_action(text,jsonb),public.circle_snapshot(),public.circle_admin_snapshot() to authenticated;
create function public.circle_export_data() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 return jsonb_build_object('exported_at',now(),
  'profile',(select to_jsonb(p) from public.profiles p where id=uid),
  'application',(select to_jsonb(a) from public.circle_applications a where profile_id=uid),
  'memberships',coalesce((select jsonb_agg(to_jsonb(m)) from public.circle_memberships m where profile_id=uid),'[]'),
  'payments',coalesce((select jsonb_agg(to_jsonb(p)-'received_by'-'refunded_by') from public.circle_payments p where profile_id=uid),'[]'),
  'check_ins',coalesce((select jsonb_agg(to_jsonb(c)) from public.circle_check_ins c where profile_id=uid),'[]'),
  'outcomes',coalesce((select jsonb_agg(to_jsonb(o)) from public.circle_outcomes o where profile_id=uid),'[]'),
  'messages',coalesce((select jsonb_agg(to_jsonb(m)) from public.messages m where sender_id=uid),'[]'),
  'reports',coalesce((select jsonb_agg(to_jsonb(r)) from public.circle_reports r where profile_id=uid),'[]'));
end;$$;
revoke all on function public.circle_export_data() from public,anon;
grant execute on function public.circle_export_data() to authenticated;
commit;
