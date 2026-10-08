-- Leaving with care, organiser alerts, removing a member, chat digests.
-- Everything is rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'side'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
insert into public.circle_applications(profile_id,answers,status) select id,'{}'::jsonb,'joined' from auth.users where id<>'00000000-0000-0000-0000-000000000008';
-- Circle A starts in 10 days; members 1–5 joined and paid, 6 invited.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date+10,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-00000000000a',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,5) i;
insert into public.circle_memberships(circle_id,profile_id,status) values('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000006','invited');
update public.circle_applications set status='invited' where profile_id='00000000-0000-0000-0000-000000000006';
insert into public.circle_payments(profile_id,circle_id,status) select profile_id,circle_id,'paid' from public.circle_memberships where status='joined';
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status)
select '10000000-0000-0000-0000-00000000000a',i,'Week '||i,'Alkmaar',now()+interval '10 days'+interval '7 days'*(i-1),now()+interval '10 days'+interval '7 days'*(i-1)+interval '2 hours',6,'open' from generate_series(1,6) i;
insert into public.chat_threads(circle_id,title) values('10000000-0000-0000-0000-00000000000a','A chat');
insert into public.chat_participants(thread_id,profile_id) select t.id,m.profile_id from public.chat_threads t,public.circle_memberships m where t.circle_id=m.circle_id and m.status='joined';

set local role authenticated;
-- 1. Switching keeps the €19, even before the first meetup.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((public.circle_snapshot()->'switch'->>'available')::boolean,'a switch is offered before the first meetup');
select public.circle_action('switch_group','{"reason":"The time doesn’t work","note":"Mondays are better"}');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','back on the waiting list');
select pg_temp.assert_true((public.circle_snapshot()->>'move_credit')::boolean,'the €19 carries over');
reset role;
select pg_temp.assert_true((select reason from public.circle_moves where profile_id='00000000-0000-0000-0000-000000000001') like 'The time doesn’t work — Mondays are better','the reason is kept');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000008' and title='A member is switching groups'),'the organiser hears about the switch');
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('switch_group','{"reason":"x"}')$q$),'only one switch');

-- 2. Leaving with a refund: a reviewed request, with the reason.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.circle_action('cancel_agreement','{"reason":"Something came up"}');
select pg_temp.assert_true(public.circle_snapshot()->'left_circle'->>'name'='Circle A','after leaving, the app says so');
select pg_temp.assert_true(public.circle_snapshot()->'left_circle'->>'refund'='requested','and that the refund is requested');
select public.circle_action('rejoin');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','they can join the waiting list again');
reset role;
select pg_temp.assert_true((select reason from public.circle_refund_requests where profile_id='00000000-0000-0000-0000-000000000002')='Something came up','refund reason stored');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000008' and title='A member asked for a refund'),'organiser hears about the refund request');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000002' and title='You’ve left the Circle' and body not like '%will return%'),'member message promises no payout');

-- 3. A declined invitation tells the organiser a place opened.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000006',true);
select public.circle_action('decline');
reset role;
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000008' and title='A place opened in a Circle' and body like '%is no longer joining%'),'organiser hears about the decline');

-- 4. Reports: reporter email for the organiser, and a thank-you when resolved.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.circle_action('report','{"reason":"Please help with a concern"}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(public.circle_admin_snapshot()->'reports'->0->>'email'='side3@example.test','organiser sees who reported');
select pg_temp.assert_true(public.circle_admin_snapshot()->'refunds'->0->>'reason'='Something came up','organiser sees the refund reason');
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'circles'->0->'left_ids')>=3,'organiser knows who left the Circle');
select public.circle_action('admin_resolve_report',jsonb_build_object('id',public.circle_admin_snapshot()->'reports'->0->>'id'));
reset role;
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='Thanks for your report'),'reporter hears it was handled');

-- 5. Removing a member: organisers only.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_admin_remove_member('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000004','Repeated harassment')$q$),'members cannot remove members');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_admin_remove_member('10000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000004','Repeated harassment');
reset role;
select pg_temp.assert_true((select status from public.circle_memberships_all where profile_id='00000000-0000-0000-0000-000000000004')='left','removed from the Circle');
select pg_temp.assert_true(not exists(select 1 from public.chat_participants where profile_id='00000000-0000-0000-0000-000000000004'),'and from the chat');
select pg_temp.assert_true((select status from public.circle_applications where profile_id='00000000-0000-0000-0000-000000000004')='withdrawn','not put back on the waiting list');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000004' and title like 'You’re no longer in%'),'they are told');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.assert_true((public.circle_snapshot()->'left_circle'->>'removed')::boolean,'their screen says they were removed');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(not coalesce((public.circle_snapshot()->'left_circle'->>'removed')::boolean,false),'someone who left is not shown as removed');
reset role;

-- 6. One evening summary for new chat messages.
insert into public.messages(thread_id,sender_id,body) select id,'00000000-0000-0000-0000-000000000005','See you Thursday!' from public.chat_threads;
select public.queue_chat_digests(); select public.queue_chat_digests();
select pg_temp.assert_true((select count(*) from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='New messages in your Circle')=1,'one digest per day');
select pg_temp.assert_true(not exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000005' and title='New messages in your Circle'),'not for your own messages');
-- 7. Retention clean-up removes only what is past its time.
insert into public.notifications(recipient_profile_id,kind,title,body,created_at) values('00000000-0000-0000-0000-000000000003','update','Old','Old',now()-interval '13 months');
select public.purge_old_records();
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='Old'),'year-old notifications are removed');
select pg_temp.assert_true(exists(select 1 from public.notifications where title='Thanks for your report'),'recent ones stay');
rollback;
