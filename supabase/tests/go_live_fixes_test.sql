-- Fixes from the go-live review. Rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-000000000001','new@example.test'),
 ('00000000-0000-0000-0000-000000000002','busy@example.test'),
 ('00000000-0000-0000-0000-000000000008','organiser@example.test');
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
-- GL-16: someone else has 25 photos (with Storage's own owner_id column set);
-- a new member with none can still upload.
insert into storage.objects(bucket_id,name,owner_id)
select 'profile-photos','00000000-0000-0000-0000-000000000002/'||i||'.jpg','00000000-0000-0000-0000-000000000002' from generate_series(1,25) i;
select pg_temp.assert_true(public.circle_photo_count('00000000-0000-0000-0000-000000000001')=0,'a new member has no photos counted');
select pg_temp.assert_true(public.circle_photo_count('00000000-0000-0000-0000-000000000002')=25,'only a member''s own photos count');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
insert into storage.objects(bucket_id,name,owner,owner_id) values('profile-photos','00000000-0000-0000-0000-000000000001/profile.jpg','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
-- GL-06: service-only work is not callable by members.
do $$ declare denied boolean:=false; begin
 begin perform public.queue_circle_notifications(); exception when insufficient_privilege then denied:=true; end;
 perform pg_temp.assert_true(denied,'members cannot run the reminder job');
end $$;
-- GL-09: the export covers the newer records.
select pg_temp.assert_true(public.circle_export_data() ?& array['moves','not_matched_again','email_notifications','notifications','refund_requests'],'export includes moves, matching choices, preferences, notifications and refunds');
reset role;
select pg_temp.assert_true(not has_function_privilege('anon','public.queue_circle_notifications()','EXECUTE'),'not callable without signing in');
-- GL-10: a new report notifies the organiser.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-000000000001','C','Monday',current_date+3,'19:00','active');
insert into public.circle_reports(profile_id,circle_id,reason) values('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Something felt wrong');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000008' and title='A member reported a concern'),'the organiser hears about a new report');
select pg_temp.assert_true(not exists(select 1 from public.notifications where body like '%felt wrong%'),'the notification does not repeat the report');
rollback;
