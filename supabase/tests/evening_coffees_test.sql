-- Evening one-to-ones: daytime first unless both are men or both are women,
-- a friendly line on evening invitations, and no nudge after an evening "no".
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.p(i int) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid $$;
insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.p(i),'ev'||i||'@example.test',jsonb_build_object('first_name','E'||i) from generate_series(1,6) i;
-- 1 a man, 2 a woman, 3 a man, 4 a woman free only on Wednesday evening,
-- 5 non-binary, 6 gave no answer. The others: Wednesday evening, Saturday afternoon.
insert into public.circle_applications(profile_id,answers,status)
select pg_temp.p(i),
       jsonb_build_object('availability_slots',
                          case when i=4 then '{"wed":["evening"]}'::jsonb
                               else '{"wed":["evening"],"sat":["afternoon"]}'::jsonb end,
                          'gender',(array['man','woman','man','woman','non_binary',null])[i]),
       'joined'
  from generate_series(1,6) i;
insert into public.circles(id,name,schedule,start_date,local_time,status) values('20000000-0000-0000-0000-00000000000e','Circle E','Weekly',current_date,'19:30','active');
-- Next week, Monday to Sunday: Wednesday evening comes before Saturday afternoon.
create temp table w as select current_date + (8 - extract(isodow from current_date)::int) mon;
create function pg_temp.slot(x int, y int) returns timestamp language sql as $$
  select public.circle_coffee_slot('20000000-0000-0000-0000-00000000000e', pg_temp.p(x), pg_temp.p(y),
                                   (select mon from w), (select mon + 6 from w)) at time zone 'Europe/Amsterdam' $$;

select pg_temp.assert_true(pg_temp.slot(1,2)=(select mon+5 from w)+time '14:00','a man and a woman: the shared daytime, not the earlier evening');
select pg_temp.assert_true(pg_temp.slot(1,3)=(select mon+2 from w)+time '20:00','two men: the first time both are free');
select pg_temp.assert_true(pg_temp.slot(2,4)=(select mon+2 from w)+time '20:00','two women: the first time both are free');
select pg_temp.assert_true(pg_temp.slot(1,4)=(select mon+2 from w)+time '20:00','no shared daytime: the evening is still suggested');
select pg_temp.assert_true(pg_temp.slot(1,5)=(select mon+5 from w)+time '14:00','non-binary: daytime first');
select pg_temp.assert_true(pg_temp.slot(1,6)=(select mon+5 from w)+time '14:00','no answer: daytime first');

-- The invitations: the evening one says it is as friends, the daytime one is unchanged.
select public.circle_coffee_ask('20000000-0000-0000-0000-00000000000e',1,pg_temp.p(1),pg_temp.p(4),(select mon from w),(select mon+6 from w));
select public.circle_coffee_ask('20000000-0000-0000-0000-00000000000e',1,pg_temp.p(3),pg_temp.p(2),(select mon from w),(select mon+6 from w));
select pg_temp.assert_true((select count(*) from public.notifications where body like '%. A drink in the evening, just as friends: whatever you like to drink. Can you make it? Answer in the app. Not for you? No reason needed.')=2,'the evening invitation: a drink as friends, no reason needed');
select pg_temp.assert_true((select count(*) from public.notifications where body like '%. Coffee or a drink, just the two of you. Can you make it? Answer in the app.')=2,'the daytime invitation is unchanged');
select pg_temp.assert_true((select pl.kind from public.circle_coffees k join public.circle_coffee_places pl on pl.name=k.place where k.a=pg_temp.p(1))='evening','an evening place for the evening');
select pg_temp.assert_true((select pl.kind from public.circle_coffees k join public.circle_coffee_places pl on pl.name=k.place where k.a=pg_temp.p(3))='daytime','a café for the daytime');

-- Both get a "yes" and a "no": only the daytime "no" is nudged.
update public.circle_coffees set a_answer='yes', b_answer='no', answered_at=now()-interval '13 hours';
select public.queue_circle_coffees();
select public.queue_circle_coffees();
select pg_temp.assert_true((select count(*) from public.notifications where title like '% would love to meet')=1,'one nudge, for the daytime coffee');
select pg_temp.assert_true((select dedupe_key from public.notifications where title like '% would love to meet')='coffee-nudge:'||(select id from public.circle_coffees where a=pg_temp.p(3)),'the evening "no" stands');
select pg_temp.assert_true((select not nudged from public.circle_coffees where a=pg_temp.p(1)),'the evening coffee is never nudged');
-- On the day: an evening one is a drink tonight, not a coffee (20261038).
update public.circle_coffees set status='confirmed',
  starts_at=greatest(now()+interval '1 minute', ((now() at time zone 'Europe/Amsterdam')::date + time '20:00') at time zone 'Europe/Amsterdam')
 where a=pg_temp.p(1);
delete from public.notifications;
select public.queue_coffee_reminders(true);
select pg_temp.assert_true((select count(*) from public.notifications where title like 'A drink with % tonight')=2,'the evening reminder: a drink tonight');
select pg_temp.assert_true(not exists(select 1 from public.notifications where title like 'Coffee with %'),'never coffee in the evening');
-- The pairing keeps its edge-case checks from 20261024.
select pg_temp.assert_true(position('circle_coffee_blocked' in pg_get_functiondef('public.queue_circle_coffees()'::regprocedure))>0,'blocked pairs are still skipped');
rollback;
