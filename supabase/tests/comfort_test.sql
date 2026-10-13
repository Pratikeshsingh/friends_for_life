-- Coffee reminder on the day, booking names, "would you go back?".
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'cf'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'cf%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'cf%@example.test';
update public.profiles set first_name='Anna' where id='00000000-0000-0000-0000-000000000002';
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000008');
set local role authenticated;
do $$ declare i int; begin
 for i in 1..6 loop
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'gender','woman','phone','+3161234567'||i));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
-- Without a plan: the saved suggestions fill in, booking name included.
select public.circle_action('admin_create','{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Thursday Circle","schedule":"Thursday evenings","start_date":"2027-10-07","time":"19:30"}'::jsonb);
reset role;
select pg_temp.assert_true((select booking_name from public.events where circle_week=1)='Thursday Circle','booking name defaults to the Circle''s name');
create temp table ids as select (select id from public.events where circle_week=1) ev;
grant select on ids to authenticated;
-- The organiser changes it for one week; members see it.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_schedule',jsonb_build_object('id',(select ev from ids),'title','Dinner together','venue','Rozey Alkmaar','date','2027-10-07','time','19:00','booking','Olivia','notify',false));
select pg_temp.assert_true(public.circle_admin_snapshot()->'circles'->0->'meetups'->0->>'booking_name'='Olivia','organiser sees it');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_snapshot()->'meetups') m where m->>'booking_name'='Olivia'),'member sees the booking name');
reset role;
-- "Would you go back?" is stored with the check-in and counted for the organiser.
update public.circle_memberships_all set status='joined', payment_status='paid';
update public.circles set status='active';
update public.events set starts_at=now()-interval '3 hours', ends_at=now()-interval '1 hour' where id=(select ev from ids);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('check_in',jsonb_build_object('id',(select ev from ids),'feeling','🙂 Good','connections','[]'::jsonb,'place_feeling','😊 Great'));
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true((public.circle_admin_snapshot()->'circles'->0->'meetups'->0->'place_feelings'->>'😊 Great')::int=1,'place tally');
reset role;
-- Coffee reminder: only at 08:00 Netherlands time, once.
insert into public.circle_coffees(circle_id,round,a,b,starts_at,place,status)
select (select id from public.circles),1,'00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',
       ((now() at time zone 'Europe/Amsterdam')::date + time '23:30') at time zone 'Europe/Amsterdam','Mr. Gold','confirmed';
select public.queue_coffee_reminders();
select pg_temp.assert_true(
  case when extract(hour from now() at time zone 'Europe/Amsterdam')=8
       then (select count(*) from public.notifications where dedupe_key like 'coffee-today:%')=2
       else not exists(select 1 from public.notifications where dedupe_key like 'coffee-today:%') end,'reminder only at 08:00');
select public.queue_coffee_reminders(true);
select public.queue_coffee_reminders(true);
select pg_temp.assert_true((select count(*) from public.notifications where dedupe_key like 'coffee-today:%')=2,'one reminder each, once');
select pg_temp.assert_true((select body from public.notifications where dedupe_key like 'coffee-today:%' and recipient_profile_id='00000000-0000-0000-0000-000000000001')='23:30 at Mr. Gold. Running late? Let them know in the app.','reminder says when and where');
select pg_temp.assert_true(exists(select 1 from public.notifications where title='Coffee with Member 2 today'),'names the other person');
-- Running late: one tap posts in the group chat (in the member's language) and tells the coffee partner.
update public.profiles set language='nl' where id='00000000-0000-0000-0000-000000000001';
update public.circle_coffees set starts_at=now()+interval '30 minutes';
create temp table cof as select id from public.circle_coffees;
grant select on cof to authenticated;
update public.events set starts_at=now()+interval '1 hour', ends_at=now()+interval '3 hours' where id=(select ev from ids);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_action('running_late',jsonb_build_object('kind','coffee','id',(select id from cof),'minutes',10));
select pg_temp.assert_true((public.circle_snapshot()->'messages'->-1->>'body')='Ik ben ongeveer 10 minuten later voor onze koffie, Member 2.','chat message in the member''s language');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select public.circle_action('running_late',jsonb_build_object('kind','meetup','id',(select ev from ids),'minutes',15));
select pg_temp.assert_true((public.circle_snapshot()->'messages'->-1->>'body')='Running about 15 minutes late.','group meetup message');
select pg_temp.assert_true((select count(*) from jsonb_array_elements(public.circle_snapshot()->'coffees'->'rounds'))=0,'no rounds yet');
reset role;
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000002' and title='Member 1 is running late' and body like 'About 10 minutes.%'),'coffee partner told');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
create function pg_temp.refused(sql text) returns boolean language plpgsql as $f$ begin execute sql; return false; exception when others then return true; end; $f$;
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('running_late',jsonb_build_object('kind','coffee','id',(select id from cof),'minutes',30))$q$),'only once');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('running_late',jsonb_build_object('kind','coffee','id',(select id from cof),'minutes',10))$q$),'only the two people of the coffee');
reset role;
rollback;
