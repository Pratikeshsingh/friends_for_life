-- Pay-by date, reminders, releasing a place and inviting a replacement.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
-- The rule: 5 days, never later than 3 days before the start, at least the next day.
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-20')='2026-10-06','five days after the invitation');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-07')='2026-10-04','three days before the start when that is sooner');
select pg_temp.assert_true(public.circle_pay_by('2026-10-01 10:00+02','2026-10-03')='2026-10-02','always at least the next day');

insert into auth.users(id,email) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'pb'||i||'@example.test' from generate_series(1,8) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
update public.profiles set date_of_birth='1990-01-01', profile_photo_path=id::text||'/p.jpg';
insert into storage.objects(bucket_id,name,owner) select 'profile-photos',id::text||'/p.jpg',id from public.profiles;
-- Circle starts on a Monday evening in 20 days.
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-000000000001','The Test Circle','Monday evenings',(current_date+20) - ((extract(isodow from current_date+20)::int+6)%7),'19:00','offered');
insert into public.circle_applications(profile_id,answers,status)
select id, jsonb_build_object('languages',jsonb_build_array('English'),'availability_slots','{"mon":["evening"]}'::jsonb,'availability',jsonb_build_array('Monday evening'),'phone','+31612345678'),'invited' from public.profiles where id<>'00000000-0000-0000-0000-000000000008';
-- Member 1 invited 7 days ago and overdue; member 2 invited today.
insert into public.circle_memberships(circle_id,profile_id,status,created_at) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','invited',now()-interval '7 days'),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','invited',now());
update public.circle_applications set status='waiting' where profile_id in ('00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000006');
insert into public.circle_payments(profile_id,circle_id) values('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true((public.circle_snapshot()->>'pay_by')::date=(now() at time zone 'Europe/Amsterdam')::date+5,'the member sees their pay-by date');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true((select (m->>'overdue')::boolean from jsonb_array_elements(public.circle_admin_snapshot()->'circles'->0->'members') m where m->>'profile_id'='00000000-0000-0000-0000-000000000001'),'the organiser sees the overdue place');
select pg_temp.assert_true((public.circle_admin_snapshot()->'payments'->0->>'overdue')::boolean,'and on the payment card');
reset role;
-- Reminders: organiser hears about the overdue place, once.
select public.queue_pay_by_reminders(); select public.queue_pay_by_reminders();
select pg_temp.assert_true((select count(*)=1 from public.notifications where title='A place is overdue'),'one overdue alert per place');
set local role authenticated;
-- Only organisers release, and only unpaid places.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_admin_release_place('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001')$q$),'members cannot release places');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_admin_release_place('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
reset role;
select pg_temp.assert_true((select status='left' from public.circle_memberships where profile_id='00000000-0000-0000-0000-000000000001'),'the place is released');
select pg_temp.assert_true((select status='cancelled' from public.circle_payments where profile_id='00000000-0000-0000-0000-000000000001'),'the unpaid agreement is cancelled');
select pg_temp.assert_true((select status='waiting' from public.circle_applications where profile_id='00000000-0000-0000-0000-000000000001'),'they are back on the waiting list');
-- Invite a replacement; rules are enforced.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_admin_invite('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005');
reset role;
select pg_temp.assert_true((select status='invited' from public.circle_memberships where profile_id='00000000-0000-0000-0000-000000000005'),'the replacement is invited');
select pg_temp.assert_true((select status='invited' from public.circle_applications where profile_id='00000000-0000-0000-0000-000000000005'),'and leaves the waiting list');
update public.circle_applications set answers=answers||'{"availability":["Tuesday morning"]}' where profile_id='00000000-0000-0000-0000-000000000006';
set local role authenticated;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_admin_invite('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000006')$q$),'someone not free at that time is refused');
-- The released member can be invited again later with a fresh deadline.
select public.circle_admin_invite('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
reset role;
select pg_temp.assert_true((select status='invited' and created_at>now()-interval '1 minute' from public.circle_memberships where profile_id='00000000-0000-0000-0000-000000000001'),'a re-invitation gets a fresh pay-by date');
rollback;
