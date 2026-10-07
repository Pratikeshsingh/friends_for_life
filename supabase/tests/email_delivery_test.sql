-- Email delivery: deferring without using an attempt, old notifications not
-- emailed, and the WhatsApp number is optional.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'ed'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,2) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'ed%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'ed%@example.test';

-- Apply without a WhatsApp number.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('apply',jsonb_build_object('name','Member 1','city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'phone',''));
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='waiting','applying works without a WhatsApp number');
select pg_temp.assert_true(not (public.circle_snapshot()->>'needs_details')::boolean,'no WhatsApp number is not a missing detail');
do $$ declare blocked boolean:=false; begin
 begin perform public.circle_action('draft',(public.circle_snapshot()->'application')||'{"phone":"12"}'::jsonb); exception when others then blocked:=true; end;
 perform pg_temp.assert_true(blocked,'a WhatsApp number that is given must still be valid');
end $$;
reset role;

-- Deferring hands the notification back without using an attempt.
delete from public.notifications;
insert into public.notifications(recipient_profile_id,kind,title,body) values('00000000-0000-0000-0000-000000000002','update','Hello','Body');
create temp table claimed as select * from public.notifications_pending_email(1);
select pg_temp.assert_true((select email_attempts=1 from public.notifications),'claiming uses an attempt');
select public.defer_notification_email(id,lease_token,3600,'Daily limit reached') from claimed;
select pg_temp.assert_true((select email_attempts=0 and email_first_claimed_at is null and email_lease_token is null and email_retry_at>now()+interval '59 minutes' from public.notifications),'deferring gives the attempt back and waits');
select pg_temp.assert_true(not exists(select 1 from public.notifications_pending_email(1)),'a deferred email waits until its retry time');
do $$ declare c record; begin
 select * into c from claimed;
 begin perform public.defer_notification_email(c.id,c.lease_token); raise exception 'stale defer accepted'; exception when others then if sqlerrm='stale defer accepted' then raise; end if; end;
end $$;
set local role authenticated;
do $$ begin
 begin perform public.defer_notification_email(gen_random_uuid(),gen_random_uuid()); raise exception 'member deferred'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
