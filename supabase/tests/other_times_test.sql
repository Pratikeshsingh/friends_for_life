-- Applying with only "other times" works; with neither it is refused.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data) values('00000000-0000-0000-0000-000000000001','ot@example.test','{"first_name":"Ot"}');
insert into storage.objects(bucket_id,name) values('profile-photos','00000000-0000-0000-0000-000000000001/profile.jpg');
update public.profiles set profile_photo_path='00000000-0000-0000-0000-000000000001/profile.jpg';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
create temp table base as select jsonb_build_object('name','Ot','city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{}'::jsonb,'availability','[]'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'gender','woman') p;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('apply',(select p from base))$q$),'no times at all is refused');
select public.circle_action('apply',(select p from base)||'{"other_times":"Mondays after 22:00"}');
select pg_temp.assert_true(public.circle_snapshot()->'application'->>'other_times'='Mondays after 22:00','other times alone is enough');
rollback;
