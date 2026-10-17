-- Notification wording, destinations, language and email categories.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data) values('00000000-0000-0000-0000-000000000001','nv1@example.test','{"first_name":"Noor"}');
update public.profiles set language='nl' where id='00000000-0000-0000-0000-000000000001';
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000a','Circle A','Thursday',current_date-3,'19:30','active');
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status) values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-00000000000a',1,'Dinner together','Alkmaar',now()-interval '3 days',now()-interval '3 days'+interval '2 hours',6,'open');
insert into public.notifications(recipient_profile_id,event_id,kind,title,body) values
 ('00000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','update','How did tonight feel?','Your private check-in is ready in your Circle.'),
 ('00000000-0000-0000-0000-000000000001',null,'update','Your Circle is now yours','x'),
 ('00000000-0000-0000-0000-000000000001',null,'update','New messages in your Circle','2 new messages in Circle A. Open VriendTime to read and reply.'),
 ('00000000-0000-0000-0000-000000000001',null,'reminder','Your €19 has not arrived yet','x');
select pg_temp.assert_true((select metadata->>'open' from public.notifications where title='How was your meetup?')='checkin:20000000-0000-0000-0000-000000000001','check-in leads to the check-in');
select pg_temp.assert_true(exists(select 1 from public.notifications where title='Six weeks together: well done!' and metadata->>'open'='outcome'),'graduation reworded');
select pg_temp.assert_true((select kind from public.notifications where title='New messages in your Circle')='chat','chat summary has its own kind');
-- Categories: reminders off, chat on.
insert into public.notification_settings(profile_id,email_enabled,email_reminders) values('00000000-0000-0000-0000-000000000001',true,false);
create temp table got as select * from public.notifications_pending_email_v2(50);
select pg_temp.assert_true(not exists(select 1 from got where title='Your €19 has not arrived yet'),'reminders switched off are not emailed');
select pg_temp.assert_true(exists(select 1 from got where kind='chat'),'chat still emailed');
select pg_temp.assert_true((select bool_and(language='nl') from got),'language comes along');
select pg_temp.assert_true(exists(select 1 from got where open like 'checkin:%'),'destination comes along');
rollback;
