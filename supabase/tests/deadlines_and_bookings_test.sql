-- Paying a week ahead, booking states that say what is really happening,
-- what members actually paid, and Rozey's price.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.error(sql text) returns text language plpgsql as $$ begin execute sql; return null; exception when others then return sqlerrm; end; $$;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Europe/Amsterdam')::date $$;
create function pg_temp.at(d date, t time) returns timestamptz language sql immutable as $$ select (d + t) at time zone 'Europe/Amsterdam' $$;
create function pg_temp.meetup(w int) returns jsonb language sql stable as $$
  select m from jsonb_array_elements(public.circle_admin_snapshot()->'circles') c, jsonb_array_elements(c->'meetups') m
   where c->>'name'='Booking Circle' and (m->>'week')::int=w $$;

-- 1. The deadlines.
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-30')='2026-10-08','seven days after the invitation (since pay-first)');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-07')='2026-10-06','but the day before the first meetup when that is sooner');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-03')='2026-10-02','a late invitation gets until the next day');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-02')='2026-10-01','never past the day before the first meetup');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 23:30+00','2026-10-30')='2026-10-09','counted in Netherlands days');
select pg_temp.assert_true(public.circle_accept_until('2026-10-01 10:00+02','2026-10-30')='2026-10-29','paying late stays possible until the day before the first meetup');
select pg_temp.assert_true(public.circle_accept_until('2026-10-01 10:00+02','2026-10-05')='2026-10-04','also for a late invitation');

insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'dl'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000008');
-- A Circle starting in five days. Member 1 was invited ten days ago and never
-- answered; member 2 was invited today; member 3 said yes ten days ago (to €19).
insert into public.circles(id,name,schedule,start_date,local_time,status)
values('30000000-0000-0000-0000-000000000001','Soon Circle','Thursday evenings',pg_temp.today()+5,'19:00','offered');
insert into public.circle_applications(profile_id,answers,status)
select id,'{}'::jsonb,'invited' from public.profiles where id<>'00000000-0000-0000-0000-000000000008';
insert into public.circle_memberships(circle_id,profile_id,status,created_at) values
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','invited',now()-interval '10 days'),
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','invited',now()),
 ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','invited',now()-interval '10 days');
insert into public.circle_payments(profile_id,circle_id,amount_cents,agreement_version)
values('00000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001',1900,'founding-19-eur-v1');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true((public.circle_snapshot()->>'pay_by')::date=pg_temp.today()-3,'the pay-by date was seven days after the invitation');
select pg_temp.assert_true((public.circle_snapshot()->>'accept_until')::date=pg_temp.today()+4,'saying yes late stays possible until the day before the start');
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('join','{"agree_to_pay":true}')$q$) is null,'so a late yes is taken');
select public.circle_action('decline');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((public.circle_snapshot()->>'pay_by')::date=pg_temp.today()+4 and (public.circle_snapshot()->>'accept_until')::date=pg_temp.today()+4,'a late invitation: until the day before the start');
select public.circle_action('join','{"agree_to_pay":true}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('join','{"agree_to_pay":true}')$q$) is null,'someone who already said yes is not locked out');
select pg_temp.assert_true((public.circle_snapshot()->'payment_history'->0->>'amount_cents')::int=1900,'members see what they actually paid');
reset role;
select pg_temp.assert_true((select status from public.circle_memberships where profile_id='00000000-0000-0000-0000-000000000001')='left','saying no still works after it closed');
select pg_temp.assert_true(exists(select 1 from public.circle_payments where profile_id='00000000-0000-0000-0000-000000000002' and status='awaiting_payment' and amount_cents=3900),'saying yes in time works');

-- No new invitations on the day of the first meetup.
insert into public.circles(id,name,schedule,start_date,local_time,status)
values('30000000-0000-0000-0000-000000000002','Today Circle','Thursday evenings',pg_temp.today(),'19:00','offered');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_admin_invite('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000004')$q$) like 'It’s too late to invite someone new%','no invitation on the day of the first meetup');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_admin_invite_before_deadline('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004')$q$) is not null,'the older invite function is not callable directly');
reset role;

