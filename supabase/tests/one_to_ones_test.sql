-- One-to-one coffees: rounds, answers, nudges, swaps, free weeks, the tracker.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'oo'||i||'@example.test',jsonb_build_object('first_name','P'||i) from generate_series(1,7) i;
update public.profiles set first_name='P'||right(id::text,1) where email like 'oo%@example.test';
-- Everyone is free at every offered time.
insert into public.circle_applications(profile_id,answers,status)
select id,'{"availability_slots":{"tue":["morning","evening"],"wed":["morning","evening"],"thu":["morning","evening"],"fri":["afternoon","evening"],"sat":["afternoon","evening"],"sun":["afternoon","evening"]}}'::jsonb,'joined'
  from public.profiles where email like 'oo%@example.test';
insert into public.circle_admins values('00000000-0000-0000-0000-000000000007');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Weekly',current_date-8,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-00000000000a',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,6) i;
-- Week 2 has just ended; week 3 is a week away.
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('10000000-0000-0000-0000-00000000000a',1,'W1','Alkmaar',now()-interval '8 days',now()-interval '8 days'+interval '2 hours',6,'open','Rozey'),
 ('10000000-0000-0000-0000-00000000000a',2,'W2','Alkmaar',now()-interval '3 hours',now()-interval '1 hour',6,'open','Cafe'),
 ('10000000-0000-0000-0000-00000000000a',3,'W3','Alkmaar',now()+interval '7 days',now()+interval '7 days 2 hours',6,'open','Boules');

-- Nothing before meetup 2 has ended.
update public.events set ends_at=now()+interval '1 hour' where circle_week=2;
select public.queue_circle_coffees();
select pg_temp.assert_true(not exists(select 1 from public.circle_coffees),'no round before meetup 2 ends');
update public.events set ends_at=now()-interval '1 hour' where circle_week=2;

-- Another city's places are never used here.
insert into public.circle_coffee_places(city,kind,name,sort) values('Haarlem','daytime','Haarlem Café',0),('Haarlem','evening','Haarlem Bar',0);
-- Round 1: three pairs, everyone asked once, never on a meetup day.
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.circle_coffees where round=1)=3,'three pairs in round 1');
select pg_temp.assert_true((select count(*) from public.notifications where title like 'This week you could meet %')=6,'everyone is asked');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffees k join public.events e on (e.starts_at at time zone 'Europe/Amsterdam')::date=(k.starts_at at time zone 'Europe/Amsterdam')::date),'never on a group-meetup day');
select pg_temp.assert_true((select count(distinct place) from public.circle_coffees)>=2,'places rotate across the Circle');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffees where place like 'Haarlem%'),'only places in the Circle''s city');
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.circle_coffees)=3,'a round is created once');

create temp table pairs as select row_number() over (order by a) n, id, a, b from public.circle_coffees;
grant select on pairs to authenticated;
set local role authenticated;
-- Pair 1: both yes.
select set_config('request.jwt.claim.sub',(select a::text from pairs where n=1),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=1),'answer','yes'));
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'current'->>'mine'='yes','my answer shows');
select set_config('request.jwt.claim.sub',(select b::text from pairs where n=1),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=1),'answer','yes'));
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'current'->>'status'='confirmed','both yes: it is on');
select pg_temp.assert_true((public.circle_snapshot()->'coffees'->'rounds'->0->'coffee'->>'status')='confirmed' and (public.circle_snapshot()->'coffees'->'rounds'->0->>'round')='1','the round shows in the timeline');
-- Someone else cannot answer for them.
select set_config('request.jwt.claim.sub',(select a::text from pairs where n=2),true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=1),'answer','no'))$q$),'only the two can answer');
-- Pair 2: yes and no. Pair 3: yes and no.
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=2),'answer','yes'));
select set_config('request.jwt.claim.sub',(select b::text from pairs where n=2),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=2),'answer','no'));
select set_config('request.jwt.claim.sub',(select a::text from pairs where n=3),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=3),'answer','yes'));
select set_config('request.jwt.claim.sub',(select b::text from pairs where n=3),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from pairs where n=3),'answer','no'));
reset role;
select pg_temp.assert_true((select count(*) from public.notifications where title like 'You’re meeting %')=2,'both hear it is on');

-- Half a day later: one nudge to each "no". Nudges only go out more than
-- 12 hours before the coffee; tomorrow's 10:30 is closer than that late in
-- the evening, so the two coffees move two days on (same daytime hour).
update public.circle_coffees set answered_at=now()-interval '13 hours';
update public.circle_coffees set starts_at=starts_at+interval '2 days' where id in (select id from pairs where n in (2,3));
select public.queue_circle_coffees();
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.notifications where title like '% would love to meet')=2,'one nudge per no');
select pg_temp.assert_true((select recipient_profile_id from public.notifications where title like '% would love to meet' order by recipient_profile_id limit 1) in (select b from pairs),'the nudge goes to the one who said no');

