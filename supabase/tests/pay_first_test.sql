-- Pay first, then meet the group (20261040): seats without names, seven days
-- to pay, late payments into a seat or a credit, and starting the Circle.
begin;
select set_config('vriendtime.pay_first', 'on', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.error(sql text) returns text language plpgsql as $$ begin execute sql; return null; exception when others then return sqlerrm; end; $$;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Europe/Amsterdam')::date $$;
-- The first Thursday at least [after] days away.
create function pg_temp.thu(after int) returns date language sql stable as $$
  select pg_temp.today() + after + ((4 - extract(isodow from pg_temp.today() + after)::int + 7) % 7) $$;
create function pg_temp.u(i int) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid $$;
create function pg_temp.got(i int, t text) returns boolean language sql stable as $$
  select exists(select 1 from public.notifications where recipient_profile_id=pg_temp.u(i) and title=t) $$;
create function pg_temp.pay(i int) returns void language plpgsql security definer as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.u(i)::text, true);
  perform public.circle_action('join', '{"agree_to_pay":true}');
  perform set_config('request.jwt.claim.sub', pg_temp.u(8)::text, true);
  perform public.circle_action('admin_confirm_payment', jsonb_build_object('received', true,
    'id', (select id from public.circle_payments where profile_id = pg_temp.u(i) and status = 'awaiting_payment')));
end; $$;

insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.u(i),'pf'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,9) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'pf%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'pf%@example.test';
insert into public.circle_admins(profile_id) values(pg_temp.u(8));
create temp table plan as
select jsonb_agg(jsonb_build_object('title',t.title,'venue',coalesce(t.venue,''),'address',t.address,'cost',t.cost,
                                    'time',to_char(t.start_time,'HH24:MI'),'included',t.included) order by t.week) weeks
  from public.circle_programme_template t where t.city='Alkmaar' and t.kind='evening';
create temp table first_try as select pg_temp.thu(8) d;
grant select on plan, first_try to authenticated;
grant execute on function pg_temp.u(int), pg_temp.pay(int), pg_temp.today(), pg_temp.thu(int) to authenticated;

set local role authenticated;
do $$ declare i int; begin
 for i in 1..9 loop
  continue when i = 8;
  perform set_config('request.jwt.claim.sub', pg_temp.u(i)::text, true);
  perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'gender',case when i % 2 = 0 then 'woman' else 'man' end));
 end loop;
end $$;
select set_config('request.jwt.claim.sub', pg_temp.u(8)::text, true);
select public.circle_action('admin_create',jsonb_build_object('members',jsonb_build_array(pg_temp.u(1),pg_temp.u(2),pg_temp.u(3),pg_temp.u(4),pg_temp.u(5),pg_temp.u(6)),
  'name','Thursday Circle','schedule','Thursday evenings','start_date',(select d from first_try)::text,'time','19:00','weeks',(select weeks from plan)));
reset role;
create temp table ids as select id cid from public.circles where name='Thursday Circle';
grant select on ids to authenticated;

-- 1. Found, not started: seats, not people.
select pg_temp.assert_true((select pay_first and started_at is null and status='offered' from public.circles where id=(select cid from ids)),'a new Circle pays first and has not started');
select pg_temp.assert_true(pg_temp.got(1,'We’ve found people for your times') and not pg_temp.got(1,'You’re invited to a Circle'),'the invitation says people were found, not "meet your group"');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
create temp table s1 as select public.circle_snapshot() s;
select pg_temp.assert_true((select s->>'stage' from s1)='invited','invited');
select pg_temp.assert_true((select jsonb_array_length(s->'members') from s1)=0,'no names or photos before paying');
select pg_temp.assert_true((select not (s->'circle' ? 'start_date') from s1),'no start date yet');
select pg_temp.assert_true((select count(*)=6 and bool_and(not (m ? 'date') and not (m ? 'venue') and m ? 'title' and m ? 'included')
                             from s1, jsonb_array_elements(s->'meetups') m),'the six weeks, without dates or places');
select pg_temp.assert_true((select s->'pay_first'->>'found' from s1)='6' and (select s->'pay_first'->>'confirmed' from s1)='0','six seats found, none confirmed');
select pg_temp.assert_true((select (s->>'pay_by')::date from s1)=pg_temp.today()+7,'seven days to pay');

