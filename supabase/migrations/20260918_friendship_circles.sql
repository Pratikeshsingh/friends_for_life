-- Apply after schema.sql and release_hardening.sql. Additive: preserves existing bookings.
-- Manual payment agreements are added by the following release migration.
begin;
create table public.circle_admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade
);
create table public.circle_applications (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check(status in ('draft','waiting','invited','joined','withdrawn')),
  submitted_at timestamptz,
  updated_at timestamptz not null default now()
);
create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(name) between 1 and 100),
  city text not null default 'Alkmaar',
  schedule text not null,
  start_date date not null,
  local_time time not null default '19:30',
  timezone text not null default 'Europe/Amsterdam' check(timezone='Europe/Amsterdam'),
  status text not null default 'offered' check(status in ('offered','active','completed','cancelled')),
  created_at timestamptz not null default now()
);
create table public.circle_memberships (
  circle_id uuid references public.circles(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'invited' check(status in ('invited','joined','left')),
  payment_status text not null default 'unpaid' check(payment_status in ('unpaid','paid','refunded')),
  created_at timestamptz not null default now(),
  primary key(circle_id,profile_id)
);
-- One pilot Circle per member. Later programmes can introduce a separate active-membership constraint.
create unique index circle_one_membership on public.circle_memberships(profile_id) where status<>'left';
alter table public.events add column circle_id uuid references public.circles(id) on delete cascade,
  add column circle_week integer check(circle_week between 1 and 6),
  add column completed_at timestamptz;
create unique index circle_programme_week on public.events(circle_id,circle_week) where circle_id is not null and circle_week is not null;
alter table public.event_attendees add column attended boolean;
alter table public.chat_threads add column circle_id uuid unique references public.circles(id) on delete cascade;
create table public.circle_check_ins (
  profile_id uuid references public.profiles(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  feeling text not null,
  connections uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  primary key(profile_id,event_id)
);
create table public.circle_outcomes (
  profile_id uuid references public.profiles(id) on delete cascade,
  circle_id uuid references public.circles(id) on delete cascade,
  answers jsonb not null,
  day90_answered_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(profile_id,circle_id)
);
create table public.circle_refund_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  circle_id uuid not null references public.circles(id) on delete cascade,
  status text not null default 'requested' check(status in ('requested','approved','declined','refunded')),
  requested_at timestamptz not null default now(),
  unique(profile_id,circle_id)
);
create table public.circle_audit (
  id bigint generated always as identity primary key,
  actor uuid references public.profiles(id) on delete set null,
  action text not null,
  target_id uuid,
  created_at timestamptz not null default now()
);
-- No table grants to app clients: all Circle reads/writes go through authenticated RPCs below.
alter table public.circle_admins enable row level security;
alter table public.circle_applications enable row level security;
alter table public.circles enable row level security;
alter table public.circle_memberships enable row level security;
alter table public.circle_check_ins enable row level security;
alter table public.circle_outcomes enable row level security;
alter table public.circle_refund_requests enable row level security;
alter table public.circle_audit enable row level security;
revoke all on public.circle_admins,public.circle_applications,public.circles,public.circle_memberships,public.circle_check_ins,public.circle_outcomes,public.circle_refund_requests,public.circle_audit from anon,authenticated;
grant all on public.circle_admins,public.circle_applications,public.circles,public.circle_memberships,public.circle_check_ins,public.circle_outcomes,public.circle_refund_requests,public.circle_audit to service_role;

create function public.circle_is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.circle_admins where profile_id=auth.uid());
$$;
revoke all on function public.circle_is_admin() from public;

-- Preserve the existing catalog columns while excluding private Circle events.
create or replace view public.event_catalog as
select id,title,subtitle,description,city,venue_area,reveal_venue_at,starts_at,ends_at,status,
activity_type,vibe,minimum_attendees,confirmed_count,capacity,image_url,tags,languages
from public.events where circle_id is null and status in ('open','full','closed');

