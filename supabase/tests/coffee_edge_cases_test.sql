-- One-to-one coffees when people leave, block each other, or delete their account.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'ce'||i||'@example.test',jsonb_build_object('first_name','P'||i) from generate_series(1,4) i;
update public.profiles set first_name='P'||right(id::text,1) where email like 'ce%@example.test';
insert into public.circle_applications(profile_id,answers,status)
select id,'{"availability_slots":{"tue":["morning"],"wed":["morning","evening"],"thu":["morning","evening"],"fri":["afternoon","evening"],"sat":["afternoon","evening"],"sun":["afternoon","evening"]}}'::jsonb,'joined'
  from public.profiles where email like 'ce%@example.test';
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-00000000000c','Circle C','Weekly',current_date-8,'19:30','active');
insert into public.circle_memberships(circle_id,profile_id,status,payment_status)
select '10000000-0000-0000-0000-00000000000c',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'joined','paid' from generate_series(1,4) i;
insert into public.events(circle_id,circle_week,title,city,starts_at,ends_at,capacity,status,venue_name) values
 ('10000000-0000-0000-0000-00000000000c',2,'W2','Alkmaar',now()-interval '3 hours',now()-interval '1 hour',6,'open','Cafe'),
 ('10000000-0000-0000-0000-00000000000c',3,'W3','Alkmaar',now()+interval '7 days',now()+interval '7 days 2 hours',6,'open','Boules');
-- P1 asked not to be matched with P4 (round-robin round 1 pairs 1–4 and 2–3).
insert into public.circle_exclusions(profile_id,excluded_profile_id) values('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004');
select public.queue_circle_coffees();
select pg_temp.assert_true(not exists(select 1 from public.circle_coffees where '00000000-0000-0000-0000-000000000001' in (a,b) and '00000000-0000-0000-0000-000000000004' in (a,b)),'never paired after "don''t match again"');
select pg_temp.assert_true((select count(*) from public.circle_coffees)=1,'the other pair still meets');
-- P2 leaves the Circle: their coffee is off and P3 is told.
update public.circle_memberships_all set status='left' where profile_id='00000000-0000-0000-0000-000000000002';
select pg_temp.assert_true((select status from public.circle_coffees)='off','coffee called off when someone leaves');
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='P2 can’t make it after all'),'partner is told');
-- A new coffee between P1 and P3; "don't match again" calls it off quietly for the reason.
insert into public.circle_coffees(circle_id,round,a,b,starts_at,place,status) values('10000000-0000-0000-0000-00000000000c',1,'00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()+interval '2 days','Kaldi','confirmed');
insert into public.circle_exclusions(profile_id,excluded_profile_id) values('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001');
select pg_temp.assert_true((select status from public.circle_coffees where place='Kaldi')='off','exclusion calls off a planned coffee');
-- Account deletion tells the partner first.
insert into public.circle_coffees(circle_id,round,a,b,starts_at,place,status) values('10000000-0000-0000-0000-00000000000c',1,'00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004',now()+interval '3 days','Mr. Gold','asked');
delete from auth.users where id='00000000-0000-0000-0000-000000000004';
select pg_temp.assert_true(exists(select 1 from public.notifications where recipient_profile_id='00000000-0000-0000-0000-000000000003' and title='P4 can’t make it after all'),'partner told when an account is deleted');
-- A cancelled Circle calls off everything left.
insert into public.circle_coffees(circle_id,round,a,b,starts_at,place,status) values('10000000-0000-0000-0000-00000000000c',2,'00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()+interval '4 days','SOEPP','asked');
update public.circles set status='cancelled' where id='10000000-0000-0000-0000-00000000000c';
select pg_temp.assert_true((select status from public.circle_coffees where place='SOEPP')='off','cancelled Circle calls off coffees');
rollback;
