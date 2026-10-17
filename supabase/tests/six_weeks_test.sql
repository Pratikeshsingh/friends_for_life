-- The six weeks, version two: €39 with two activities included, three plans,
-- week 5 for the group, a VriendTime nudge in the chat, and booking emails.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
create function pg_temp.version(event uuid) returns int language sql stable as $$
  select (m->>'plan_version')::int from jsonb_array_elements(public.circle_snapshot()->'meetups') m where m->>'id'=event::text $$;
create function pg_temp.week(k text, w int) returns public.circle_programme_template language sql stable as $$
  select * from public.circle_programme_template where city='Alkmaar' and kind=k and week=w $$;

-- 1. €39 everywhere.
select pg_temp.assert_true(not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and prosrc like '%€19%'),'no message names €19 any more');
select pg_temp.assert_true(exists(select 1 from pg_proc where pronamespace='public'::regnamespace and prosrc like '%€39%'),'messages name €39');
select pg_temp.assert_true((select column_default from information_schema.columns where table_schema='public' and table_name='circle_payments' and column_name='amount_cents')='3900','new agreements are for €39');
select pg_temp.assert_true((select column_default from information_schema.columns where table_schema='public' and table_name='circle_payments' and column_name='agreement_version') like '%circle-39-eur-v1%','and say so in their version');

-- 2. The three plans.
select pg_temp.assert_true((select count(*) from public.circle_programme_template where city='Alkmaar' and kind in ('morning','afternoon','evening'))=18,'three full plans');
select pg_temp.assert_true((select string_agg(title,' | ' order by week) from public.circle_programme_template where city='Alkmaar' and kind='evening')
  ='Hello, new faces | Find out who’s secretly competitive | Go beyond “what do you do?” | The rematch | Your call | Graduation: a new beginning','the evening weeks');
select pg_temp.assert_true((pg_temp.week('morning',4)).title='Say cheese' and (pg_temp.week('morning',4)).venue='Hollands Kaasmuseum','mornings: the cheese museum, indoors');
select pg_temp.assert_true((select string_agg(to_char(start_time,'HH24:MI'),',' order by week) from public.circle_programme_template where city='Alkmaar' and kind='evening')='20:00,20:00,19:00,20:00,20:00,20:00','evenings at 20:00, the dinner at 19:00');
select pg_temp.assert_true((select string_agg(week::text,',' order by week) from public.circle_programme_template where city='Alkmaar' and kind='afternoon' and included)='2,4','two activities included');
select pg_temp.assert_true((select bool_and(venue is null) from public.circle_programme_template where city='Alkmaar' and week=5 and kind in ('morning','afternoon','evening')),'week 5 has no place: the group decides');
select pg_temp.assert_true((select bool_and(venue='Hofman') from public.circle_programme_template where city='Alkmaar' and week=6 and kind in ('morning','afternoon','evening')),'everyone graduates at Hofman');
select pg_temp.assert_true((pg_temp.week('evening',3)).cost='About €38 per person, or €43 from Friday to Sunday: dinner and drinks, all you can eat.','Rozey: dinner and drinks');

-- 3. Creating a Circle with this plan.
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'six'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'six%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'six%@example.test';
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000008');
update public.profiles set first_name='Olivia' where id='00000000-0000-0000-0000-000000000008';
-- Read as the database, before acting as a member: the plans aren't public.
create temp table plan as
select jsonb_agg(jsonb_build_object('title',t.title,'venue',coalesce(t.venue,''),'address',t.address,'cost',t.cost,
                                    'time',to_char(t.start_time,'HH24:MI'),'included',t.included) order by t.week) weeks
  from public.circle_programme_template t where t.city='Alkmaar' and t.kind='evening';
grant select on plan to authenticated;
create temp table members as select '["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"]'::jsonb ids;
grant select on members to authenticated;
set local role authenticated;
do $$ declare i int; begin
 for i in 1..6 loop
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'gender',case when i<=3 then 'woman' else 'man' end));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
-- Every week but 5 needs a place.
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_create',jsonb_build_object('members',(select ids from members),'name','Thursday Circle','schedule','Thursday evenings','start_date','2027-10-07','time','19:00','weeks',(select jsonb_set(weeks,'{1,venue}','""') from plan)))$q$),'week 2 without a place is refused');
select public.circle_action('admin_create',jsonb_build_object('members',(select ids from members),'name','Thursday Circle','schedule','Thursday evenings','start_date','2027-10-07','time','19:00','weeks',(select weeks from plan)));
reset role;
select pg_temp.assert_true((select string_agg(to_char(starts_at at time zone 'Europe/Amsterdam','HH24:MI'),',' order by circle_week) from public.events where circle_week is not null)='20:00,20:00,19:00,20:00,20:00,20:00','each week starts at its own time');
select pg_temp.assert_true((select bool_and(to_char(ends_at at time zone 'Europe/Amsterdam','HH24:MI')='22:00') from public.events where circle_week is not null),'every evening ends at 22:00');
select pg_temp.assert_true((select venue_name is null from public.events where circle_week=5),'week 5 is open');
select pg_temp.assert_true((select string_agg(circle_week::text,',' order by circle_week) from public.events where included)='2,4','weeks 2 and 4 are included');
create temp table ids as select (select id from public.circles) cid,
  (select id from public.events where circle_week=2) w2, (select id from public.events where circle_week=5) w5,
  (select id from public.events where circle_week=6) w6;
grant select on ids to authenticated;

-- Members see what's included.
insert into public.circle_payments(profile_id,circle_id,status) select profile_id,circle_id,'paid' from public.circle_memberships;
update public.circle_memberships set status='joined', payment_status='paid';
update public.circles set status='active';
select pg_temp.assert_true((select amount_cents from public.circle_payments limit 1)=3900,'a new payment is €39');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((select string_agg(m->>'week',',' order by (m->>'week')::int) from jsonb_array_elements(public.circle_snapshot()->'meetups') m where (m->>'included')::boolean)='2,4','members see the included weeks');