-- 2. Five pay: confirmed, still no group or chat; the organiser can start.
select pg_temp.pay(i) from generate_series(1,5) i;
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='confirmed','paid: confirmed, waiting for the start');
select pg_temp.assert_true(public.circle_snapshot()->'pay_first'->>'confirmed'='5','five of six confirmed');
select pg_temp.assert_true(jsonb_array_length(public.circle_snapshot()->'members')=0 and jsonb_array_length(public.circle_snapshot()->'messages')=0,'still no names or chat');
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('message','{"body":"Hi!"}')$q$)='Your group chat opens once your group is booked.','the chat opens at the start');
reset role;
select pg_temp.assert_true((select status from public.circles where id=(select cid from ids))='offered','paying does not start the Circle');
select pg_temp.assert_true((select body from public.notifications where recipient_profile_id=pg_temp.u(1) and title='You’re in! Your place is confirmed')
  ='We’ve received your €39, so your place is confirmed. We’ll tell you the dates and introduce your group as soon as it’s booked.','confirmed, without "say hello to your group"');
select pg_temp.assert_true((select count(*) from public.notifications where title='A group is ready to start')=1,'the organiser hears once that the group can start');
select public.queue_meetup_housekeeping();
select pg_temp.assert_true(not exists(select 1 from public.notifications where title in ('A week to book','A meetup has no place yet')),'no booking alerts for placeholder dates');

-- 3. Member 6 doesn't pay within 7 days: the seat opens.
update public.circle_memberships set created_at=now()-interval '8 days' where profile_id=pg_temp.u(6);
select public.queue_pay_by_reminders(); select public.queue_pay_by_reminders();
select pg_temp.assert_true(pg_temp.got(6,'Your seat is open again'),'they hear their seat is open');
select pg_temp.assert_true((select body from public.notifications where recipient_profile_id=pg_temp.u(6) and title='Your seat is open again') not like '%refund%','without pointing at refunds');
select pg_temp.assert_true((select status from public.circle_applications where profile_id=pg_temp.u(6))='waiting','and are back on the waiting list');
select pg_temp.assert_true(pg_temp.got(8,'A seat is open'),'the organiser hears the seat is open');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(6)::text, true);
select pg_temp.assert_true((public.circle_snapshot()->'pay_first'->>'expired')::boolean,'their invitation shows as expired');
-- The organiser gives the seat to member 7.
select set_config('request.jwt.claim.sub', pg_temp.u(8)::text, true);
select pg_temp.assert_true(pg_temp.error($q$select public.circle_admin_invite((select cid from ids), pg_temp.u(7))$q$) is null,'the open seat can be offered again');
reset role;
select pg_temp.assert_true(pg_temp.got(7,'We’ve found people for your times'),'the new invitation says the same');

-- 4. Member 6 pays late anyway: member 7 is within their 7 days, so 6 gets a credit.
set local role authenticated;
select pg_temp.pay(6);
reset role;
select pg_temp.assert_true((select status from public.circle_memberships where profile_id=pg_temp.u(6))='left','a late payment with no free seat does not join');
select pg_temp.assert_true(exists(select 1 from public.circle_moves where profile_id=pg_temp.u(6) and outcome is null and payment_id is not null),'it becomes a credit for their next group');
select pg_temp.assert_true(pg_temp.got(6,'Your €39 has arrived'),'and they are told so');
select pg_temp.assert_true((select status from public.circle_applications where profile_id=pg_temp.u(6))='waiting','still on the waiting list');
set local role authenticated;
select pg_temp.pay(7);
reset role;
select pg_temp.assert_true((select count(*) from public.circle_memberships where circle_id=(select cid from ids) and status='joined')=6,'six paid');

-- 5. The placeholder dates move on a week at a time.
update public.events set starts_at=((starts_at at time zone 'Europe/Amsterdam')-make_interval(days=>((select d from first_try)-pg_temp.thu(1)))) at time zone 'Europe/Amsterdam',
                         ends_at=((ends_at at time zone 'Europe/Amsterdam')-make_interval(days=>((select d from first_try)-pg_temp.thu(1)))) at time zone 'Europe/Amsterdam'
 where circle_id=(select cid from ids);
update public.circles set start_date=pg_temp.thu(1) where id=(select cid from ids);
select public.queue_pay_by_reminders();
select pg_temp.assert_true((select start_date>=pg_temp.today()+4 and extract(isodow from start_date)=4 from public.circles where id=(select cid from ids)),'a placeholder start never comes within 3 days');
select pg_temp.assert_true((select (starts_at at time zone 'Europe/Amsterdam')::date from public.events where circle_id=(select cid from ids) and circle_week=1)=(select start_date from public.circles where id=(select cid from ids)),'and the weeks move with it');

-- 6. Starting.
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(8)::text, true);
select pg_temp.assert_true(pg_temp.error(format('select public.circle_action(''admin_start'',%L)',jsonb_build_object('id',(select cid from ids),'start_date',pg_temp.today()+1)))
  like 'Choose a first meetup at least 3 days%','at least 3 days'' notice');
