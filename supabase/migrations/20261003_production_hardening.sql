-- Apply after all 20261002 migrations. Keeps the existing permission wrappers.
begin;
alter table public.events add column if not exists created_by uuid references public.profiles(id) on delete set null,
 add column if not exists updated_by uuid references public.profiles(id) on delete set null,
 add column if not exists plan_version integer not null default 0,
 add column if not exists meeting_point text,
 add column if not exists cost_notes text,
 add column if not exists accessibility_notes text;
alter table public.circle_payments add column if not exists payment_reported_at timestamptz;
create table public.circle_action_requests (
 profile_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null, action text not null, payload jsonb not null,
 created_at timestamptz not null default now(), primary key(profile_id,request_id));
alter table public.circle_action_requests enable row level security;
revoke all on public.circle_action_requests from anon,authenticated;

alter function public.circle_action(text,jsonb) rename to circle_action_before_hardening;
revoke all on function public.circle_action_before_hardening(text,jsonb) from public,anon,authenticated;
create function public.circle_action(action text,payload jsonb default '{}') returns void
language plpgsql security definer set search_path=public as $$
#variable_conflict use_variable
declare uid uuid:=auth.uid(); m public.circle_memberships; p public.circle_payments;
 e public.events; prior public.circle_action_requests; eid uuid; tid uuid;
 dt timestamptz; changed boolean:=false;
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 if octet_length(payload::text)>16000 then raise exception 'This request is too large.'; end if;
 -- All member writes for this account serialize, including retries.
 perform 1 from public.profiles where id=uid for update;
 select * into m from public.circle_memberships where profile_id=uid and status<>'left' for update;
 if action in ('schedule','message','report') and payload->>'request_id' is not null then
  select * into prior from public.circle_action_requests where profile_id=uid and request_id=(payload->>'request_id')::uuid;
  if found then
   if prior.action<>action or prior.payload<>payload then raise exception 'This request was already saved. Refresh before changing it.'; end if;
   return;
  end if;
  insert into public.circle_action_requests(profile_id,request_id,action,payload) values(uid,(payload->>'request_id')::uuid,action,payload);
 end if;
 if action='cancel_agreement' then
  select * into p from public.circle_payments where profile_id=uid
   and (payload->>'id' is null or id=(payload->>'id')::uuid)
   and agreed_at>=now()-interval '14 days' and status in ('paid','awaiting_payment')
   order by agreed_at desc limit 1 for update;
  if not found then raise exception 'No eligible agreement found. Contact the organiser for help.'; end if;
  if p.status='paid' then
   insert into public.circle_refund_requests(profile_id,circle_id) values(uid,p.circle_id) on conflict do nothing;
  else update public.circle_payments set status='cancelled' where id=p.id;
  end if;
  update public.circle_memberships set status='left' where circle_id=p.circle_id and profile_id=uid;
  update public.circle_applications set status='withdrawn',updated_at=now() where profile_id=uid and not exists(select 1 from public.circle_memberships where profile_id=uid and status<>'left');
  delete from public.chat_participants cp using public.chat_threads t where cp.thread_id=t.id and t.circle_id=p.circle_id and cp.profile_id=uid;
  delete from public.event_attendees ea using public.events ev where ea.event_id=ev.id and ev.circle_id=p.circle_id and ea.profile_id=uid and ev.starts_at>now();
  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
   values(uid,'update','Programme cancelled',case when p.status='paid' then 'Your place is released. Your refund is pending; follow it in Profile.' else 'Your place and unpaid agreement are cancelled.' end,'cancel-final:'||p.id) on conflict do nothing;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,p.id);
  return;
 elsif action='payment_sent' then
  update public.circle_payments set payment_reported_at=coalesce(payment_reported_at,now())
   where profile_id=uid and circle_id=m.circle_id and status='awaiting_payment';
  if not found then raise exception 'No pending payment agreement.'; end if;
  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
   select profile_id,'support','Payment needs verification','A member reported sending their programme payment. Check the bank transfer before confirming.','payment-reported:'||m.circle_id||':'||uid from public.circle_admins on conflict do nothing;
  return;
 elsif action in ('schedule','cancel_extra') then
  if m.status is distinct from 'joined' or m.payment_status is distinct from 'paid' then raise exception 'An active paid membership is required.'; end if;
  if not exists(select 1 from public.circles where id=m.circle_id and status in ('active','completed')) then raise exception 'This Circle is not active.'; end if;
  if payload->>'id' is not null then
   select * into e from public.events where id=(payload->>'id')::uuid and circle_id=m.circle_id for update;
   if not found or e.starts_at<=now() or e.completed_at is not null or e.status='cancelled' then raise exception 'Only upcoming plans can be changed.'; end if;
   if e.circle_week is not null and (e.circle_week<4 or action='cancel_extra') then raise exception 'The organiser manages this programme meetup.'; end if;
   if e.circle_week is null and e.created_by is distinct from uid and not public.circle_is_admin() then raise exception 'Only the creator or organiser can change this extra plan.'; end if;
   if payload->>'version' is null or (payload->>'version')::int<>e.plan_version then raise exception 'This plan changed. Close and reopen it to see the latest version.'; end if;
   eid:=e.id;
   if action='cancel_extra' then
    update public.events set status='cancelled',plan_version=plan_version+1,updated_by=uid where id=eid;
   end if;
  elsif action='cancel_extra' then raise exception 'Choose a plan.';
  end if;
  if action='schedule' then
   if coalesce(length(trim(payload->>'title')),0) not between 1 and 120 or coalesce(length(trim(payload->>'venue')),0) not between 1 and 180 then raise exception 'Add an activity and place.'; end if;
   if exists(select 1 from jsonb_each_text(payload) x where x.key in ('venue_address','meeting_point','cost_notes','accessibility_notes') and length(x.value)>300) then raise exception 'Keep each detail under 300 characters.'; end if;
   if e.circle_week is not null then dt:=e.starts_at;
   else dt:=((payload->>'date')::date+(payload->>'time')::time) at time zone 'Europe/Amsterdam'; end if;
   if dt is null or dt<=now() then raise exception 'Choose a future date and time.'; end if;
   if eid is null then
    insert into public.events(circle_id,title,city,starts_at,ends_at,capacity,status,venue_name,venue_area,activity_type,created_by)
     values(m.circle_id,trim(payload->>'title'),'Alkmaar',dt,dt+interval '2 hours',6,'open',trim(payload->>'venue'),'Alkmaar','Circle meetup',uid) returning id into eid;
   end if;
   update public.events set title=trim(payload->>'title'),venue_name=trim(payload->>'venue'),
    starts_at=dt,ends_at=case when circle_week is not null then ends_at else dt+interval '2 hours' end,
    venue_address=coalesce(nullif(trim(payload->>'venue_address'),''),venue_address),
    meeting_point=nullif(trim(payload->>'meeting_point'),''),cost_notes=nullif(trim(payload->>'cost_notes'),''),accessibility_notes=nullif(trim(payload->>'accessibility_notes'),''),
    updated_by=uid,plan_version=plan_version+1 where id=eid;
  end if;
  insert into public.notifications(recipient_profile_id,event_id,kind,title,body)
   select profile_id,eid,'update',case when action='cancel_extra' then 'Extra plan cancelled' else 'Your Circle has a plan update' end,'Open the plan to see the latest details.'
   from public.circle_memberships where circle_id=m.circle_id and status='joined';
  insert into public.circle_audit(actor,action,target_id) values(uid,action,eid);
  return;
 elsif action='outcome' then
  update public.circles c set status='completed' where c.id=m.circle_id and c.status='active'
   and (select count(*) from public.events where circle_id=c.id and circle_week is not null and ends_at<=now())=6;
 end if;
 perform public.circle_action_before_hardening(action,payload);
 if action='admin_schedule' then
  update public.events set plan_version=plan_version+1,updated_by=uid,
   venue_address=coalesce(nullif(payload->>'venue_address',''),venue_address),meeting_point=coalesce(payload->>'meeting_point',meeting_point),
   cost_notes=coalesce(payload->>'cost_notes',cost_notes),accessibility_notes=coalesce(payload->>'accessibility_notes',accessibility_notes)
   where id=(payload->>'id')::uuid;
 elsif action='admin_confirm_refund' then
  update public.circle_memberships cm set status='left' from public.circle_refund_requests r where r.id=(payload->>'id')::uuid and cm.profile_id=r.profile_id and cm.circle_id=r.circle_id;
 elsif action='admin_confirm_payment' then
  update public.notifications set body='Your €19 payment has been received. Your six programme meetups are included. Open your Circle to meet the group.'
   where recipient_profile_id=(select profile_id from public.circle_payments where id=(payload->>'id')::uuid) and title='Your place is confirmed';
 end if;
