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
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ declare original jsonb:=public.circle_snapshot()->'application'; begin
 perform public.circle_action('draft',original||'{"name":""}'::jsonb);
 perform pg_temp.assert_true(public.circle_snapshot()->>'stage'='apply','edited draft is removed from matching until valid resubmission');
 perform public.circle_action('apply',original);
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_create','{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Thursday Circle","schedule":"Thursday evenings","start_date":"2027-10-07","time":"19:30"}');
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'circles')=1,'admin created exactly one circle');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='invited','assigned member sees invitation');
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'meetups')=6,'six weekly meetups generated');
select pg_temp.assert_true((select bool_and(item->>'time'='19:30') from jsonb_array_elements(public.circle_snapshot()->'meetups') item),'DST preserves local meeting hour');
select pg_temp.assert_true((select count(*)=0 from public.event_catalog),'public catalog excludes Circle events');
do $$ declare blocked boolean:=false; eid uuid:=(public.circle_snapshot()->'meetups'->0->>'id')::uuid; begin
 begin perform public.circle_action('rsvp',jsonb_build_object('id',eid,'going',true)); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'unpaid invitee cannot RSVP');
 blocked:=false;
 begin perform public.reserve_event(eid); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'legacy reservation RPC cannot bypass payment membership');
 blocked:=false;
 begin perform public.circle_action('join'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'live join cannot fake a payment');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000007',true);
select pg_temp.assert_true(not(public.circle_snapshot() ? 'members'),'outsider cannot inspect Circle members');
reset role;
-- Emulate trusted payment confirmation, solely inside this rollback-only test.
update public.circle_memberships set status='joined',payment_status='paid';
update public.circles set status='active';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('rsvp',jsonb_build_object('id',public.circle_snapshot()->'meetups'->0->>'id','going',true));
select public.circle_action('rsvp',jsonb_build_object('id',public.circle_snapshot()->'meetups'->0->>'id','going',true));
select pg_temp.assert_true((public.circle_snapshot()->'meetups'->0->>'confirmed')::int=1,'RSVP retry does not double count');
select public.circle_action('message','{"body":"Hello Circle"}');
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'messages')=1,'member message persists');
reset role;
update public.events set starts_at=now()-interval '3 hours',ends_at=now()-interval '1 hour' where circle_week=1;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('complete_meetup',jsonb_build_object('id',public.circle_admin_snapshot()->'circles'->0->'meetups'->0->>'id'));
select public.circle_action('admin_attendance',jsonb_build_object('id',public.circle_admin_snapshot()->'circles'->0->'meetups'->0->>'id','profile_id','00000000-0000-0000-0000-000000000001','attended',true));
select pg_temp.assert_true((public.circle_admin_snapshot()->'metrics'->>'meetup_1_attended')::int=1,'actual attendance recorded separately from RSVP');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('check_in',jsonb_build_object('id',public.circle_snapshot()->'meetups'->0->>'id','feeling','😐 Okay','connections','[]'::jsonb));
select public.circle_action('refund');
select pg_temp.assert_true(public.circle_snapshot()->>'refund'='requested','eligible refund request saved');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'check_ins')=0,'other members cannot see private check-ins');
select pg_temp.assert_true(public.circle_snapshot()->>'refund' is null,'other members cannot see refund request');
reset role;
update public.events set completed_at=now()-interval '49 hours' where circle_week=1;
set local role authenticated;
do $$ declare blocked boolean:=false; begin
 begin perform public.circle_action('refund'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'refund window expires after 48 hours');
end $$;
reset role;
select public.queue_circle_notifications();
select pg_temp.assert_true(public.queue_circle_notifications()=0,'notification retries are idempotent');
rollback;