-- Guard every attendance write, including old RPCs, with Circle membership.
create function public.guard_circle_attendance() returns trigger language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 select circle_id into cid from public.events where id=new.event_id;
 if cid is not null and not exists(select 1 from public.circle_memberships where circle_id=cid and profile_id=new.profile_id and status='joined' and payment_status='paid') then
   raise exception 'Join this Circle before confirming attendance.';
 end if;
 return new;
end;$$;
revoke all on function public.guard_circle_attendance() from public;
create trigger guard_circle_attendance before insert or update on public.event_attendees for each row execute function public.guard_circle_attendance();

create function public.circle_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare uid uuid:=auth.uid(); a public.circle_applications; m public.circle_memberships; c public.circles; result jsonb; first_end timestamptz;
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 select * into a from public.circle_applications where profile_id=uid;
 select * into m from public.circle_memberships where profile_id=uid and status<>'left';
 result:=jsonb_build_object('profile_id',uid,'is_admin',public.circle_is_admin(),'application',coalesce(a.answers,'{}'::jsonb),'stage',case when a.status='waiting' then 'waiting' else 'apply' end);
 if m.circle_id is null then return result; end if;
 select * into c from public.circles where id=m.circle_id;
 select completed_at into first_end from public.events where circle_id=c.id and circle_week=1;
 result:=result||jsonb_build_object('stage',case when m.status='invited' then 'invited' when c.status='completed' then 'completed' else 'active' end,
 'circle',to_jsonb(c),'payment',m.payment_status,'day90_due',current_date>=c.start_date+90,
 'refund_eligible',m.payment_status='paid' and first_end is not null and now() between first_end and first_end+interval '48 hours',
 'refund',(select status from public.circle_refund_requests where profile_id=uid and circle_id=c.id),
 'members',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',coalesce(p.first_name,ca.answers->>'name','Member'),'bio','Looking forward to getting to know the Circle.','interests',coalesce(ca.answers->'interests','[]'::jsonb)) order by cm.created_at) from public.circle_memberships cm join public.profiles p on p.id=cm.profile_id left join public.circle_applications ca on ca.profile_id=p.id where cm.circle_id=c.id and cm.status<>'left'),'[]'::jsonb),
 'meetups',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'week',e.circle_week,'title',e.title,'date',to_char(e.starts_at at time zone c.timezone,'YYYY-MM-DD'),'time',to_char(e.starts_at at time zone c.timezone,'HH24:MI'),'venue',coalesce(e.venue_name,'Location to be confirmed'),'completed',e.completed_at is not null,'confirmed',e.confirmed_count,'rsvp',exists(select 1 from public.event_attendees ea where ea.event_id=e.id and ea.profile_id=uid and ea.status='joined')) order by e.starts_at) from public.events e where e.circle_id=c.id and e.status<>'cancelled'),'[]'::jsonb),
 'check_ins',coalesce((select jsonb_agg(jsonb_build_object('id',event_id,'feeling',feeling)) from public.circle_check_ins where profile_id=uid),'[]'::jsonb),
 'outcome',(select answers from public.circle_outcomes where profile_id=uid and circle_id=c.id));
 if m.status='joined' then
  result:=result||jsonb_build_object('messages',coalesce((select jsonb_agg(x.item order by x.created_at) from (select msg.created_at,jsonb_build_object('id',msg.id,'created_at',msg.created_at,'name',coalesce(p.first_name,'Member'),'body',msg.body,'own',msg.sender_id=uid) item from public.messages msg join public.chat_threads t on t.id=msg.thread_id join public.profiles p on p.id=msg.sender_id where t.circle_id=c.id order by msg.created_at desc limit 100) x),'[]'::jsonb));
 end if;
 return result;
end;$$;

