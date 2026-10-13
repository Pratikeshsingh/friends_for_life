-- Organiser alerts arrive as one email at set times; safety reports at once.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'dg'||i||'@example.test' from generate_series(1,2) i;
insert into public.circle_admins values('00000000-0000-0000-0000-000000000001');
insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key) values
 ('00000000-0000-0000-0000-000000000001','support','A meetup has no place yet','Circle A · week 3 on Thu 22 Oct: add the place so members know where to go.','t1'),
 ('00000000-0000-0000-0000-000000000001','support','Circles can be formed','5 people are ready to be grouped. Open Form Circles to see the groups.','t2'),
 ('00000000-0000-0000-0000-000000000001','support','A member reported a concern','Someone reported a concern.','t3'),
 ('00000000-0000-0000-0000-000000000002','support','Thanks for your report','We will look at it.','t4');
update public.notifications set read_at=now() where dedupe_key='t2';
-- The email queue sends the report and the member's notice, not the other organiser alerts.
create temp table q as select * from public.notifications_pending_email_v2(50);
select pg_temp.assert_true((select string_agg(title,',' order by title) from q)='A member reported a concern,Thanks for your report','only urgent and member emails go out at once');
-- Outside 09/13/18 nothing happens unless forced.
select public.queue_organiser_digest(true);
select pg_temp.assert_true((select count(*) from public.notifications where title='Things to do in VriendTime')=1,'one digest');
select pg_temp.assert_true((select body from public.notifications where title='Things to do in VriendTime') like '• A meetup has no place yet: Circle A%','lists the unread alert');
select pg_temp.assert_true((select body from public.notifications where title='Things to do in VriendTime') not like '%Circles can be formed%','skips what the organiser already opened');
select pg_temp.assert_true((select metadata->>'open' from public.notifications where title='Things to do in VriendTime')='organiser:todo','opens the To do tab');
-- The digest itself is emailed; the alerts it covered are not.
create temp table q2 as select * from public.notifications_pending_email_v2(50);
select pg_temp.assert_true(exists(select 1 from q2 where title='Things to do in VriendTime'),'the digest is emailed');
select pg_temp.assert_true(not exists(select 1 from q2 where title in ('A meetup has no place yet','Circles can be formed')),'covered alerts are not emailed');
-- Nothing new: no second email.
select public.queue_organiser_digest(true);
select pg_temp.assert_true((select count(*) from public.notifications where title='Things to do in VriendTime')=1,'no repeat without something new');
rollback;
