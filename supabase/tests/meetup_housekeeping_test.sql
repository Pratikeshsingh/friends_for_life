-- Meetups complete themselves after 24 hours; organisers hear about missing
-- places; week 5 is the group's own: an email, a chat nudge, then the organiser.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'hk'||i||'@example.test' from generate_series(1,3) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000003');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date-20,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status) values('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000001','joined','paid');
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-00000000000a',1,'W1','Alkmaar',now()-interval '20 days',now()-interval '20 days'+interval '2 hours',6,'open','Rozey'),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-00000000000a',2,'W2','Alkmaar',now()-interval '10 hours',now()-interval '8 hours',6,'open','Cafe'),
 ('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-00000000000a',3,'W3','Alkmaar',now()+interval '2 days',now()+interval '2 days'+interval '2 hours',6,'open',null),
 ('20000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-00000000000a',5,'Your call','Alkmaar',now()+interval '5 days',now()+interval '5 days'+interval '2 hours',6,'open',null),
 ('20000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-00000000000a',6,'Graduation','Alkmaar',now()+interval '6 days',now()+interval '6 days'+interval '2 hours',6,'open','Hofman');
insert into public.chat_threads(id,circle_id,title,kind) values('30000000-0000-0000-0000-00000000000a','10000000-0000-0000-0000-00000000000a','Circle A','group');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select completed_at is not null from public.events where circle_week=1),'a meetup more than a day ago is complete');
select pg_temp.assert_true((select completed_at is null from public.events where circle_week=2),'one that ended hours ago is not yet');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='A meetup has no place yet'),'organiser hears about a missing place');
select pg_temp.assert_true((select metadata->>'open' from public.notifications where title='Week 5 is your call')='meetup:20000000-0000-0000-0000-000000000005','members hear week 5 is theirs, linking to it');
select pg_temp.assert_true((select body from public.notifications where title='Week 5 is your call') like 'Week 5 of Circle A is on % Choose together what to do, where, and a start between %','the email says what to choose');
select pg_temp.assert_true(not exists(select 1 from public.notifications where title like 'Your plan for week%'),'no reminder of a set plan: week 6 is booked for them');
select pg_temp.assert_true((select count(*) from public.messages where thread_id='30000000-0000-0000-0000-00000000000a' and kind='system' and sender_id is null)=1,'VriendTime nudges the group chat');
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='Week 5 has no plan yet'),'the organiser waits while there is time');
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='A meetup has no place yet' and event_id='20000000-0000-0000-0000-000000000005'),'week 5 has no place on purpose');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select count(*) from public.notifications where title='Week 5 is your call')=1,'one email each');
select pg_temp.assert_true((select count(*) from public.messages where thread_id='30000000-0000-0000-0000-00000000000a')=1,'one chat nudge');
-- Three days before, still open: the organiser books something.
update public.events set starts_at=now()+interval '2 days', ends_at=now()+interval '2 days 2 hours' where circle_week=5;
select public.queue_meetup_housekeeping();
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='Week 5 has no plan yet'),'the organiser hears week 5 is still open');
-- Once the group planned it, nothing more.
update public.events set venue_name='Jonas', starts_at=now()+interval '9 days', ends_at=now()+interval '9 days 2 hours', group_nudged_at=null where circle_week=5;
delete from public.notifications where title='Week 5 is your call';
select public.queue_meetup_housekeeping();
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='Week 5 is your call'),'a planned week 5 needs no reminder');
-- Pay-by never later than the day before the first meetup (20261036).
select pg_temp.assert_true(public.circle_pay_by(now(), (now() at time zone 'Europe/Amsterdam')::date + 1)=(now() at time zone 'Europe/Amsterdam')::date,'a late invitation pays by the day before the first meetup');
rollback;
