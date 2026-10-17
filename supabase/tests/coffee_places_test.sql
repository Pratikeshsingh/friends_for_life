-- Coffee places: opening hours, map links, Alkmaar's list, and the organiser's editor.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.p(i int) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid $$;
-- A wall-clock time in Alkmaar, as an instant.
create function pg_temp.ams(d date, t time) returns timestamptz language sql stable as $$ select (d + t) at time zone 'Europe/Amsterdam' $$;
-- Next week, Monday to Sunday.
create temp table w as select current_date + (8 - extract(isodow from current_date)::int) mon;
create function pg_temp.wk(n int) returns date language sql stable as $$ select mon + n from w $$;
create function pg_temp.hours(place text) returns jsonb language sql stable as $$ select opening_hours from public.circle_coffee_places where city='Alkmaar' and name=place limit 1 $$;

-- 1. Alkmaar's list.
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Alkmaar' and kind='daytime')=7,'seven daytime cafés');
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Alkmaar' and kind='evening')=7,'seven evening places');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffee_places where name='Mr. Gold'),'Mr. Gold is off the list');
select pg_temp.assert_true((select string_agg(kind,',') from public.circle_coffee_places where name='Echt Alkmaar')='daytime','Echt Alkmaar is a daytime café now');
select pg_temp.assert_true((select string_agg(kind,',') from public.circle_coffee_places where name='Het Alkmaars Koffiehuis')='evening','the Koffiehuis is for an evening drink now');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffee_places where city='Alkmaar' and opening_hours is null),'every place has its hours (checked 13 Oct 2026)');
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Alkmaar' and hours_checked_at='2026-10-13')=14,'all fourteen checked');
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Alkmaar' and maps_url like 'https://www.google.com/maps/search/?api=1&query=%')=14,'every place has a map link');
select pg_temp.assert_true(position('Anne%26Max%2C' in (select maps_url from public.circle_coffee_places where name='Anne&Max'))>0,'an & in a name is encoded');
select pg_temp.assert_true(pg_temp.hours('Miss Central')->'mon'='[]'::jsonb,'Miss Central is closed on Monday');
select pg_temp.assert_true(pg_temp.hours('Kaldi')->'mon'->0->>'open'='13:00','Kaldi opens at 13:00 on Monday');

-- 2. Open for the whole hour?
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Kaldi'),pg_temp.ams(pg_temp.wk(1),'10:30')),'Kaldi on Tuesday at 10:30: open');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Kaldi'),pg_temp.ams(pg_temp.wk(0),'10:30'))=false,'Kaldi on Monday at 10:30: not open yet');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Miss Central'),pg_temp.ams(pg_temp.wk(0),'14:00'))=false,'closed all Monday');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Kaatje''s Bakery'),pg_temp.ams(pg_temp.wk(6),'14:00')),'14:00 to 15:00 fits before a 16:00 close');
select pg_temp.assert_true(public.circle_place_open('{"sun":[{"open":"10:00","close":"14:30"}]}',pg_temp.ams(pg_temp.wk(6),'14:00'))=false,'closing within the hour is too early');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Het Alkmaars Koffiehuis'),pg_temp.ams(pg_temp.wk(2),'20:00')),'open until midnight');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Het Alkmaars Koffiehuis'),pg_temp.ams(pg_temp.wk(4),'20:00')),'open until two at night');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Het Alkmaars Koffiehuis'),pg_temp.ams(pg_temp.wk(1),'20:00'))=false,'closed on Tuesday');
select pg_temp.assert_true(public.circle_place_open('{"wed":[{"open":"09:00","close":"12:00"},{"open":"17:00","close":"23:00"}]}',pg_temp.ams(pg_temp.wk(2),'20:00')),'a second opening later in the day');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Soepp'),pg_temp.ams(pg_temp.wk(3),'20:00')),'Soepp: Thursday evening, open');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Soepp'),pg_temp.ams(pg_temp.wk(2),'20:00'))=false,'Soepp: Wednesday it closes at 16:00');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Soepp'),pg_temp.ams(pg_temp.wk(1),'10:30')),'Soepp: Tuesday morning, open');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('1480 Foodbar'),pg_temp.ams(pg_temp.wk(2),'20:00')),'1480 Foodbar: Wednesday evening, open');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Grand Café Klunder'),pg_temp.ams(pg_temp.wk(2),'20:00')),'Klunder: Wednesday until 22:00');
select pg_temp.assert_true(public.circle_place_open(pg_temp.hours('Grand Café Klunder'),pg_temp.ams(pg_temp.wk(0),'20:00'))=false,'Klunder: Monday it may close at 18:00');
select pg_temp.assert_true(pg_temp.hours('Anne&Max')->'sat'->0->>'close'='18:00','Anne&Max: Saturday until 18:00');
select pg_temp.assert_true(public.circle_place_open(null,pg_temp.ams(pg_temp.wk(2),'20:00')) is null,'no hours: unknown');
select pg_temp.assert_true(public.circle_place_open('{"wed":null}',pg_temp.ams(pg_temp.wk(2),'20:00')) is null,'a day without hours: unknown');
select pg_temp.assert_true(public.circle_place_open('{"tue":[]}',pg_temp.ams(pg_temp.wk(2),'20:00')) is null,'a day that is not listed: unknown');
select pg_temp.assert_true(public.circle_place_open('{"wed":[{"open":"9","close":"17"}]}',pg_temp.ams(pg_temp.wk(2),'10:30')) is null,'a typo is unknown, never an error');

