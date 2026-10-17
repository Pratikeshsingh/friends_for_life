-- Meetups as time windows, and the morning, afternoon and evening plans.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.ends(t time) returns text language sql stable as $$
  select to_char(public.circle_window_end((date '2027-03-03' + t) at time zone 'Europe/Amsterdam') at time zone 'Europe/Amsterdam', 'HH24:MI') $$;

-- 1. Each part of the day has its end.
select pg_temp.assert_true(pg_temp.ends('10:30')='12:00','morning: 10:30–12:00');
select pg_temp.assert_true(pg_temp.ends('14:00')='16:00','afternoon: 14:00–16:00');
select pg_temp.assert_true(pg_temp.ends('19:00')='22:00','evening: 19:00–22:00');
select pg_temp.assert_true(pg_temp.ends('11:00')='12:30','never shorter than an hour and a half');
select pg_temp.assert_true(pg_temp.ends('21:30')='23:00','a late start keeps its hour and a half');
-- Summer time: still 22:00 on the clock.
select pg_temp.assert_true(to_char(public.circle_window_end(timestamptz '2027-07-07 19:00 Europe/Amsterdam') at time zone 'Europe/Amsterdam','HH24:MI')='22:00','22:00 in summer too');

-- 2. Morning and afternoon plans exist next to evening ones (their content
--    is set by 20261035 and checked in six_weeks_test); the old daytime plan stays.
select pg_temp.assert_true((select count(*) from public.circle_programme_template where city='Alkmaar' and kind in ('morning','afternoon'))=12,'two full plans');
select pg_temp.assert_true(exists(select 1 from public.circle_programme_template where kind='daytime'),'the daytime plan stays for the older app');
select pg_temp.assert_true(not exists(select 1 from public.circle_programme_template where venue='Kaldi' and address is distinct from 'Marktstraat 13'),'Kaldi has its address');
rollback;
