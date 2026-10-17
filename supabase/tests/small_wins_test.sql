-- Small wins (20261041): city, Friday mornings, "Something else", notifications
-- that expire, the WhatsApp opt-in and the four-weekly times check.
begin;
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.error(sql text) returns text language plpgsql as $$ begin execute sql; return null; exception when others then return sqlerrm; end; $$;
create function pg_temp.u(i int) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid $$;
grant execute on function pg_temp.u(int) to authenticated;

insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.u(i),'sw'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,4) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'sw%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'sw%@example.test';
insert into public.circle_admins(profile_id) values(pg_temp.u(4));

-- 1. City.
select pg_temp.assert_true((select bool_and(city='Alkmaar') from public.profiles where email like 'sw%@example.test'),'everyone has a city: Alkmaar for now');

-- 2. Friday mornings for one-to-ones.
select pg_temp.assert_true(position('when dy = ''fri'' then array[''morning'', ''afternoon'', ''evening'']' in pg_get_functiondef('public.circle_coffee_slot(uuid, uuid, uuid, date, date)'::regprocedure))>0,'Friday mornings can host a one-to-one');

-- 3. "Something else", with a note.
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
select public.circle_action('apply',jsonb_build_object('name','Member 1','city','Alkmaar','date_of_birth','1990-01-01','languages',jsonb_build_array('English'),
  'availability_slots','{"fri":["morning"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),
  'goals',jsonb_build_array('Other parents','Something else'),'goals_other','  Meeting other parents  ',
  'life_context',jsonb_build_array('Something else'),'life_context_other',repeat('x',120),'energy',2,'commitment',true));
reset role;
select pg_temp.assert_true((select answers->'availability' from public.circle_applications where profile_id=pg_temp.u(1))='["Friday morning"]'::jsonb,'Friday morning is a time');
select pg_temp.assert_true((select answers->>'goals_other' from public.circle_applications where profile_id=pg_temp.u(1))='Meeting other parents','the note is kept, trimmed');
select pg_temp.assert_true((select length(answers->>'life_context_other') from public.circle_applications where profile_id=pg_temp.u(1))=80,'and kept short');

-- 4. Notifications that expire.
insert into public.circle_applications(profile_id,answers,status) select pg_temp.u(i),'{}'::jsonb,'joined' from generate_series(2,3) i;
insert into public.circles(id,name,schedule,start_date,local_time,status) values('32000000-0000-0000-0000-000000000001','Friday Circle','Friday mornings',current_date-10,'10:30','active');
insert into public.chat_threads(circle_id,title,kind) values('32000000-0000-0000-0000-000000000001','Friday Circle','group');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status) select '32000000-0000-0000-0000-000000000001',pg_temp.u(i),'joined','paid' from generate_series(1,3) i;
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status) values
 ('33000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001',1,'Hello, new faces','Alkmaar',now()-interval '10 days',now()-interval '10 days'+interval '2 hours',6,'open'),
 ('33000000-0000-0000-0000-000000000002','32000000-0000-0000-0000-000000000001',2,'Find out who’s secretly competitive','Alkmaar',now()-interval '3 days',now()-interval '3 days'+interval '2 hours',6,'open'),
 ('33000000-0000-0000-0000-000000000003','32000000-0000-0000-0000-000000000001',3,'Go beyond','Alkmaar',now()+interval '4 days',now()+interval '4 days 2 hours',6,'open');
delete from public.notifications;
insert into public.notifications(recipient_profile_id,event_id,kind,title,body) values
 (pg_temp.u(2),'33000000-0000-0000-0000-000000000003','reminder','See your Circle tomorrow','Go beyond · Open your Circle for the plan.'),
 (pg_temp.u(2),'33000000-0000-0000-0000-000000000002','update','How did tonight feel?','Tell us.');
select pg_temp.assert_true((select expires_at from public.notifications where event_id='33000000-0000-0000-0000-000000000003')=(select ends_at from public.events where id='33000000-0000-0000-0000-000000000003'),'a note about a meetup ends with the meetup');
select pg_temp.assert_true((select expires_at is null from public.notifications where event_id='33000000-0000-0000-0000-000000000002'),'a check-in about a past meetup never expires');
update public.notifications set expires_at=now()-interval '1 minute' where event_id='33000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(2)::text, true);
select pg_temp.assert_true((public.circle_snapshot()->>'unread_notifications')::int=1,'something that is over no longer counts as new');
reset role;
select pg_temp.assert_true(not exists(select 1 from public.notifications_pending_email_v2(50) x where x.title='See your Circle tomorrow'),'and is not emailed late');

