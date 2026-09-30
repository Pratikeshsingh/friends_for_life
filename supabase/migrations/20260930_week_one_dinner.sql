-- Week one is a two-hour dinner everywhere in the app, so new Circles get
-- 'Dinner together' as their first meetup title instead of 'Coffee &
-- introductions'. Week six becomes 'One last get-together', because
-- 'evening' was wrong for morning and afternoon Circles. Built on the live
-- circle_action_core as of 2026-09-30; only these two titles change.
begin;

CREATE OR REPLACE FUNCTION public.circle_action_core(action text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
     or coalesce(extract(year from age(current_date,(payload->>'date_of_birth')::date))::int,0) not between 18 and 120
     or coalesce(jsonb_array_length(payload->'languages'),0)=0 or coalesce(jsonb_array_length(payload->'availability'),0)=0
     or coalesce(jsonb_array_length(payload->'interests'),0)=0 or coalesce(jsonb_array_length(payload->'activities'),0)=0
     or coalesce(jsonb_array_length(payload->'goals'),0)=0 or coalesce((payload->>'commitment')::boolean,false)=false then raise exception 'Complete your matching answers and six-week commitment.'; end if;
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
  if exists(select 1 from public.circle_applications a join public.profiles p on p.id=a.profile_id where a.profile_id=any(ids) and (p.date_of_birth is null or not public.circle_has_profile_photo(p.id) or not a.answers ? 'availability_slots')) then raise exception 'Ask these applicants to finish their birthday, photo and availability first.'; end if;
  if not exists(select 1 from public.circle_applications a cross join lateral jsonb_array_elements_text(a.answers->'languages') l where a.profile_id=any(ids) group by l.value having count(distinct a.profile_id)=cardinality(ids)) then raise exception 'Choose a group with at least one shared language.'; end if;
  proposed_date:=(payload->>'start_date')::date; proposed_time:=(payload->>'time')::time;
  if proposed_date<=current_date or proposed_time is null then raise exception 'Choose a future start date and time.'; end if;
  if public.circle_time_period(proposed_time) is null then raise exception 'Choose a two-hour slot within morning 09–12, afternoon 12–17, or evening 17–22.'; end if;
  if not exists(select 1 from public.circle_applications a cross join lateral jsonb_array_elements_text(a.answers->'availability') v where a.profile_id=any(ids) and v.value=(trim(to_char(proposed_date,'Day'))||' '||public.circle_time_period(proposed_time)) group by v.value having count(distinct a.profile_id)=cardinality(ids)) then raise exception 'Choose a day and time that everyone selected.'; end if;
  insert into public.circles(name,schedule,start_date,local_time) values(trim(payload->>'name'),trim(payload->>'schedule'),proposed_date,proposed_time) returning id into cid;
  insert into public.circle_memberships(circle_id,profile_id) select cid,unnest(ids);
  update public.circle_applications set status='invited',updated_at=now() where profile_id=any(ids);
  insert into public.chat_threads(circle_id,title,kind,created_by) values(cid,payload->>'name','group',uid);
  for i in 1..6 loop
   insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_area,activity_type)
   values(cid,i,(array['Dinner together','Bowling together','A walk & a warm drink','Choose something together','A plan of your own','One last get-together'])[i],'Alkmaar',((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam',(((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours',6,'open','Alkmaar','Circle meetup');
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
end;$function$;

-- Existing Circles: rename weeks one and six if the organiser has not
-- renamed them.
update public.events set title='Dinner together'
 where circle_week=1 and title='Coffee & introductions';
update public.events set title='One last get-together'
 where circle_week=6 and title='One more evening together';

commit;
