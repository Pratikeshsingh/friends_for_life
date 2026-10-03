-- Refund until 48 hours before the first meetup; afterwards one free move.
-- Everything is rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'move'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
insert into public.circle_applications(profile_id,answers,status) select id,'{}'::jsonb,'joined' from auth.users where id<>'00000000-0000-0000-0000-000000000008';

-- Circle A starts in 5 days: inside the refund window.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date+5,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-00000000000a',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,4) i;
insert into public.circle_payments(profile_id,circle_id,status) select profile_id,circle_id,'paid' from public.circle_memberships;
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status)
select '10000000-0000-0000-0000-00000000000a',i,'Week '||i,'Alkmaar',now()+interval '5 days'+interval '7 days'*(i-1),now()+interval '5 days'+interval '7 days'*(i-1)+interval '2 hours',6,'open' from generate_series(1,6) i;
insert into public.chat_threads(circle_id,title) values('10000000-0000-0000-0000-00000000000a','A chat');
insert into public.chat_participants(thread_id,profile_id) select t.id,m.profile_id from public.chat_threads t,public.circle_memberships m where t.circle_id=m.circle_id;

set local role authenticated;
-- 1. More than 48 hours before the first meetup: refund.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((public.circle_snapshot()->'payment_agreement'->>'can_cancel')::boolean,'cancel is offered inside the window');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_leave('bye')$q$),'leaving is refused while a refund is still possible');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('request_move')$q$),'no move before the first meetup');
select public.circle_action('cancel_agreement');
select pg_temp.assert_true(public.circle_snapshot()->'payment_history'->0->>'refund'='requested','cancel inside the window records a refund');

-- 2. Within 48 hours of the first meetup: no refund, leaving is allowed.
reset role;
update public.events set starts_at=starts_at-interval '4 days',ends_at=ends_at-interval '4 days' where circle_id='10000000-0000-0000-0000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(not (public.circle_snapshot()->'payment_agreement'->>'can_cancel')::boolean,'cancel is no longer offered');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('cancel_agreement')$q$),'no refund within 48 hours');

-- 3. After the first meetup has started: one free move.
reset role;
update public.events set starts_at=starts_at-interval '2 days',ends_at=ends_at-interval '2 days' where circle_id='10000000-0000-0000-0000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true((public.circle_snapshot()->'move'->>'available')::boolean,'move is offered after the first meetup');
-- Once the second meetup has started, the move is gone.
reset role;
update public.events set starts_at=starts_at-interval '7 days',ends_at=ends_at-interval '7 days' where circle_id='10000000-0000-0000-0000-00000000000a';
set local role authenticated;
select pg_temp.assert_true(not (public.circle_snapshot()->'move'->>'available')::boolean,'no move after the second meetup starts');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('request_move')$q$),'a late move is refused');
reset role;
update public.events set starts_at=starts_at+interval '7 days',ends_at=ends_at+interval '7 days' where circle_id='10000000-0000-0000-0000-00000000000a';
set local role authenticated;
select public.circle_action('request_move','{"reason":"Different rhythm"}');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','mover is back on the waiting list');
select pg_temp.assert_true((public.circle_snapshot()->>'move_credit')::boolean,'mover has a credit');
reset role;
select pg_temp.assert_true(not exists(select 1 from public.chat_participants where profile_id='00000000-0000-0000-0000-000000000003'),'mover leaves the old chat');
select pg_temp.assert_true(exists(select 1 from public.notifications where kind='support' and title='A member wants to move to another group'),'organiser is told');

-- The organiser sees who is moving.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'applications') a where a->>'profile_id'='00000000-0000-0000-0000-000000000003' and (a->>'moving')::boolean),'organiser sees the move');

-- 4. Joining the next Circle is free.
reset role;
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000b','Circle B','Monday',current_date+10,'19:30','offered');
insert into public.circle_memberships(circle_id,profile_id,status) values('10000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-000000000003','invited');
update public.circle_applications set status='invited' where profile_id='00000000-0000-0000-0000-000000000003';
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status)
select '10000000-0000-0000-0000-00000000000b',i,'Week '||i,'Alkmaar',now()+interval '10 days'+interval '7 days'*(i-1),now()+interval '10 days'+interval '7 days'*(i-1)+interval '2 hours',6,'open' from generate_series(1,6) i;
insert into public.chat_threads(circle_id,title) values('10000000-0000-0000-0000-00000000000b','B chat');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.circle_action('join');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='active','the credit covers the new Circle');
select pg_temp.assert_true(not (public.circle_snapshot()->>'move_credit')::boolean,'the credit is used');
select pg_temp.assert_true(not (public.circle_snapshot()->'payment_agreement'->>'can_cancel')::boolean,'a moved-in place has no refund');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.circle_payments where profile_id='00000000-0000-0000-0000-000000000003'),'no second payment is created');
update public.events set starts_at=now()-interval '3 hours',ends_at=now()-interval '1 hour' where circle_id='10000000-0000-0000-0000-00000000000b' and circle_week=1;
set local role authenticated;
select pg_temp.assert_true(not (public.circle_snapshot()->'move'->>'available')::boolean,'no second free move');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('request_move')$q$),'a second move is refused');

-- 5. If the organiser cancels the new Circle, the original €19 is refunded.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_cancel_circle','{"id":"10000000-0000-0000-0000-00000000000b"}');
reset role;
select pg_temp.assert_true((select payment_id is not null from public.circle_refund_requests where profile_id='00000000-0000-0000-0000-000000000003' and circle_id='10000000-0000-0000-0000-00000000000b'),'refund points at the original payment');
set local role authenticated;

-- 6. The organiser can refund a move nobody could place.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select public.circle_action('request_move');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_refund_move',jsonb_build_object('id',(select a->>'move_id' from jsonb_array_elements(public.circle_admin_snapshot()->'applications') a where a->>'profile_id'='00000000-0000-0000-0000-000000000004')));
reset role;
select pg_temp.assert_true(exists(select 1 from public.circle_refund_requests r join public.circle_payments p on p.id=r.payment_id where r.profile_id='00000000-0000-0000-0000-000000000004'),'unplaced move becomes a refund');
select pg_temp.assert_true((select status='withdrawn' from public.circle_applications where profile_id='00000000-0000-0000-0000-000000000004'),'and leaves the waiting list');
rollback;