-- 5. WhatsApp: after week 2, opt-in, with a number.
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(2)::text, true);
select pg_temp.assert_true((public.circle_snapshot()->'whatsapp'->>'has_phone')='false','asked after week 2, no number yet');
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('whatsapp','{"answer":"yes"}')$q$)='Add a valid WhatsApp number, for example 06 12345678.','a yes needs a number');
select public.circle_action('whatsapp','{"answer":"yes","phone":"06 12345678"}');
select pg_temp.assert_true(public.circle_snapshot()->'whatsapp'->>'answer'='yes','the answer is saved');
select set_config('request.jwt.claim.sub', pg_temp.u(3)::text, true);
select public.circle_action('whatsapp','{"answer":"no"}');
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
select public.circle_action('whatsapp','{"answer":"yes","phone":"+31611111111"}');
select set_config('request.jwt.claim.sub', pg_temp.u(4)::text, true);
create temp table wa as select c->'whatsapp' w from jsonb_array_elements(public.circle_admin_snapshot()->'circles') c where c->>'name'='Friday Circle';
reset role;
select pg_temp.assert_true((select count(*) from wa, jsonb_array_elements(w) x where x->>'answer'='yes' and x->>'phone' like '+31%')=2,'the organiser sees who said yes, with their number');
select pg_temp.assert_true((select count(*) from wa, jsonb_array_elements(w) x where x->>'answer'='no' and x->>'phone' is null)=1,'and no number for a no');
select pg_temp.assert_true((select count(*) from public.notifications where title='A WhatsApp group can be made')=1,'two yeses: the organiser hears once');
update public.events set ends_at=now()+interval '1 day', starts_at=now()+interval '23 hours' where circle_week=2;
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(3)::text, true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('whatsapp','{"answer":"yes"}')$q$)='This question comes after your second meetup.','not before week 2');
reset role;
update public.events set ends_at=now()-interval '1 day', starts_at=now()-interval '26 hours' where circle_week=2;

-- 6. The hourly prompts.
delete from public.circle_whatsapp where profile_id=pg_temp.u(3);
update public.circle_applications set status='waiting', updated_at=now()-interval '29 days' where profile_id=pg_temp.u(1);
select public.queue_circle_prompts(); select public.queue_circle_prompts();
select pg_temp.assert_true((select count(*) from public.notifications where title='A WhatsApp group for your Circle?')=1,'asked once, only who hasn''t answered');
select pg_temp.assert_true((select recipient_profile_id from public.notifications where title='A WhatsApp group for your Circle?')=pg_temp.u(3),'that is member 3');
select pg_temp.assert_true((select count(*) from public.notifications where title='Still free at your times?' and metadata->>'open'='profile')=1,'four weeks waiting: one check, opening Profile');
update public.circle_applications set updated_at=now() where profile_id=pg_temp.u(1);
select public.queue_circle_prompts();
select pg_temp.assert_true((select count(*) from public.notifications where title='Still free at your times?')=1,'confirmed: no new check');
-- 7. (20261042) One-to-one times, other times to the organiser, "already have a group".
insert into auth.users(id,email,raw_user_meta_data) values(pg_temp.u(5),'sw5@example.test','{"first_name":"Member 5"}');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(5)::text, true);
select public.circle_action('draft',jsonb_build_object('name','Member 5','city','Alkmaar','date_of_birth','1990-01-01','languages',jsonb_build_array('English'),
  'availability_slots','{"fri":["morning"]}'::jsonb,'coffee_slots','{"fri":["morning","afternoon","nonsense"],"xyz":["evening"]}'::jsonb,
  'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),
  'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'other_times','Monday evenings'));
reset role;
select pg_temp.assert_true((select answers->'coffee_slots' from public.circle_applications where profile_id=pg_temp.u(5))='{"fri":["afternoon","morning"]}'::jsonb,'one-to-one times are kept, only real days and times');
select pg_temp.assert_true(position('answers->''coffee_slots'', answers->''availability_slots''' in pg_get_functiondef('public.circle_coffee_slot(uuid, uuid, uuid, date, date)'::regprocedure))>0,'and used for one-to-ones');
select pg_temp.assert_true((select count(*) from public.notifications where title='Someone needs other times' and body like 'Member 5: “Monday evenings”%')=1,'other times go to the organiser');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(3)::text, true);
select public.circle_action('whatsapp','{"answer":"have"}');
reset role;
select pg_temp.assert_true((select answer from public.circle_whatsapp where profile_id=pg_temp.u(3))='have','"we already have a group" is an answer');
rollback;