-- 4. Week 5 is theirs: a start in their part of the day; the day stays.
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('schedule',jsonb_build_object('id',(select w5 from ids),'version',pg_temp.version((select w5 from ids)),'title','Pub quiz','venue','Jonas','date','2027-11-04','time','17:00'))$q$),'17:00 is too early for an evening group');
select public.circle_action('schedule',jsonb_build_object('id',(select w5 from ids),'version',pg_temp.version((select w5 from ids)),'title','Pub quiz','venue','Jonas Bistro Bar','date','2030-01-01','time','18:30'));
reset role;
select pg_temp.assert_true((select to_char(starts_at at time zone 'Europe/Amsterdam','YYYY-MM-DD HH24:MI') from public.events where circle_week=5)='2027-11-04 18:30','week 5 keeps its day, at the group''s time');
select pg_temp.assert_true((select venue_name from public.events where circle_week=5)='Jonas Bistro Bar','and its place');
-- The news goes to the chat and to the others (20261038).
select pg_temp.assert_true(exists(select 1 from public.messages where kind='system' and body='Member 1 planned week 5: Pub quiz at Jonas Bistro Bar, starting 18:30.'),'VriendTime tells the chat who planned what');
select pg_temp.assert_true((select count(*) from public.notifications where title='Week 5 is planned' and body='Member 1 planned week 5: Pub quiz at Jonas Bistro Bar, starting 18:30.')=5,'the five others hear it');
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='Week 5 is planned' and recipient_profile_id='00000000-0000-0000-0000-000000000001'),'not the one who planned it');
select pg_temp.assert_true(not exists(select 1 from public.notifications where event_id=(select w5 from ids) and title in ('Your Circle has a plan update','Your Circle plan changed')),'instead of the generic update');
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('schedule',jsonb_build_object('id',(select w6 from ids),'version',pg_temp.version((select w6 from ids)),'title','Party','venue','Elsewhere','date','2027-11-11','time','20:00'))$q$),'the graduation is ours');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('schedule',jsonb_build_object('id',(select w2 from ids),'version',pg_temp.version((select w2 from ids)),'title','Darts','venue','Elsewhere','date','2027-10-14','time','20:00'))$q$),'so are the included weeks');

-- 5. VriendTime in the chat.
reset role;
insert into public.messages(thread_id,sender_id,body,kind)
select id,null,'Week 5 is your call! Share ideas here, then tap “Plan it” on the week 5 card to set the place and the time.','system'
  from public.chat_threads where circle_id=(select cid from ids);
select pg_temp.assert_true(pg_temp.refused($q$insert into public.messages(thread_id,sender_id,body,kind) select id,'00000000-0000-0000-0000-000000000001','Hi','system' from public.chat_threads limit 1$q$),'a member message cannot pose as VriendTime');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_snapshot()->'messages') m where m->>'name'='VriendTime' and (m->>'system')::boolean and not (m->>'own')::boolean),'members see the VriendTime message');
select pg_temp.assert_true(jsonb_array_length(public.circle_messages_before(now()+interval '1 day','ffffffff-ffff-ffff-ffff-ffffffffffff'))>=1,'and it pages like any other');
select public.circle_action('message',jsonb_build_object('body','Pub quiz?'));
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_snapshot()->'messages') m where m->>'body'='Pub quiz?' and (m->>'own')::boolean),'members still chat as themselves');

-- 6. Booking: online places get a link, email-only places an email in one tap.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'venues') v where v->>'name'='The Boules Club' and v->>'booking'='email'),'the organiser sees how each place is booked');
select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','email'));
reset role;
select pg_temp.assert_true((select to_email from public.circle_venue_emails)='reserveringen.alkmaar@theboulesclub.com','the email goes to the place''s booking address');
select pg_temp.assert_true((select subject from public.circle_venue_emails) like 'Reservering voor 6 personen op donderdag 14 oktober om 20:00','in Dutch, with the date and time');
select pg_temp.assert_true((select body from public.circle_venue_emails) like 'Beste team van The Boules Club,%van 20:00 tot 22:00, op naam van “Thursday Circle”%factuur%Olivia%','with the window, the booking name, an invoice for an included activity, and the organiser');
select pg_temp.assert_true((select booking_status='requested' and booking_requested_at is not null from public.events where circle_week=2),'the week shows the email went out');
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','email'))$q$),'not twice by accident');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','email','again',true))$q$),'not even on purpose while the first still waits');
reset role;
-- The email worker takes it and reports back.
select pg_temp.assert_true((select count(*) from public.venue_emails_pending(10))=1,'the worker picks it up');
select pg_temp.assert_true((select count(*) from public.venue_emails_pending(10))=0,'a picked-up email is not handed out twice');
select public.ack_venue_email(id) from public.circle_venue_emails;
select pg_temp.assert_true((select bool_and(sent_at is not null) from public.circle_venue_emails),'sent');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','email','again',true));
select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','booked'));
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'circles'->0->'meetups') m where m->>'booking_status'='booked'),'the organiser ticks it booked');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_booking',jsonb_build_object('id',(select w2 from ids),'step','email','again',true))$q$),'members cannot send booking emails');
reset role;
-- A place without a booking email.
insert into public.circle_venues(city,name,booking,booking_url) values('Alkmaar','Online Only','online','https://example.test/book');
update public.events set venue_name='Online Only' where circle_week=1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_booking',jsonb_build_object('id',(select id from public.events where circle_week=1),'step','email'))$q$),'no booking email for an online-only place');
rollback;