-- 3. Suggestions, in a test town with cafés of its own.
insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.p(i),'cp'||i||'@example.test',jsonb_build_object('first_name','C'||i) from generate_series(1,3) i;
insert into public.circle_applications(profile_id,answers,status)
select pg_temp.p(i),'{"gender":"woman","availability_slots":{"tue":["morning"],"wed":["morning"]}}'::jsonb,'joined' from generate_series(1,2) i;
insert into public.circle_admins values(pg_temp.p(3));
insert into public.circles(id,name,schedule,start_date,local_time,status,city) values('30000000-0000-0000-0000-00000000000c','Circle C','Weekly',current_date,'19:30','active','Testdorp');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '30000000-0000-0000-0000-00000000000c',pg_temp.p(i),'joined','paid' from generate_series(1,2) i;
insert into public.circle_coffee_places(city,kind,name,address,sort,opening_hours,maps_url) values
 ('Testdorp','daytime','Early Bird','Dorp 1',1,'{"mon":[{"open":"07:00","close":"10:00"}],"tue":[{"open":"07:00","close":"10:00"}],"wed":[{"open":"07:00","close":"10:00"}],"thu":[],"fri":[],"sat":[],"sun":[]}','https://example.test/early'),
 ('Testdorp','daytime','Sunny','Plein 1',2,'{"mon":[],"tue":[],"wed":[{"open":"09:00","close":"18:00"}],"thu":[],"fri":[],"sat":[],"sun":[]}','https://example.test/sunny');
create function pg_temp.slot() returns timestamptz language sql stable as $$
  select public.circle_coffee_slot('30000000-0000-0000-0000-00000000000c',pg_temp.p(1),pg_temp.p(2),pg_temp.wk(0),pg_temp.wk(6)) $$;
-- Tuesday 10:30: Early Bird has just closed and Sunny is shut, so Wednesday.
select pg_temp.assert_true(pg_temp.slot()=pg_temp.ams(pg_temp.wk(2),'10:30'),'a time when every place is closed is skipped');
-- A café whose hours we don't know keeps Tuesday possible, and gets it.
insert into public.circle_coffee_places(city,kind,name,address,sort,maps_url) values('Testdorp','daytime','Mystery','Steeg 2',3,'https://example.test/mystery');
select pg_temp.assert_true(pg_temp.slot()=pg_temp.ams(pg_temp.wk(1),'10:30'),'unknown hours keep a time possible');
select public.circle_coffee_ask('30000000-0000-0000-0000-00000000000c',1,pg_temp.p(1),pg_temp.p(2),pg_temp.wk(0),pg_temp.wk(6));
select pg_temp.assert_true((select place from public.circle_coffees where round=1 and circle_id='30000000-0000-0000-0000-00000000000c')='Mystery','unknown hours only when nothing known is open');
-- Wednesday: Sunny is open. It wins even though the Circle has been there more often.
insert into public.circle_coffees(circle_id,round,a,b,starts_at,place,status)
select '30000000-0000-0000-0000-00000000000c',3,pg_temp.p(1),pg_temp.p(2),now()-interval '30 days','Sunny','confirmed' from generate_series(1,2);
select public.circle_coffee_ask('30000000-0000-0000-0000-00000000000c',2,pg_temp.p(1),pg_temp.p(2),pg_temp.wk(2),pg_temp.wk(2));
select pg_temp.assert_true((select place from public.circle_coffees where round=2 and circle_id='30000000-0000-0000-0000-00000000000c')='Sunny','a place known to be open comes first');
select pg_temp.assert_true((select maps_url from public.circle_coffees where round=2 and circle_id='30000000-0000-0000-0000-00000000000c')='https://example.test/sunny','the map link goes with the coffee');

-- 4. The member sees the link; the organiser sees hours and links.
update public.circle_coffees set status='off' where round=1 and circle_id='30000000-0000-0000-0000-00000000000c';
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.p(1)::text,true);
select pg_temp.assert_true(public.circle_snapshot()->'coffees'->'current'->>'maps_url'='https://example.test/sunny','the coffee card gets the map link');
select set_config('request.jwt.claim.sub',pg_temp.p(3)::text,true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'coffee_places') x
                                   where x->>'name'='Sunny' and x->'opening_hours' ? 'wed' and x->>'maps_url'='https://example.test/sunny'),'the organiser sees hours and links');
-- 5. Saving the list keeps a place's hours, and its link while the address stays.
select public.circle_action('admin_coffee_places',jsonb_build_object('city','Testdorp','kind','daytime','places',jsonb_build_array(
  jsonb_build_object('name','Sunny','address','Plein 1'),
  jsonb_build_object('name','mystery','address','Andere Steeg 9'),
  jsonb_build_object('name','New Place','address',''))));
reset role;
select pg_temp.assert_true((select opening_hours->'wed'->0->>'close' from public.circle_coffee_places where city='Testdorp' and name='Sunny')='18:00','hours kept');
select pg_temp.assert_true((select maps_url from public.circle_coffee_places where city='Testdorp' and name='Sunny')='https://example.test/sunny','the link stays while the address is the same');
select pg_temp.assert_true((select maps_url is null from public.circle_coffee_places where city='Testdorp' and name='mystery'),'a new address drops the old link');
select pg_temp.assert_true((select opening_hours is null and maps_url is null from public.circle_coffee_places where city='Testdorp' and name='New Place'),'a new place starts without hours or link');
select pg_temp.assert_true(not exists(select 1 from public.circle_coffee_places where city='Testdorp' and name='Early Bird'),'a place taken off the list is gone');
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Alkmaar')=14,'other towns are untouched');
-- The map link must be a web link.
select pg_temp.assert_true((select count(*) from public.circle_coffee_places where city='Testdorp')=3,'three places now');
do $$ begin
  update public.circle_coffee_places set maps_url='javascript:alert(1)' where name='Sunny';
  raise exception 'ASSERTION FAILED: a non-https link was accepted';
exception when check_violation then null;
end $$;
rollback;