end;$$;
revoke all on function public.circle_action(text,jsonb) from public,anon;
grant execute on function public.circle_action(text,jsonb) to authenticated;

-- Existing clients also receive the safe leave behaviour.
alter function public.circle_leave(text) rename to circle_leave_before_hardening;
revoke all on function public.circle_leave_before_hardening(text) from public,anon,authenticated;
create function public.circle_leave(reason text default null) returns void language plpgsql security definer set search_path=public as $$
#variable_conflict use_variable
begin
 if exists(select 1 from public.circle_payments p join public.circle_memberships m on m.profile_id=p.profile_id and m.circle_id=p.circle_id
   where p.profile_id=auth.uid() and m.status='joined' and p.status='paid' and p.agreed_at>=now()-interval '14 days') then
  raise exception 'You can still cancel your agreement and request a refund. Use Cancel my programme agreement in Profile.';
 end if;
 perform public.circle_leave_before_hardening(reason);
 delete from public.chat_participants cp using public.chat_threads t where cp.thread_id=t.id and cp.profile_id=auth.uid()
  and t.circle_id is not null and not exists(select 1 from public.circle_memberships where profile_id=auth.uid() and circle_id=t.circle_id and status='joined');
end;$$;
revoke all on function public.circle_leave(text) from public,anon;
grant execute on function public.circle_leave(text) to authenticated;

