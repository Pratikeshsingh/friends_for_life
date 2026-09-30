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

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ declare blocked boolean:=false; begin
 begin perform public.circle_action('join'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'explicit payment agreement required');
end $$;
select public.circle_action('join','{"agree_to_pay":true}');
select public.circle_action('join','{"agree_to_pay":true}');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='invited','consent alone does not unlock Circle');
select pg_temp.assert_true(public.circle_snapshot()->'payment_agreement'->>'status'='awaiting_payment','awaiting receipt');
do $$ declare blocked boolean:=false; pid text:=public.circle_snapshot()->'payment_agreement'->>'id'; begin
 begin perform public.circle_action('admin_confirm_payment',jsonb_build_object('id',pid,'received',true)); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'member cannot confirm own payment');
 blocked:=false;
 begin perform public.circle_action_core('message','{"body":"bypass"}'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'internal function inaccessible');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'payments')=1,'repeat consent is idempotent');
select public.circle_action('admin_confirm_payment',jsonb_build_object('id',public.circle_admin_snapshot()->'payments'->0->>'id','received',true));
select public.circle_action('admin_confirm_payment',jsonb_build_object('id',public.circle_admin_snapshot()->'payments'->0->>'id','received',true));
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.circle_action('join','{"agree_to_pay":true}');
select pg_temp.assert_true(public.circle_snapshot()->'payment_agreement'->>'status'='awaiting_payment','second invitee can accept after first payment');
select public.circle_action('decline');
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','decline returns applicant to matching');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='active','confirmed payment activates membership');
select public.circle_action('message','{"body":"A real Circle message"}');
select public.circle_action('report','{"reason":"Please help with a concern"}');
select pg_temp.assert_true(jsonb_array_length(public.circle_export_data()->'reports')=1,'data export contains own report');
select public.circle_action('cancel_agreement');
select pg_temp.assert_true(public.circle_snapshot()->>'refund'='requested','14 day cancellation records refund');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'reports')=1,'organiser can review report');
select public.circle_action('admin_resolve_report',jsonb_build_object('id',public.circle_admin_snapshot()->'reports'->0->>'id'));
select public.circle_action('admin_cancel_circle',jsonb_build_object('id',public.circle_admin_snapshot()->'circles'->0->>'id'));
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='cancelled','cancelled Circle displayed accurately');
do $$ declare blocked boolean:=false; begin
 begin perform public.circle_action('message','{"body":"Should not send"}'); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'cancelled Circle cannot send messages');
end $$;
reset role;
-- Deleting an account must not erase an outstanding refund obligation.
delete from auth.users where id='00000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(jsonb_array_length(public.circle_admin_snapshot()->'refunds')=1,'refund retained after account deletion');
select public.circle_action('admin_confirm_refund',jsonb_build_object('id',public.circle_admin_snapshot()->'refunds'->0->>'id','returned',true));
select public.circle_action('admin_confirm_refund',jsonb_build_object('id',public.circle_admin_snapshot()->'refunds'->0->>'id','returned',true));
select pg_temp.assert_true(public.circle_admin_snapshot()->'refunds'->0->>'status'='refunded','manual refund completed idempotently after deletion');
rollback;
