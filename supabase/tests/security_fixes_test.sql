-- Regression tests for 20261004_security_fixes.sql. Each block tries an
-- attack from the 3 October 2026 audit and expects it to be refused, then
-- checks the normal app route still works. Everything is rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'fix'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-000000000001','Test Circle','Thursday',current_date+7,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-000000000001',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,3) i;
insert into public.circle_payments(profile_id,circle_id,status) select profile_id,circle_id,'paid' from public.circle_memberships;
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name)
select ('20000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'10000000-0000-0000-0000-000000000001',i,'Week '||i,'Alkmaar',now()+interval '7 days'*i,now()+interval '7 days'*i+interval '2 hours',6,'open','The shared cafe' from generate_series(1,6) i;
insert into public.chat_threads(id,circle_id,title) values('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Test chat');
insert into public.chat_participants(thread_id,profile_id) select '30000000-0000-0000-0000-000000000001',profile_id from public.circle_memberships;
insert into public.notifications(id,recipient_profile_id,kind,title,body)
values('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','update','Original','Original');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);

-- SEC-01: only read_at can change.
do $$ declare denied boolean:=false; begin
 begin
  update public.notifications set email_snapshot=jsonb_build_object('email','attacker@example.test') where id='50000000-0000-0000-0000-000000000001';
 exception when insufficient_privilege then denied:=true; end;
 perform pg_temp.assert_true(denied,'member cannot write the email snapshot');
 denied:=false;
 begin
  update public.notifications set title='Forged' where id='50000000-0000-0000-0000-000000000001';
 exception when insufficient_privilege then denied:=true; end;
 perform pg_temp.assert_true(denied,'member cannot rewrite a notification');
end $$;
update public.notifications set read_at=now() where id='50000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select read_at is not null from public.notifications where id='50000000-0000-0000-0000-000000000001'),'member can still mark a notification read');

-- SEC-02: the profile email follows the sign-in email, whatever is sent.
update public.profiles set email='unverified@example.test', first_name='Robin' where id=auth.uid();
select pg_temp.assert_true((select email from public.profiles where id=auth.uid())='fix1@example.test','profile email stays the verified sign-in email');
select pg_temp.assert_true((select first_name from public.profiles where id=auth.uid())='Robin','other profile fields still save');
do $$ declare denied boolean:=false; begin
 begin update public.profiles set profile_photo_path='00000000-0000-0000-0000-000000000002/photo.jpg' where id=auth.uid();
 exception when others then denied:=true; end;
 perform pg_temp.assert_true(denied,'member cannot point their photo at someone else''s file');
 denied:=false;
 begin update public.profiles set profile_photo_path=auth.uid()::text||'/nested/photo.jpg' where id=auth.uid();
 exception when others then denied:=true; end;
 perform pg_temp.assert_true(denied,'photo paths cannot be nested');
end $$;
update public.profiles set profile_photo_path=auth.uid()::text||'/photo.jpg' where id=auth.uid();

-- SEC-03: no direct chat inserts; the app route sets the time and the limit holds.
do $$ declare denied boolean:=false; begin
 begin
  insert into public.messages(thread_id,sender_id,body,created_at) values('30000000-0000-0000-0000-000000000001',auth.uid(),'Backdated',now()-interval '2 days');
 exception when insufficient_privilege then denied:=true; end;
 perform pg_temp.assert_true(denied,'member cannot insert messages directly');
end $$;
select public.circle_action('message','{"body":"Hello through the app"}');
reset role;
select pg_temp.assert_true((select created_at>now()-interval '1 minute' from public.messages where body='Hello through the app'),'the database sets the message time');
insert into public.messages(thread_id,sender_id,body,created_at)
select '30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','Backdated by a privileged path '||i,now()-interval '2 days' from generate_series(1,12) i;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $$ declare limited boolean:=false; begin
 begin perform public.circle_action('message','{"body":"One too many"}'); exception when others then limited:=true; end;
 perform pg_temp.assert_true(limited,'backdated timestamps no longer hide messages from the limit');
end $$;

-- SEC-04: extra plans are capped per member, per Circle and in time.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ declare refused boolean:=false; begin
 for i in 1..3 loop perform public.circle_action('schedule',jsonb_build_object('title','Extra '||i,'venue','Cafe','date',current_date+4,'time','12:00')); end loop;
 begin perform public.circle_action('schedule',jsonb_build_object('title','Extra 4','venue','Cafe','date',current_date+4,'time','12:00'));
 exception when others then refused:=true; end;
 perform pg_temp.assert_true(refused,'a fourth upcoming extra is refused');
 refused:=false;
 begin perform public.circle_action('schedule',jsonb_build_object('title','Far away','venue','Cafe','date',current_date+200,'time','12:00'));
 exception when others then refused:=true; end;
 perform pg_temp.assert_true(refused,'extras more than three months ahead are refused');
end $$;
reset role;
select pg_temp.assert_true((select count(*) from public.events where circle_week is null)=3,'refused plans leave nothing behind');
select pg_temp.assert_true((select count(*) from public.notifications where title='Your Circle has a plan update')=9,'only accepted plans notify the Circle');

-- SEC-05: after a refund, no venue through the old API, and attendance is cleaned up.
update public.events set starts_at=now()+interval '12 hours',ends_at=now()+interval '14 hours',venue_address='Private venue' where circle_week=1;
insert into public.event_attendees(event_id,profile_id,status) values('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','joined'),('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','joined');
insert into public.circle_refund_requests(profile_id,circle_id) values('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(exists(select 1 from public.get_revealed_event_venues('20000000-0000-0000-0000-000000000001')),'a current member still gets the venue');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_confirm_refund',jsonb_build_object('id',public.circle_admin_snapshot()->'refunds'->0->>'id','returned',true));
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true(not exists(select 1 from public.get_revealed_event_venues('20000000-0000-0000-0000-000000000001')),'a refunded member gets no venue');
reset role;
select pg_temp.assert_true(not exists(select 1 from public.event_attendees where profile_id='00000000-0000-0000-0000-000000000003'),'refund removes future attendance');
select pg_temp.assert_true(not exists(select 1 from public.chat_participants where profile_id='00000000-0000-0000-0000-000000000003'),'refund removes the chat seat');

-- SEC-08: uploads only directly in the member's own folder, with a quota.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
insert into storage.objects(bucket_id,name,owner) values('profile-photos','00000000-0000-0000-0000-000000000001/one.jpg','00000000-0000-0000-0000-000000000001');
do $$ declare denied boolean:=false; begin
 begin insert into storage.objects(bucket_id,name,owner) values('profile-photos','00000000-0000-0000-0000-000000000001/deep/two.jpg','00000000-0000-0000-0000-000000000001');
 exception when others then denied:=true; end;
 perform pg_temp.assert_true(denied,'nested uploads are refused');
 for i in 2..20 loop insert into storage.objects(bucket_id,name,owner) values('profile-photos','00000000-0000-0000-0000-000000000001/'||i||'.jpg','00000000-0000-0000-0000-000000000001'); end loop;
 denied:=false;
 begin insert into storage.objects(bucket_id,name,owner) values('profile-photos','00000000-0000-0000-0000-000000000001/21.jpg','00000000-0000-0000-0000-000000000001');
 exception when others then denied:=true; end;
 perform pg_temp.assert_true(denied,'the 21st photo is refused');
end $$;
rollback;
