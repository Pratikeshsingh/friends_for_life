-- Meetups complete themselves after 24 hours; organisers hear about missing
-- places; weeks 5-6 get a reminder of their default plan.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'hk'||i||'@example.test' from generate_series(1,3) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000003');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date-20,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status) values('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000001','joined','paid');
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-00000000000a',1,'W1','Alkmaar',now()-interval '20 days',now()-interval '20 days'+interval '2 hours',6,'open','Rozey'),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-00000000000a',2,'W2','Alkmaar',now()-interval '10 hours',now()-interval '8 hours',6,'open','Cafe'),
 ('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-00000000000a',3,'W3','Alkmaar',now()+interval '2 days',now()+interval '2 days'+interval '2 hours',6,'open',null),
 ('20000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-00000000000a',5,'Drinks','Alkmaar',now()+interval '5 days',now()+interval '5 days'+interval '2 hours',6,'open','Mr. Gold');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select completed_at is not null from public.events where circle_week=1),'a meetup more than a day ago is complete');
select pg_temp.assert_true((select completed_at is null from public.events where circle_week=2),'one that ended hours ago is not yet');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='A meetup has no place yet'),'organiser hears about a missing place');
select pg_temp.assert_true((select metadata->>'open' from public.notifications where title='Your plan for week 5')='meetup:20000000-0000-0000-0000-000000000005','members get the week-5 reminder linking to it');
select pg_temp.assert_true((select body from public.notifications where title='Your plan for week 5') like '%planned as Drinks at Mr. Gold%','reminder names the plan');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select count(*) from public.notifications where title='Your plan for week 5')=1,'only once');
-- Pay-by never after the first meetup.
select pg_temp.assert_true(public.circle_pay_by(now(), current_date)=current_date,'late invitation pays by the first meetup day');
rollback;