create function public.circle_action(action text,payload jsonb default '{}'::jsonb) returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); admin boolean:=public.circle_is_admin(); cm public.circle_memberships; cid uuid; eid uuid; tid uuid; ids uuid[]; n integer; i integer; first_end timestamptz; event_row public.events; proposed_date date; proposed_time time;
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 if octet_length(payload::text)>16000 then raise exception 'This request is too large.'; end if;
 select * into cm from public.circle_memberships where profile_id=uid and status<>'left';
 cid:=cm.circle_id;
 if action in ('draft','apply','withdraw') then
  if cid is not null then raise exception 'Contact the organiser to change an assigned application.'; end if;
  if action='withdraw' then update public.circle_applications set status='withdrawn',updated_at=now() where profile_id=uid; return; end if;
  if action='apply' then
   if coalesce(length(trim(payload->>'name')),0)=0 or coalesce(length(trim(payload->>'city')),0)=0
     or coalesce((payload->>'age')::integer,0) not between 18 and 120
     or coalesce(jsonb_array_length(payload->'languages'),0)=0 or coalesce(jsonb_array_length(payload->'availability'),0)=0
     or coalesce(jsonb_array_length(payload->'interests'),0)=0 or coalesce(jsonb_array_length(payload->'activities'),0)=0
     or coalesce(length(trim(payload->>'hopes')),0)=0 or coalesce((payload->>'commitment')::boolean,false)=false then raise exception 'Complete your matching answers and six-week commitment.'; end if;
  end if;
  insert into public.circle_applications(profile_id,answers,status,submitted_at) values(uid,payload,case when action='apply' then 'waiting' else 'draft' end,case when action='apply' then now() end)
  on conflict(profile_id) do update set answers=excluded.answers,status=excluded.status,submitted_at=coalesce(excluded.submitted_at,circle_applications.submitted_at),updated_at=now();
  return;
 end if;
 if action='admin_create' then
  if not admin then raise exception 'Organiser access required.'; end if;
  select array_agg(distinct value::uuid) into ids from jsonb_array_elements_text(payload->'members');
  if coalesce(cardinality(ids),0) not between 5 and 6 then raise exception 'Choose 5–6 applicants.'; end if;
  perform 1 from public.circle_applications where profile_id=any(ids) order by profile_id for update;
  if (select count(*) from public.circle_applications where profile_id=any(ids) and status='waiting')<>cardinality(ids) then raise exception 'An applicant is no longer waiting. Refresh first.'; end if;
  if not exists(select 1 from public.circle_applications a cross join lateral jsonb_array_elements_text(a.answers->'languages') l where a.profile_id=any(ids) group by l.value having count(distinct a.profile_id)=cardinality(ids)) then raise exception 'Choose a group with at least one shared language.'; end if;
  proposed_date:=(payload->>'start_date')::date; proposed_time:=(payload->>'time')::time;
  if proposed_date<=current_date or proposed_time is null then raise exception 'Choose a future start date and time.'; end if;
  if not exists(select 1 from public.circle_applications a cross join lateral jsonb_array_elements_text(a.answers->'availability') v where a.profile_id=any(ids) and v.value=(case extract(isodow from proposed_date)::int when 1 then 'Monday evening' when 2 then 'Tuesday evening' when 3 then 'Wednesday evening' when 4 then 'Thursday evening' when 5 then 'Friday evening' when 6 then 'Saturday afternoon' else 'Sunday afternoon' end) group by v.value having count(distinct a.profile_id)=cardinality(ids)) then raise exception 'The selected start day must match everyone’s availability.'; end if;
  insert into public.circles(name,schedule,start_date,local_time) values(trim(payload->>'name'),trim(payload->>'schedule'),proposed_date,proposed_time) returning id into cid;
  insert into public.circle_memberships(circle_id,profile_id) select cid,unnest(ids);
  update public.circle_applications set status='invited',updated_at=now() where profile_id=any(ids);
  insert into public.chat_threads(circle_id,title,kind,created_by) values(cid,payload->>'name','group',uid);
  for i in 1..6 loop
   insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_area,activity_type)
   values(cid,i,(array['Coffee & introductions','Bowling together','A walk & a warm drink','Choose something together','A plan of your own','One more evening together'])[i],'Alkmaar',((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam',(((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours',6,'open','Alkmaar','Circle meetup');
  end loop;
  insert into public.notifications(recipient_profile_id,kind,title,body) select unnest(ids),'update','Your Circle is ready','Your Circle invitation and six-week schedule are ready to review.';
  insert into public.circle_audit(actor,action,target_id) values(uid,action,cid);
  return;
 end if;
 if action in ('admin_schedule','admin_attendance') then
  if not admin then raise exception 'Organiser access required.'; end if;
  select * into event_row from public.events where id=(payload->>'id')::uuid and circle_id is not null for update;
  if not found then raise exception 'Circle meetup not found.'; end if;
  if action='admin_attendance' then
   if event_row.ends_at>now() then raise exception 'Record actual attendance after the meetup.'; end if;
   if not exists(select 1 from public.circle_memberships where circle_id=event_row.circle_id and profile_id=(payload->>'profile_id')::uuid and status='joined') then raise exception 'Choose a joined member of this Circle.'; end if;
   insert into public.event_attendees(event_id,profile_id,status,attended) values(event_row.id,(payload->>'profile_id')::uuid,case when (payload->>'attended')::boolean then 'joined' else 'no_show' end,(payload->>'attended')::boolean) on conflict(event_id,profile_id) do update set attended=excluded.attended;
  else
   if event_row.completed_at is not null then raise exception 'Completed meetups cannot be rescheduled.'; end if;
   proposed_date:=(payload->>'date')::date;proposed_time:=(payload->>'time')::time;
   if proposed_date is null or proposed_time is null or ((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')<=now() or coalesce(length(trim(payload->>'title')),0) not between 1 and 120 or coalesce(length(trim(payload->>'venue')),0) not between 1 and 180 then raise exception 'Choose an activity, place, and future date/time.'; end if;
   update public.events set title=trim(payload->>'title'),venue_name=trim(payload->>'venue'),starts_at=(proposed_date+proposed_time) at time zone 'Europe/Amsterdam',ends_at=((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours' where id=event_row.id;
   insert into public.notifications(recipient_profile_id,event_id,kind,title,body) select profile_id,event_row.id,'update','Your Circle plan changed','Open your Circle to see the updated activity, place, and time.' from public.circle_memberships where circle_id=event_row.circle_id and status<>'left';
  end if;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,event_row.id);return;
 end if;
 if action='join' then raise exception 'Payments are not open yet. No charge has been made.'; end if;
 if action='complete_meetup' then
  if not admin then raise exception 'Organiser access required.'; end if;
  select * into event_row from public.events where id=(payload->>'id')::uuid and circle_id is not null for update;
  if not found or event_row.ends_at>now() then raise exception 'Only a past Circle meetup can be marked complete.'; end if;
  update public.events set completed_at=coalesce(completed_at,ends_at) where id=event_row.id;
  if (select count(*) from public.events where circle_id=event_row.circle_id and circle_week is not null and completed_at is not null)=6 then update public.circles set status='completed' where id=event_row.circle_id; end if;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,event_row.id); return;
 end if;
 if cid is null or cm.status<>'joined' or cm.payment_status<>'paid' then raise exception 'Join your Circle to use this feature.'; end if;
 if action='message' then
  if length(trim(payload->>'body')) not between 1 and 2000 or payload->>'body' is null then raise exception 'Write a message of 1–2000 characters.'; end if;
  select id into tid from public.chat_threads where circle_id=cid;
  insert into public.messages(thread_id,sender_id,body) values(tid,uid,trim(payload->>'body')); return;
 elsif action in ('rsvp','check_in') then
  select * into event_row from public.events where id=(payload->>'id')::uuid and circle_id=cid for update;
  if not found then raise exception 'Meetup not found in your Circle.'; end if;
  if action='rsvp' then
   if event_row.starts_at<=now() or event_row.status='cancelled' then raise exception 'This meetup is no longer accepting RSVPs.'; end if;
   insert into public.event_attendees(event_id,profile_id,status) values(event_row.id,uid,case when (payload->>'going')::boolean then 'joined' else 'cancelled' end) on conflict(event_id,profile_id) do update set status=excluded.status;return;
  end if;
  if event_row.completed_at is null then raise exception 'Check in after the meetup.'; end if;
  if payload->>'feeling' not in ('😊 Great','🙂 Good','😐 Okay','🙁 Not for me') or payload->>'feeling' is null then raise exception 'Choose how the meetup felt.'; end if;
  select coalesce(array_agg(distinct value::uuid),'{}') into ids from jsonb_array_elements_text(coalesce(payload->'connections','[]'));
  if exists(select 1 from unnest(ids) p where p=uid or not exists(select 1 from public.circle_memberships where circle_id=cid and profile_id=p and status='joined')) then raise exception 'Choose members of your Circle.'; end if;
  insert into public.circle_check_ins(profile_id,event_id,feeling,connections) values(uid,event_row.id,payload->>'feeling',ids) on conflict(profile_id,event_id) do update set feeling=excluded.feeling,connections=excluded.connections;return;
 elsif action='outcome' then
  if not exists(select 1 from public.circles where id=cid and status='completed') then raise exception 'Share this after your programme.'; end if;
  if payload ? 'still_meeting' and not exists(select 1 from public.circles where id=cid and current_date>=start_date+90) then raise exception 'The 90-day check-in is not due yet.'; end if;
  if exists(select 1 from jsonb_each_text(payload) x where x.key not in ('plans','friend','outside','still_meeting') or x.value not in ('Yes','Not yet')) then raise exception 'Choose Yes or Not yet for the outcome questions.'; end if;
  insert into public.circle_outcomes(profile_id,circle_id,answers,day90_answered_at) values(uid,cid,payload,case when payload ? 'still_meeting' then now() end) on conflict(profile_id,circle_id) do update set answers=excluded.answers,day90_answered_at=coalesce(excluded.day90_answered_at,circle_outcomes.day90_answered_at),updated_at=now();return;
 elsif action='refund' then
  select completed_at into first_end from public.events where circle_id=cid and circle_week=1;
  if first_end is null or now() not between first_end and first_end+interval '48 hours' then raise exception 'The refund window is 48 hours after your first meetup ends. Contact the organiser for help.'; end if;
  insert into public.circle_refund_requests(profile_id,circle_id) values(uid,cid) on conflict(profile_id,circle_id) do nothing;return;
 elsif action='schedule' then
  proposed_date:=(payload->>'date')::date;proposed_time:=(payload->>'time')::time;
  if proposed_date is null or proposed_time is null or ((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')<=now() or coalesce(length(trim(payload->>'title')),0) not between 1 and 120 or coalesce(length(trim(payload->>'venue')),0) not between 1 and 180 then raise exception 'Choose an activity, place, and future date/time.'; end if;
  if payload->>'id' is not null then
   update public.events set title=trim(payload->>'title'),venue_name=trim(payload->>'venue'),starts_at=(proposed_date+proposed_time) at time zone 'Europe/Amsterdam',ends_at=((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours' where id=(payload->>'id')::uuid and circle_id=cid and circle_week>=4 and completed_at is null;
   if not found then raise exception 'Only upcoming weeks 4–6 can be changed by members.'; end if;
  else
   insert into public.events(circle_id,title,city,starts_at,ends_at,capacity,status,venue_name,venue_area,activity_type) values(cid,trim(payload->>'title'),'Alkmaar',(proposed_date+proposed_time) at time zone 'Europe/Amsterdam',((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours',6,'open',trim(payload->>'venue'),'Alkmaar','Circle meetup');
  end if;
  insert into public.circle_audit(actor,action,target_id) values(uid,action,cid);return;
 end if;
 raise exception 'Unknown Circle action.';
end;$$;

create function public.circle_admin_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
 if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
 return jsonb_build_object('applications',coalesce((select jsonb_agg(answers||jsonb_build_object('profile_id',profile_id,'status',status) order by submitted_at) from public.circle_applications where status='waiting'),'[]'::jsonb),
 'circles',coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('meetups',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'title',e.title,'date',to_char(e.starts_at at time zone 'Europe/Amsterdam','YYYY-MM-DD'),'completed',e.completed_at is not null,'time',to_char(e.starts_at at time zone 'Europe/Amsterdam','HH24:MI'),'venue',e.venue_name,'attendees',coalesce((select jsonb_agg(jsonb_build_object('profile_id',cm.profile_id,'name',p.first_name,'attended',ea.attended)) from public.circle_memberships cm join public.profiles p on p.id=cm.profile_id left join public.event_attendees ea on ea.profile_id=cm.profile_id and ea.event_id=e.id where cm.circle_id=c.id and cm.status='joined'),'[]'::jsonb)) order by e.starts_at) from public.events e where e.circle_id=c.id),'[]'::jsonb))) from public.circles c),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(to_jsonb(r)||jsonb_build_object('name',p.first_name)) from public.circle_refund_requests r join public.profiles p on p.id=r.profile_id),'[]'::jsonb),
 'metrics',jsonb_build_object('applications',(select count(*) from public.circle_applications where status<>'draft'),'paid',(select count(*) from public.circle_memberships where payment_status='paid'),'completed',(select count(*) from public.circles where status='completed'),
 'meetup_1_attended',(select count(*) from public.event_attendees ea join public.events e on e.id=ea.event_id where e.circle_week=1 and ea.attended=true),
 'week_3_attended',(select count(*) from public.event_attendees ea join public.events e on e.id=ea.event_id where e.circle_week=3 and ea.attended=true),
 'made_a_friend',(select count(*) from public.circle_outcomes where answers->>'friend'='Yes'),
 'outcome_responses',(select count(*) from public.circle_outcomes),
 'day90_eligible',(select count(*) from public.circle_memberships m join public.circles c on c.id=m.circle_id where c.start_date+90<=current_date and m.status='joined'),
 'day90_responses',(select count(*) from public.circle_outcomes where day90_answered_at is not null),
 'day90_still_meeting',(select count(*) from public.circle_outcomes where day90_answered_at is not null and answers->>'still_meeting'='Yes')));
end;$$;
revoke all on function public.circle_snapshot(),public.circle_action(text,jsonb),public.circle_admin_snapshot() from public;
grant execute on function public.circle_snapshot(),public.circle_action(text,jsonb),public.circle_admin_snapshot() to authenticated;

-- Schedule this service-only function hourly in Supabase Cron after deployment.
-- Existing notification read policies keep each notification private to its recipient.
create function public.queue_circle_notifications() returns integer language plpgsql security definer set search_path=public as $$
declare total integer:=0; added integer;
begin
 insert into public.notifications(recipient_profile_id,event_id,kind,title,body,dedupe_key)
 select m.profile_id,e.id,'reminder','See your Circle tomorrow',e.title||' · Open your Circle for the plan.','circle-reminder:'||e.id||':'||e.starts_at
 from public.events e join public.circle_memberships m on m.circle_id=e.circle_id
 where m.status='joined' and e.status<>'cancelled' and e.starts_at>now() and e.starts_at<=now()+interval '24 hours'
 on conflict do nothing;
 get diagnostics added=row_count;total:=total+added;
 insert into public.notifications(recipient_profile_id,event_id,kind,title,body,dedupe_key)
 select m.profile_id,e.id,'update','How did tonight feel?','Your private check-in is ready in your Circle.','circle-checkin:'||e.id
 from public.events e join public.circle_memberships m on m.circle_id=e.circle_id
 where m.status='joined' and e.completed_at is not null and e.completed_at>now()-interval '7 days'
 and not exists(select 1 from public.circle_check_ins ci where ci.profile_id=m.profile_id and ci.event_id=e.id)
 on conflict do nothing;
 get diagnostics added=row_count;total:=total+added;
 insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
 select m.profile_id,'update',case when current_date>=c.start_date+90 then '90 days on: how is your Circle?' else 'Your Circle is now yours' end,
 'Are you still making plans together? Share an update from your Circle. No further payment is required.',
 case when current_date>=c.start_date+90 then 'circle-day90:' else 'circle-graduation:' end||c.id
 from public.circles c join public.circle_memberships m on m.circle_id=c.id where c.status='completed' and m.status='joined'
 on conflict do nothing;
 get diagnostics added=row_count;return total+added;
end;$$;
revoke all on function public.queue_circle_notifications() from public;
grant execute on function public.queue_circle_notifications() to service_role;

commit;