-- Check-in/refund clocks follow the event end, not an organiser clicking Complete.
do $$ declare definition text:=pg_get_functiondef('public.circle_action_core(text,jsonb)'::regprocedure); begin
 definition:=replace(definition,'if event_row.completed_at is null then raise exception', 'if event_row.ends_at>now() then raise exception');
 definition:=replace(definition,'select completed_at into first_end','select ends_at into first_end');
 execute definition;
end;$$;

alter function public.circle_snapshot() rename to circle_snapshot_before_hardening;
revoke all on function public.circle_snapshot_before_hardening() from public,anon,authenticated;
create function public.circle_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
#variable_conflict use_variable
declare result jsonb:=public.circle_snapshot_before_hardening(); cid uuid:=(result->'circle'->>'id')::uuid; uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 result:=result||jsonb_build_object('payment_history',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'circle_id',p.circle_id,'reference','VT-'||upper(replace(p.id::text,'-','')),'status',p.status,'agreed_at',p.agreed_at,'refund',r.status,
 'can_cancel',p.agreed_at>=now()-interval '14 days' and p.status in ('paid','awaiting_payment') and r.id is null) order by p.agreed_at desc)
 from public.circle_payments p left join public.circle_refund_requests r on r.payment_id=p.id where p.profile_id=uid),'[]'));
 if cid is not null then
  result:=result||jsonb_build_object('payment_agreement',coalesce(result->'payment_agreement','{}')||coalesce((select jsonb_build_object('reference','VT-'||upper(replace(id::text,'-','')),'payment_reported_at',payment_reported_at) from public.circle_payments where profile_id=uid and circle_id=cid),'{}'));
  result:=result||jsonb_build_object('meetups',coalesce((select jsonb_agg((m-'venue_hidden')||jsonb_build_object(
   'starts_at',e.starts_at,'ends_at',e.ends_at,'completed',e.ends_at<=now() or e.completed_at is not null,
   'venue_hidden',e.circle_week between 1 and 3 and e.starts_at>now()+interval '24 hours',
   'venue',case when e.circle_week between 1 and 3 and e.starts_at>now()+interval '24 hours' then null else e.venue_name end,
   'venue_address',case when e.circle_week between 1 and 3 and e.starts_at>now()+interval '24 hours' then null else e.venue_address end,
   'meeting_point',case when e.circle_week between 1 and 3 and e.starts_at>now()+interval '24 hours' then null else e.meeting_point end,
   'cost_notes',e.cost_notes,'accessibility_notes',e.accessibility_notes,'created_by',e.created_by,'plan_version',e.plan_version,
   'updated_by_name',(select first_name from public.profiles where id=e.updated_by)) order by e.starts_at,e.id)
   from jsonb_array_elements(result->'meetups') m join public.events e on e.id=(m->>'id')::uuid),'[]'));
  result:=result||jsonb_build_object('refund_eligible',result->>'payment'='paid' and exists(select 1 from public.events where circle_id=cid and circle_week=1 and now() between ends_at and ends_at+interval '48 hours'),
   'paid_members',(select count(*) from public.circle_memberships where circle_id=cid and status='joined' and payment_status='paid'));
  if result->>'stage'='active' and (select count(*) from public.events where circle_id=cid and circle_week is not null and ends_at<=now())=6 then result:=result||'{"stage":"completed"}'::jsonb; end if;
 end if;
 return result;
