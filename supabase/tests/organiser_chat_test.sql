-- The organiser can page back through a Circle's whole chat; members can't.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.error(sql text) returns text language plpgsql as $$ begin execute sql; return null; exception when others then return sqlerrm; end; $$;

insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','oc1@example.test','{"first_name":"Anna"}'),
 ('00000000-0000-0000-0000-000000000009','oc9@example.test','{"first_name":"Org"}');
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000009');
insert into public.circles(id,name,schedule,start_date,local_time,status)
values('31000000-0000-0000-0000-000000000001','Chat Circle','Thursday evenings',current_date+20,'19:00','active');
insert into public.chat_threads(id,circle_id,kind,title) values('32000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','group','Chat Circle');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status) values('31000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','joined','paid');
-- 450 messages at once: past the send-rate guard, which isn't under test here.
set local session_replication_role = replica;
insert into public.messages(thread_id,sender_id,body,created_at)
select '32000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Message '||i,now()-make_interval(mins=>500-i)
  from generate_series(1,450) i;
set local session_replication_role = origin;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000009',true);
create temp table latest as select public.circle_admin_messages('31000000-0000-0000-0000-000000000001') j;
select pg_temp.assert_true(jsonb_array_length((select j from latest))=200 and (select j->0->>'body' from latest)='Message 251','the latest 200, oldest first');
create temp table older as select public.circle_admin_messages_before('31000000-0000-0000-0000-000000000001',
  ((select j->0->>'created_at' from latest))::timestamptz, ((select j->0->>'id' from latest))::uuid) j;
select pg_temp.assert_true(jsonb_array_length((select j from older))=200 and (select j->0->>'body' from older)='Message 51' and (select j->199->>'body' from older)='Message 250','the 200 before them, oldest first, no gap or overlap');
select pg_temp.assert_true((select j->0->>'name' from older)='Anna','with the sender''s first name');
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_messages_before('31000000-0000-0000-0000-000000000001',
  ((select j->0->>'created_at' from older))::timestamptz, ((select j->0->>'id' from older))::uuid))=50,'and the last 50');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_admin_messages_before('31000000-0000-0000-0000-000000000001',now(),gen_random_uuid())$q$)='Organiser access required.','members can''t read through it');
reset role;
set local role anon;
select pg_temp.assert_true(pg_temp.error($q$select public.circle_admin_messages_before('31000000-0000-0000-0000-000000000001',now(),gen_random_uuid())$q$) like 'permission denied%','nor can anyone signed out');
reset role;
rollback;
