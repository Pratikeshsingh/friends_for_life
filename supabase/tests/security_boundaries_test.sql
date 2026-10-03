-- Current security authorization and matching checks. Disposable database only.
-- Every fixture and mutation is rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'test'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'test%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'test%@example.test';
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000008');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='apply','new user starts with application');
do $$ declare blocked boolean:=false; begin
 begin perform public.circle_admin_snapshot(); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'non-admin cannot inspect all applications');
 blocked:=false;
 begin perform public.circle_action('apply','{"name":"Underage","city":"Alkmaar","age":17}'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'incomplete/underage application rejected');
end $$;
create function pg_temp.expect_error(command text, expected text) returns void language plpgsql as $$
declare denied boolean:=false;
begin
 begin execute command;
 exception when others then
  if position(expected in sqlerrm)=0 then raise; end if;
  denied:=true;
 end;
 perform pg_temp.assert_true(denied,'expected denial: '||expected);
end; $$;
do $$ declare i int; begin
 for i in 1..6 loop
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'phone','+31612345678','commitment',true));
 end loop;
end $$;
-- Group creation is server-authorized, not merely hidden by the UI.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error($q$select public.circle_action('admin_create','{}')$q$,'Organiser access required');
select pg_temp.expect_error($q$select public.circle_action('admin_confirm_payment','{}')$q$,'Organiser access required');
select pg_temp.expect_error($q$insert into public.circle_admins values(auth.uid())$q$,'permission denied');
select pg_temp.expect_error($q$update public.circle_payments set status='paid'$q$,'permission denied');
select pg_temp.expect_error($q$insert into storage.objects(bucket_id,name) values('profile-photos','00000000-0000-0000-0000-000000000002/foreign.jpg')$q$,'row-level security');
select pg_temp.assert_true((select count(*)=0 from storage.objects where name='00000000-0000-0000-0000-000000000002/profile.jpg'),'outsider cannot read photo metadata');
select pg_temp.assert_true(public.circle_export_data()->'profile'->>'id'=auth.uid()::text,'export belongs to requesting member');
select pg_temp.assert_true((select count(*)=1 from public.profiles),'ordinary applicant can read only own profile');
select 'PASS member payment/admin escalation, foreign photo writes/reads, own profile/export scope' finding,true passed;
reset role;
create temp table matching_payload as select jsonb_build_object('members',jsonb_agg(id order by id),'name','Security test Circle','schedule','Thursday evenings','start_date',current_date+((4-extract(isodow from current_date)::int+7)%7)+7,'time','19:30') payload from auth.users where id<='00000000-0000-0000-0000-000000000006';
grant select on matching_payload to authenticated;
update public.circle_applications set answers=jsonb_set(answers,'{languages}','["Dutch"]') where profile_id='00000000-0000-0000-0000-000000000006';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.expect_error(format('select public.circle_action(%L,%L::jsonb)','admin_create',(select payload from matching_payload)),'shared language');
reset role;
update public.circle_applications set answers=jsonb_set(answers,'{languages}','["English"]') where profile_id='00000000-0000-0000-0000-000000000006';
set local role authenticated;
select pg_temp.expect_error(format('select public.circle_action(%L,%L::jsonb)','admin_create',(select payload||'{"time":"13:00"}'::jsonb from matching_payload)),'everyone selected');
select pg_temp.expect_error(format('select public.circle_action(%L,%L::jsonb)','admin_create',(select jsonb_set(payload,'{members}',(payload->'members')-0-0) from matching_payload)),'5–6 applicants');
reset role;
insert into public.circle_exclusions(profile_id,excluded_profile_id) values('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
set local role authenticated;
select pg_temp.expect_error(format('select public.circle_action(%L,%L::jsonb)','admin_create',(select payload from matching_payload)),'asked not to be matched');
reset role;
select pg_temp.assert_true((select count(*)=0 from public.circles),'failed matching is atomic');
delete from public.circle_exclusions;
set local role authenticated;
select public.circle_action('admin_create',payload) from matching_payload;
select 'PASS shared language, availability, group size, exclusion and atomic creation' finding,true passed;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error($q$select public.circle_action('schedule',jsonb_build_object('title','Unpaid plan','venue','Cafe','date',current_date+2,'time','12:00'))$q$,'active paid membership');
select pg_temp.expect_error(format('select public.reserve_event(%L::uuid)',public.circle_snapshot()->'meetups'->0->>'id'),'Circle');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000007',true);
select pg_temp.assert_true(not(public.circle_snapshot() ? 'members'),'outsider has no member list');
select pg_temp.expect_error($q$select public.circle_messages_before(now(),'ffffffff-ffff-ffff-ffff-ffffffffffff')$q$,'active paid membership');
select pg_temp.assert_true((select count(*)=0 from public.messages),'outsider cannot read messages directly');
select 'PASS unpaid and outsider restrictions, including legacy reservation' finding,true passed;
reset role;
rollback;