end;$$;
revoke all on function public.circle_snapshot() from public,anon;
grant execute on function public.circle_snapshot() to authenticated;

create function public.circle_messages_before(before_time timestamptz,before_id uuid) returns jsonb language plpgsql stable security definer set search_path=public as $$
#variable_conflict use_variable
declare cid uuid; begin
 select m.circle_id into cid from public.circle_memberships m join public.circles c on c.id=m.circle_id where m.profile_id=auth.uid() and m.status='joined' and m.payment_status='paid' and c.status in ('active','completed');
 if cid is null then raise exception 'An active paid membership is required.'; end if;
 return coalesce((select jsonb_agg(item order by created_at,id) from (select msg.created_at,msg.id,jsonb_build_object('id',msg.id,'created_at',msg.created_at,'name',p.first_name,'body',msg.body,'own',msg.sender_id=auth.uid()) item
 from public.messages msg join public.chat_threads t on t.id=msg.thread_id join public.profiles p on p.id=msg.sender_id
 where t.circle_id=cid and (msg.created_at,msg.id)<(before_time,before_id) order by msg.created_at desc,msg.id desc limit 100) page),'[]');
end;$$;
revoke all on function public.circle_messages_before(timestamptz,uuid) from public,anon;
grant execute on function public.circle_messages_before(timestamptz,uuid) to authenticated;

create table public.app_error_events(reference text primary key, area text not null, kind text not null, build text not null, created_at timestamptz not null default now(),profile_id uuid references public.profiles(id) on delete set null);
alter table public.app_error_events enable row level security;
revoke all on public.app_error_events from anon,authenticated;
create function public.record_app_error(area text,kind text,build text,reference text) returns void language plpgsql security definer set search_path=public as $$
#variable_conflict use_variable
begin
 if auth.uid() is null then raise exception 'Sign in first.'; end if;
 if length(area)>60 or length(kind)>80 or length(build)>80 or length(reference)>80 then return; end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if exists(select 1 from public.app_error_events where profile_id=auth.uid() and created_at>now()-interval '30 seconds') then return; end if;
 insert into public.app_error_events values(reference,area,kind,build,now(),auth.uid()) on conflict do nothing;
 delete from public.app_error_events where created_at<now()-interval '30 days';
end;$$;
revoke all on function public.record_app_error(text,text,text,text) from public,anon;
grant execute on function public.record_app_error(text,text,text,text) to authenticated;
commit;
