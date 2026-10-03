-- Run only in a disposable database with local_bootstrap + schema + hardening + Circle migration.
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
do $$ declare i int; begin
 for i in 1..6 loop
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'phone','+3161234567'||i));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ declare original jsonb:=public.circle_snapshot()->'application'; begin
 perform public.circle_action('draft',original||'{"name":""}'::jsonb);
 perform pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','a waiting applicant who edits an answer keeps their place');
 perform public.circle_action('apply',original);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);

do $$ declare rejected boolean:=false; begin
 begin perform public.circle_action('admin_create','{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Wrong time","schedule":"Thursday afternoon","start_date":"2027-10-07","time":"14:00"}'); exception when others then rejected:=true; end;
 perform pg_temp.assert_true(rejected,'organiser cannot select an unshared period on a shared day');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ declare d jsonb:=public.circle_snapshot()->'application'; rejected boolean:=false; begin
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000007',true);
 begin perform public.circle_action('apply',d||jsonb_build_object('date_of_birth',(current_date-interval '17 years')::date)); exception when others then rejected:=true; end;
 perform pg_temp.assert_true(rejected,'birthday under 18 rejected by server');
 rejected:=false;
 begin perform public.circle_action('apply',d||'{"languages":["English","Other"]}'); exception when others then rejected:=true; end;
 perform pg_temp.assert_true(rejected,'unsupported language rejected by server');
 rejected:=false;
 begin perform public.circle_action('apply',(d-'date_of_birth')||'{"age":30}'); exception when others then rejected:=true; end;
 perform pg_temp.assert_true(rejected,'numeric age cannot replace birthday');
 perform public.circle_action('apply',d||'{"age":999}');
 perform pg_temp.assert_true(not(public.circle_snapshot()->'application' ? 'age'),'stale numeric age is not stored');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_create','{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Thursday Circle","schedule":"Thursday evening","start_date":"2027-10-07","time":"19:30"}');
select pg_temp.assert_true(public.can_view_circle_photo('00000000-0000-0000-0000-000000000001/profile.jpg'),'matching organiser can review applicant photo');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.can_view_circle_photo('00000000-0000-0000-0000-000000000002/profile.jpg'),'assigned Circle can recognise other members');
select pg_temp.assert_true(not(public.circle_snapshot()->'members'->0 ? 'date_of_birth'),'birthday never shared with Circle');
select pg_temp.assert_true(not(public.circle_snapshot()->'members'->0 ? 'goals'),'private matching goals never shared with Circle');
select public.circle_action('edit_circle_profile','{"name":"Asha","intro":"Coffee and long walks."}');
select pg_temp.assert_true(public.circle_snapshot()->'application'->>'intro'='Coffee and long walks.','introduction remains editable after matching');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000007',true);
select pg_temp.assert_true(not public.can_view_circle_photo('00000000-0000-0000-0000-000000000001/profile.jpg'),'outsider cannot read member photos');
-- Pointing a profile at someone else's photo is refused at the source.
do $$ declare rejected boolean:=false; begin
 begin update public.profiles set profile_photo_path='00000000-0000-0000-0000-000000000001/profile.jpg' where id='00000000-0000-0000-0000-000000000007';
 exception when others then rejected:=true; end;
 perform pg_temp.assert_true(rejected,'a profile cannot point at someone else’s photo');
end $$;
select pg_temp.assert_true(not public.can_view_circle_photo('00000000-0000-0000-0000-000000000001/profile.jpg'),'outsider still cannot read member photos');
rollback;
