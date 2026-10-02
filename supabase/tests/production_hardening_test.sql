begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'hardening'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-000000000001','Test Circle','Thursday',current_date+7,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-000000000001',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,3) i;
insert into public.circle_payments(profile_id,circle_id,status)
select profile_id,circle_id,'paid' from public.circle_memberships;
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name)
select ('20000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'10000000-0000-0000-0000-000000000001',i,'Week '||i,'Alkmaar',now()+interval '7 days'*i,now()+interval '7 days'*i+interval '2 hours',6,'open','The shared cafe' from generate_series(1,6) i;
insert into public.chat_threads(id,circle_id,title) values('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Test chat');
insert into public.chat_participants(thread_id,profile_id) select '30000000-0000-0000-0000-000000000001',profile_id from public.circle_memberships;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->'meetups'->0->>'venue' is null,'organiser venue remains hidden');
select pg_temp.assert_true(public.circle_snapshot()->'meetups'->3->>'venue'='The shared cafe','group venue is visible immediately');
select pg_temp.assert_true(public.circle_snapshot()->>'paid_members'='3','paid headcount independent of RSVP');
select public.circle_action('schedule','{"id":"20000000-0000-0000-0000-000000000004","version":0,"title":"Games","venue":"Cafe","date":"2099-01-01","time":"10:00","request_id":"40000000-0000-0000-0000-000000000001"}');
select public.circle_action('schedule','{"id":"20000000-0000-0000-0000-000000000004","version":0,"title":"Games","venue":"Cafe","date":"2099-01-01","time":"10:00","request_id":"40000000-0000-0000-0000-000000000001"}');
select pg_temp.assert_true(public.circle_snapshot()->'meetups'->3->>'plan_version'='1','retries do not update twice');
select pg_temp.assert_true((public.circle_snapshot()->'meetups'->3->>'starts_at')::timestamptz<now()+interval '29 days','member cannot move the weekly date');
do $$ begin
 begin perform public.circle_action('schedule','{"id":"20000000-0000-0000-0000-000000000004","version":0,"title":"Other","venue":"Elsewhere"}'); raise exception 'stale write accepted'; exception when others then if sqlerrm='stale write accepted' then raise; end if; end;
end $$;
select public.circle_action('schedule',jsonb_build_object('title','Extra coffee','venue','Coffee place','date',current_date+3,'time','12:00','request_id','40000000-0000-0000-0000-000000000002'));
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'meetups')=7,'extra meetup saved');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $$ declare extra jsonb; begin
 select m into extra from jsonb_array_elements(public.circle_snapshot()->'meetups') m where m->>'week' is null;
 begin perform public.circle_action('cancel_extra',jsonb_build_object('id',extra->>'id','version',extra->'plan_version')); raise exception 'unauthorized cancellation accepted'; exception when others then if sqlerrm='unauthorized cancellation accepted' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('message','{"body":"One message","request_id":"40000000-0000-0000-0000-000000000003"}');
select public.circle_action('message','{"body":"One message","request_id":"40000000-0000-0000-0000-000000000003"}');
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'messages')=1,'message retry is idempotent');
-- Cancellation ends participation immediately but retains refund tracking.
select public.circle_action('cancel_agreement');
select pg_temp.assert_true(public.circle_snapshot()->'circle' is null,'cancelled member no longer has Circle access');
select pg_temp.assert_true(public.circle_snapshot()->'payment_history'->0->>'refund'='requested','refund remains visible after leaving');
do $$ begin
 begin perform public.circle_messages_before(now()+interval '1 day','ffffffff-ffff-ffff-ffff-ffffffffffff'); raise exception 'former member read chat'; exception when others then if sqlerrm='former member read chat' then raise; end if; end;
end $$;
-- A member who left on older software can still cancel a recent paid agreement.
reset role;
update public.circle_memberships set status='left' where profile_id='00000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.circle_action('cancel_agreement');
select pg_temp.assert_true(public.circle_snapshot()->'payment_history'->0->>'refund'='requested','legacy leaver can cancel');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
do $$ begin
 begin perform public.circle_leave(); raise exception 'eligible payment stranded by leave'; exception when others then if sqlerrm='eligible payment stranded by leave' then raise; end if; end;
end $$;
reset role;
-- End-of-meetup eligibility does not wait for manual completion.
update public.events set starts_at=now()-interval '3 hours',ends_at=now()-interval '1 hour' where circle_week=1;
set local role authenticated;
select pg_temp.assert_true((public.circle_snapshot()->>'refund_eligible')::boolean,'refund clock follows end time');
select public.circle_action('check_in','{"id":"20000000-0000-0000-0000-000000000001","feeling":"🙂 Good","connections":[]}');
select public.record_app_error('test','StateError','test-build','test-ref');
select public.record_app_error('test','StateError','test-build','test-ref-2');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.app_error_events),'diagnostics rate limited');
-- Disjoint leases, stale acknowledgements rejected, successful ack removes row.
create temp table claimed as select * from public.notifications_pending_email(1);
select pg_temp.assert_true((select count(*)=1 from claimed),'email claim available');
select pg_temp.assert_true(not exists(select 1 from public.notifications_pending_email(50) n join claimed c on n.id=c.id),'live lease cannot be claimed twice');
select public.ack_notification_email(id,lease_token) from claimed;
select pg_temp.assert_true((select n.emailed_at is not null from public.notifications n join claimed c on n.id=c.id),'email ack recorded');
do $$ declare c record; begin
 select * into c from claimed;
 begin perform public.ack_notification_email(c.id,c.lease_token); raise exception 'stale ack accepted'; exception when others then if sqlerrm='stale ack accepted' then raise; end if; end;
end $$;
set local role authenticated;
do $$ begin
 begin perform public.notifications_pending_email(1); raise exception 'member drained queue'; exception when insufficient_privilege then null; end;
 begin perform public.circle_action_before_hardening('message','{}'); raise exception 'member bypassed wrapper'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
