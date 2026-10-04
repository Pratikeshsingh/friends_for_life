-- The old meetup app is gone and Circles still work. Rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
select pg_temp.assert_true(to_regproc('public.reserve_event') is null and to_regproc('public.queue_event_notifications') is null,'old meetup functions are gone');
select pg_temp.assert_true(to_regclass('public.city_options') is null and to_regclass('public.interest_options') is null,'old lookup tables are gone');
select pg_temp.assert_true(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name in ('gender','dietary_notes','selected_event_ids','phone')),'old profile columns are gone');
select pg_temp.assert_true(not exists(select 1 from pg_policies where schemaname='public' and tablename in ('events','event_attendees')),'members cannot read or join events directly');
-- A new account gets a minimal profile.
insert into auth.users(id,email,raw_user_meta_data) values('00000000-0000-0000-0000-0000000000a1','new@example.test','{"first_name":"robin","gender":"x"}');
select pg_temp.assert_true((select first_name='Robin' and email='new@example.test' from public.profiles where id='00000000-0000-0000-0000-0000000000a1'),'sign-up creates a minimal profile');
-- Members cannot read event rows (and so Circle venues) directly.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000a1',true);
do $$ declare n int; begin
 begin select count(*) into n from public.events; exception when insufficient_privilege then n:=0; end;
 perform pg_temp.assert_true(n=0,'event rows are not readable directly');
end $$;
rollback;