select pg_temp.assert_true(pg_temp.error(format('select public.circle_action(''admin_start'',%L)',jsonb_build_object('id',(select cid from ids),'start_date',pg_temp.thu(10)+1)))
  ='Keep the group’s own weekday: everyone chose it.','on the group''s weekday');
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
select pg_temp.assert_true(pg_temp.error(format('select public.circle_action(''admin_start'',%L)',jsonb_build_object('id',(select cid from ids),'start_date',pg_temp.thu(10)))) is not null,'only organisers start a Circle');
select set_config('request.jwt.claim.sub', pg_temp.u(8)::text, true);
select public.circle_action('admin_start',jsonb_build_object('id',(select cid from ids),'start_date',pg_temp.thu(10)));
reset role;
select pg_temp.assert_true((select started_at is not null and status='active' and start_date=pg_temp.thu(10) from public.circles where id=(select cid from ids)),'started on the chosen date');
select pg_temp.assert_true((select string_agg(to_char(starts_at at time zone 'Europe/Amsterdam','YYYY-MM-DD HH24:MI'),',' order by circle_week) from public.events where circle_id=(select cid from ids) and circle_week is not null)
  =(select string_agg(to_char(pg_temp.thu(10)+7*(w-1),'YYYY-MM-DD')||' '||t,',' order by w) from unnest(array[1,2,3,4,5,6],array['20:00','20:00','19:00','20:00','20:00','20:00']) x(w,t)),'six weeks from the start, at their own times');
select pg_temp.assert_true((select count(*) from public.notifications where title='Your Circle is booked')=6,'every paid member hears the date');
select pg_temp.assert_true(exists(select 1 from public.messages where body like 'Welcome, everyone! Your six weeks start on %'),'and the chat opens with a welcome');
set local role authenticated;
select set_config('request.jwt.claim.sub', pg_temp.u(1)::text, true);
select pg_temp.assert_true(public.circle_snapshot()->>'stage'='active' and jsonb_array_length(public.circle_snapshot()->'members')=6,'now the group is visible');
select pg_temp.assert_true((select bool_and(m ? 'date') from jsonb_array_elements(public.circle_snapshot()->'meetups') m),'with dates');
select pg_temp.assert_true(pg_temp.error($q$select public.circle_action('cancel_agreement','{}')$q$) like 'Your group is booked, so your €39 can’t be returned any more.%','after the booking: no refund, the switch instead');
select pg_temp.assert_true(pg_temp.error(format('select public.circle_action(''admin_start'',%L)',jsonb_build_object('id',(select cid from ids),'start_date',pg_temp.thu(17)))) is not null,'a started Circle can''t start again');
reset role;

-- 7. Waiting two weeks: a calm word to the paid, no refund offer.
insert into public.circles(id,name,schedule,start_date,local_time) values('31000000-0000-0000-0000-000000000002','Slow Circle','Thursday evenings',pg_temp.thu(20),'19:00');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status) values('31000000-0000-0000-0000-000000000002',pg_temp.u(9),'joined','paid');
insert into public.circle_payments(profile_id,circle_id,status,received_at) values(pg_temp.u(9),'31000000-0000-0000-0000-000000000002','paid',now()-interval '15 days');
select pg_temp.assert_true(public.circle_refund_until('31000000-0000-0000-0000-000000000002')='infinity','before the start a refund can be asked for');
select public.queue_pay_by_reminders(); select public.queue_pay_by_reminders();
select pg_temp.assert_true((select count(*) from public.notifications where recipient_profile_id=pg_temp.u(9) and title='Your group needs a little longer')=1,'one calm word after two weeks');
select pg_temp.assert_true((select body from public.notifications where recipient_profile_id=pg_temp.u(9) and title='Your group needs a little longer') not like '%refund%'
  and (select body from public.notifications where recipient_profile_id=pg_temp.u(9) and title='Your group needs a little longer') not like '%money back%','without offering the money back');
select pg_temp.assert_true(pg_temp.got(8,'A group is waiting'),'the organiser hears it too');

-- 8. Old flow, for tests of it and for Circles made before.
select set_config('vriendtime.pay_first', 'off', false);
insert into public.circles(id,name,schedule,start_date,local_time) values('31000000-0000-0000-0000-000000000003','Old Circle','Thursday evenings',pg_temp.thu(20),'19:00');
select pg_temp.assert_true((select not pay_first and started_at is not null from public.circles where id='31000000-0000-0000-0000-000000000003'),'the old flow counts as started');
rollback;