-- 2. Bookings. Week 1 in ten days and week 2 in seventeen, both at an email-only place.
insert into public.circles(id,name,schedule,start_date,local_time,status)
values('30000000-0000-0000-0000-000000000003','Booking Circle','Thursday evenings',pg_temp.today()+10,'20:00','active');
insert into public.events(id,circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003',1,'Hello, new faces','Alkmaar',pg_temp.at(pg_temp.today()+10,'20:00'),pg_temp.at(pg_temp.today()+10,'22:00'),6,'open','The Boules Club'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000003',2,'Find out who’s secretly competitive','Alkmaar',pg_temp.at(pg_temp.today()+17,'20:00'),pg_temp.at(pg_temp.today()+17,'22:00'),6,'open','The Boules Club'),
 ('40000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000003',5,'Your call','Alkmaar',pg_temp.at(pg_temp.today()+12,'20:00'),pg_temp.at(pg_temp.today()+12,'22:00'),6,'open','Jonas Bistro Bar');

-- Two weeks ahead and not booked: on the organiser's list, once. Week 5 is the group's.
select public.queue_meetup_housekeeping();
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select count(*) from public.notifications where title='A week to book')=1,'one alert, for week 1 only');
select pg_temp.assert_true((select body from public.notifications where title='A week to book') like 'Booking Circle · week 1 on % at The Boules Club: not booked yet.','saying which week and where');

