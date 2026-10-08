-- A second Circle: look again after six weeks, keep the finished Circle's
-- chat as a past Circle, and get it back if the new place falls through.
-- Everything is rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'two'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
update public.profiles set profile_photo_path=id::text||'/p.jpg';
insert into public.circle_applications(profile_id,answers,status) select id,'{}'::jsonb,'joined' from auth.users where id<>'00000000-0000-0000-0000-000000000008';

-- Circle A is finished; members 1–5.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date-50,'19:30','completed');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-00000000000a',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,5) i;
insert into public.chat_threads(circle_id,title) values('10000000-0000-0000-0000-00000000000a','A chat');
insert into public.messages(thread_id,sender_id,body) select id,'00000000-0000-0000-0000-000000000002','See you all!' from public.chat_threads;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='completed','a finished Circle shows as finished');
select pg_temp.assert_true(not (public.circle_snapshot()->>'looking_again')::boolean,'not looking yet');
select public.circle_action('join_again');
select pg_temp.assert_true((public.circle_snapshot()->>'looking_again')::boolean,'looking for a new Circle');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='completed','still sees the finished Circle while waiting');
select public.circle_action('stop_looking');
select pg_temp.assert_true(not (public.circle_snapshot()->>'looking_again')::boolean,'stopped looking');
select public.circle_action('join_again');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.circle_action('join_again');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000006',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('join_again')$q$),'only after a finished Circle');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'exclusions') p
  where p->>0='00000000-0000-0000-0000-000000000001' and p->>1='00000000-0000-0000-0000-000000000002'),'former Circle-mates are kept apart');
reset role;

-- The organiser puts member 1 in Circle B.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000b','Circle B','Monday',current_date+10,'19:00','offered');
insert into public.circle_memberships(circle_id,profile_id) values('10000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-000000000001');
update public.circle_applications set status='invited' where profile_id='00000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='invited','the new Circle is now the current one');
select pg_temp.assert_true(public.circle_snapshot()->'circle'->>'name'='Circle B','and it is Circle B');
select pg_temp.assert_true(public.circle_snapshot()->'past_circles'->0->>'name'='Circle A','Circle A is a past Circle');
select pg_temp.assert_true(public.circle_snapshot()->'past_circles'->0->'messages'->0->>'body'='See you all!','with its chat');
select public.circle_action('past_message',jsonb_build_object('circle_id','10000000-0000-0000-0000-00000000000a','body','Hi again!'));
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'past_circles'->0->'messages')=2,'can still write in the past Circle');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('past_message','{"circle_id":"10000000-0000-0000-0000-00000000000b","body":"x"}')$q$),'past_message only for past Circles');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000006',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('past_message','{"circle_id":"10000000-0000-0000-0000-00000000000a","body":"x"}')$q$),'strangers cannot write in it');
-- Member 2 is still in Circle A and still sees member 1 there, photo included.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_snapshot()->'members') x where x->>'id'='00000000-0000-0000-0000-000000000001'),'the member who moved on is still in the finished Circle');
select pg_temp.assert_true(public.can_view_circle_photo('00000000-0000-0000-0000-000000000001/p.jpg'),'former Circle-mates still see each other');
reset role;

-- The new place falls through: Circle A comes back.
update public.circle_memberships set status='left' where circle_id='10000000-0000-0000-0000-00000000000b' and profile_id='00000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='completed' and public.circle_snapshot()->'circle'->>'name'='Circle A','back to the finished Circle');
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'past_circles')=0,'no past Circles left');
reset role;
rollback;