-- Two days on: the two who said yes are paired with each other; the others get a free week.
update public.circle_coffee_rounds set created_at=now()-interval '49 hours';
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.circle_coffees where swap and status='asked')=1,'one swap');
select pg_temp.assert_true((select a in (select a from pairs where n in (2,3)) and b in (select a from pairs where n in (2,3)) from public.circle_coffees where swap),'the swap pairs the two yes-sayers');
select pg_temp.assert_true((select count(*) from public.notifications where title like '% is busy, but % is free')=2,'busy-but-free wording');
select pg_temp.assert_true((select count(*) from public.notifications where title='Enjoy your free week')=2,'the two who said no get a free week');
select pg_temp.assert_true((select count(*) from public.circle_coffees where status='off')=2,'the declined pairs are off');

-- The tracker: after the coffee, they have met; one optional question follows.
update public.circle_coffees set starts_at=now()-interval '1 day' where id=(select id from pairs where n=1);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select a::text from pairs where n=1),true);
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'met' ? (select b::text from pairs where n=1),'the tracker counts the coffee');
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'feedback_due'->>'id'=(select id::text from pairs where n=1),'asked how it was');
select public.circle_action('coffee_feedback',jsonb_build_object('id',(select id from pairs where n=1),'rating','good'));
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'feedback_due' is null or jsonb_typeof(public.circle_snapshot()->'coffees'->'feedback_due')='null','asked only once');
select set_config('request.jwt.claim.sub',(select b::text from pairs where n=1),true);
select public.circle_action('coffee_feedback',jsonb_build_object('id',(select id from pairs where n=1),'rating','no_show','note','I waited 20 minutes'));
select pg_temp.assert_true(not (public.circle_snapshot()->'coffees'->'met' ? (select a::text from pairs where n=1)),'a no-show does not count as met');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('coffee_feedback',jsonb_build_object('id',(select id from pairs where n=2),'rating','good'))$q$),'no feedback on a coffee that did not happen');
reset role;

-- Round 2 never repeats a pair that met.
update public.events set ends_at=now()-interval '1 hour', starts_at=now()-interval '3 hours' where circle_week=3;
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('10000000-0000-0000-0000-00000000000a',4,'W4','Alkmaar',now()+interval '7 days',now()+interval '7 days 2 hours',6,'open','Bowling');
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.circle_coffees where round=2)>=2,'round 2 starts after meetup 3');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffees k, pairs p where k.round=2 and p.n=1 and ((k.a=p.a and k.b=p.b) or (k.a=p.b and k.b=p.a))),'nobody meets twice');

-- Cancelling a confirmed coffee tells the other person.
create temp table on2 as select id, a from public.circle_coffees where round=2 order by a limit 1;
grant select on on2 to authenticated;
update public.circle_coffees set status='confirmed', a_answer='yes', b_answer='yes' where id=(select id from on2);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select a::text from on2),true);
select public.circle_action('coffee_answer',jsonb_build_object('id',(select id from on2),'answer','no'));
reset role;
select pg_temp.assert_true(exists(select 1 from public.notifications where title like '% can’t make it after all'),'the other hears it is off');

-- The organiser sees the pairs.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000007',true);
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'circles'->0->'coffees')>=5,'organiser sees the coffees');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'circles'->0->'coffees') k, jsonb_array_elements(k->'feedback') f where f->>'note'='I waited 20 minutes'),'organiser sees the feedback');
select public.circle_action('admin_coffee_places',jsonb_build_object('kind','evening','places',jsonb_build_array(jsonb_build_object('name','Café Lekker','address','Laat 1'))));
select pg_temp.assert_true((select count(*) from jsonb_array_elements(public.circle_admin_snapshot()->'coffee_places') x where x->>'kind'='evening' and x->>'city'='Alkmaar')=1,'organiser edits the places');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_coffee_places','{"kind":"evening","places":[{"name":"X"}]}')$q$),'members cannot edit the places');
reset role;

-- The Circle ends a week after its last meetup, not straight after it.
update public.events set completed_at=now()-interval '1 day';
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name,completed_at)
select '10000000-0000-0000-0000-00000000000a',w,'W'||w,'Alkmaar',now()-interval '3 days',now()-interval '3 days',6,'open','X',now() from generate_series(5,6) w;
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select status from public.circles)='active','still active in the week after meetup 6');
update public.events set starts_at=now()-interval '9 days', ends_at=now()-interval '9 days';
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select status from public.circles)='completed','completed a week after');
rollback;