-- The booking email: waiting, then failed, then sent.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(pg_temp.meetup(5)->>'id'='40000000-0000-0000-0000-000000000005','the organiser''s meetups say which week they are');
select public.circle_action('admin_booking','{"id":"40000000-0000-0000-0000-000000000001","step":"email"}');
select pg_temp.assert_true(pg_temp.meetup(1)->'booking_email'->>'sent_at' is null and not (pg_temp.meetup(1)->'booking_email'->>'failed')::boolean,'the organiser sees it waiting to go');
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('admin_booking','{"id":"40000000-0000-0000-0000-000000000001","step":"email","again":true}')$q$)='The booking email for this week is still on its way.','no second email while the first waits');
reset role;
select public.ack_venue_email(id,'Mailbox unavailable') from public.venue_emails_pending(10);
select public.ack_venue_email(id,'Mailbox unavailable') from public.venue_emails_pending(10);
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='A booking email failed'),'no alarm while it is still being tried');
select public.ack_venue_email(id,'Mailbox unavailable') from public.venue_emails_pending(10);
select pg_temp.assert_true((select count(*) from public.notifications where title='A booking email failed')=1,'after the last try, the organiser hears it failed');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true((pg_temp.meetup(1)->'booking_email'->>'failed')::boolean and pg_temp.meetup(1)->'booking_email'->>'error'='Mailbox unavailable','and sees why');
-- The next try is sent later (here everything shares one transaction's clock).
reset role;
update public.circle_venue_emails set created_at=created_at-interval '1 hour';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_booking','{"id":"40000000-0000-0000-0000-000000000001","step":"email","again":true}');
reset role;
select public.ack_venue_email(id) from public.venue_emails_pending(10);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(pg_temp.meetup(1)->'booking_email'->>'sent_at' is not null and pg_temp.meetup(1)->>'booking_status'='requested','sent, waiting for the place to answer');
reset role;

-- A new time after the email went out: not "asked" any more, and the old request is kept.
update public.events set starts_at=starts_at+interval '30 minutes' where id='40000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select booking_status is null and booking_requested_at is null from public.events where id='40000000-0000-0000-0000-000000000001'),'a new time undoes the request');
select pg_temp.assert_true((select booking_previous->0->>'status'='requested' and booking_previous->0->>'venue'='The Boules Club' and (booking_previous->0->>'starts_at')::timestamptz=pg_temp.at(pg_temp.today()+10,'20:00') from public.events where id='40000000-0000-0000-0000-000000000001'),'the old request stays as a note');
-- Booked: the note is done.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_booking','{"id":"40000000-0000-0000-0000-000000000001","step":"booked"}');
select pg_temp.assert_true(pg_temp.meetup(1)->>'booking_status'='booked' and pg_temp.meetup(1)->'booking_previous' = 'null'::jsonb,'booked again: the note is cleared');
reset role;
-- A new place for a booked week: not booked any more, the old booking to cancel, and back on the list.
update public.events set venue_name='Jonas Bistro Bar' where id='40000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select booking_status is null and booking_previous->0->>'status'='booked' and booking_previous->0->>'venue'='The Boules Club' from public.events where id='40000000-0000-0000-0000-000000000001'),'a new place undoes "booked", and the old booking is kept to cancel');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true((select count(*) from public.notifications where title='A week to book')=2,'and the week is on the list again');
-- Saving the same place and time changes nothing.
update public.events set booking_status='booked', booking_previous=null where id='40000000-0000-0000-0000-000000000001';
update public.events set venue_name='Jonas Bistro Bar', title='Hello again' where id='40000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select booking_status='booked' and booking_previous is null from public.events where id='40000000-0000-0000-0000-000000000001'),'saving the same plan keeps the booking');
-- An email that never went out: withdrawn with the change, and nothing to cancel.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_booking','{"id":"40000000-0000-0000-0000-000000000002","step":"email"}');
reset role;
update public.events set starts_at=starts_at+interval '1 hour' where id='40000000-0000-0000-0000-000000000002';
select pg_temp.assert_true(not exists(select 1 from public.circle_venue_emails where event_id='40000000-0000-0000-0000-000000000002'),'the unsent email is withdrawn');
select pg_temp.assert_true((select booking_status is null and booking_previous is null from public.events where id='40000000-0000-0000-0000-000000000002'),'and the place never heard of it');

-- Reminders that fit the person (20261037). Starting in 20 days: 4 hasn't
-- answered, 5 said yes but hasn't paid, 7 moved here with the fee paid; all
-- invited six days ago, so tomorrow is their pay-by date. Starting in 8 days:
-- 6 was invited ten days ago and hasn't answered: no "last chance" push.
insert into public.circles(id,name,schedule,start_date,local_time,status) values
 ('30000000-0000-0000-0000-000000000004','Reminder Circle','Thursday evenings',pg_temp.today()+20,'19:00','offered'),
 ('30000000-0000-0000-0000-000000000005','Closing Circle','Thursday evenings',pg_temp.today()+8,'19:00','offered');
insert into public.circle_memberships(circle_id,profile_id,status,created_at) values
 ('30000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000004','invited',now()-interval '6 days'),
 ('30000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000005','invited',now()-interval '6 days'),
 ('30000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000007','invited',now()-interval '6 days'),
 ('30000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000006','invited',now()-interval '10 days');
insert into public.circle_payments(profile_id,circle_id) values('00000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000004');
insert into public.circle_moves(profile_id,from_circle_id) values('00000000-0000-0000-0000-000000000007','30000000-0000-0000-0000-000000000003');
delete from public.notifications;
select public.queue_pay_by_reminders(); select public.queue_pay_by_reminders();
create function pg_temp.got(who int) returns text language sql stable as $$
  select string_agg(title||' / '||body,' | ' order by title) from public.notifications
   where recipient_profile_id=('00000000-0000-0000-0000-'||lpad(who::text,12,'0'))::uuid $$;
select pg_temp.assert_true(pg_temp.got(4)='Your invitation is waiting / Accept and pay for Reminder Circle by the end of tomorrow to keep your place.','not answered yet: the invitation is waiting');
select pg_temp.assert_true(pg_temp.got(5)='Your €39 has not arrived yet / Your place in Reminder Circle is confirmed once your €39 arrives. Pay by the end of tomorrow to keep it.','said yes: the money is what''s missing');
select pg_temp.assert_true(pg_temp.got(7)='Your invitation is waiting / Reply to your invitation to Reminder Circle by the end of tomorrow to keep your place. Your fee is already paid.','moved here: nothing to pay');
select pg_temp.assert_true(pg_temp.got(6) is null,'paying late is possible, but not pushed');
select pg_temp.assert_true(pg_temp.got(8) like '%Member 6 has not said yes to Closing Circle by the pay-by date. Send a reminder, or release the place to invite someone else.%','the organiser hears who hasn''t said yes');
select pg_temp.assert_true(pg_temp.got(8) like '%Member 3 has not paid for Soon Circle by the pay-by date.%','and who hasn''t paid');

-- After paying: the place is confirmed, without suggesting meals are included.
select pg_temp.assert_true(position('so your place is confirmed. Open your Circle to meet the group and see the six weeks.' in pg_get_functiondef('public.circle_action_before_moves(text, jsonb)'::regprocedure))>0
  and position('six programme meetups are included' in pg_get_functiondef('public.circle_action_before_moves(text, jsonb)'::regprocedure))=0,'the payment message says the place is confirmed');

-- Nothing internal is callable from outside.
select pg_temp.assert_true(not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and prosecdef and has_function_privilege('anon',oid,'execute')),'no privileged function is open to anyone signed out');

-- 3. Rozey's dinner.
select pg_temp.assert_true((select cost from public.circle_programme_template where city='Alkmaar' and kind='evening' and week=3)='About €38 per person, or €43 from Friday to Sunday: dinner and drinks, all you can eat.','Rozey: €38, or €43 from Friday to Sunday');
rollback;
