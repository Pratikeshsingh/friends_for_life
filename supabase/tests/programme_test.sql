-- Six-week plan at creation, saved suggestions, quiet plan saves, chat reading, gender.
begin;
-- The old flow (meet the group, then pay); pay-first has its own test.
select set_config('vriendtime.pay_first', 'off', false);
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email,raw_user_meta_data)
select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'test'||i||'@example.test',jsonb_build_object('first_name','Member '||i) from generate_series(1,8) i;
insert into storage.objects(bucket_id,name) select 'profile-photos',id::text||'/profile.jpg' from auth.users where email like 'test%@example.test';
update public.profiles set profile_photo_path=id::text||'/profile.jpg' where email like 'test%@example.test';
insert into public.circle_admins(profile_id) values('00000000-0000-0000-0000-000000000008');
set local role authenticated;
do $$ declare i int; begin
 for i in 1..6 loop
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-'||lpad(i::text,12,'0'),true);
 perform public.circle_action('apply',jsonb_build_object('name','Member '||i,'city','Alkmaar','date_of_birth','1995-06-15','languages',jsonb_build_array('English'),'availability_slots','{"thu":["evening"]}'::jsonb,'interests',jsonb_build_array('Coffee'),'activities',jsonb_build_array('Coffee & conversation'),'goals',jsonb_build_array('Local friends'),'life_context','[]'::jsonb,'energy',2,'commitment',true,'gender',case when i<=3 then 'woman' else 'man' end,'other_times','Mondays after 22:00','phone','+3161234567'||i));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->'application'->>'gender'='woman','gender is stored');
select pg_temp.assert_true(public.circle_snapshot()->'application'->>'other_times'='Mondays after 22:00','other times are stored');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('draft',(public.circle_snapshot()->'application')||'{"gender":"robot"}')$q$),'unknown gender refused');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
-- A plan with a missing place is refused; a full plan sets every week.
select pg_temp.assert_true(pg_temp.refused(format('select public.circle_action(%L,%L::jsonb)','admin_create',('{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Thursday Circle","schedule":"Thursday evenings","start_date":"2027-10-07","time":"19:30"}'::jsonb)||'{"weeks":[{"title":"Dinner","venue":""}]}')),'all six weeks need a place');
select public.circle_action('admin_create',('{"members":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002","00000000-0000-0000-0000-000000000003","00000000-0000-0000-0000-000000000004","00000000-0000-0000-0000-000000000005","00000000-0000-0000-0000-000000000006"],"name":"Thursday Circle","schedule":"Thursday evenings","start_date":"2027-10-07","time":"19:30"}'::jsonb)||jsonb_build_object('weeks',(select jsonb_agg(jsonb_build_object('title','Plan '||i,'venue','Place '||i,'address','Street '||i,'cost','€'||i)) from generate_series(1,6) i)));
reset role;
select pg_temp.assert_true((select string_agg(title||'@'||venue_name,',' order by circle_week) from public.events)='Plan 1@Place 1,Plan 2@Place 2,Plan 3@Place 3,Plan 4@Place 4,Plan 5@Place 5,Plan 6@Place 6','all six weeks planned');
select pg_temp.assert_true((select string_agg(cost_notes,',' order by circle_week) from public.events)='€1,€2,€3,€4,€5,€6','costs saved with the plan');
select pg_temp.assert_true((select bool_and(to_char(ends_at at time zone 'Europe/Amsterdam','HH24:MI')='22:00') from public.events),'evening meetups run until 22:00');
create temp table ids as select (select id from public.events where circle_week=2) ev, (select id from public.circles) cid;
grant select on ids to authenticated;
-- Members see the place straight away, from the invitation on.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(public.circle_snapshot()->'meetups'->0->>'venue'='Place 1','place visible on the invitation');
-- Saving a plan quietly sends no update.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_schedule',jsonb_build_object('id',(select ev from ids),'title','Plan 2b','venue','Place 2','date',current_date+30,'time','19:00','notify',false));
reset role;
select pg_temp.assert_true(not exists(select 1 from public.notifications where title='Your Circle plan changed'),'no email when notify is false');
select pg_temp.assert_true((select to_char(ends_at at time zone 'Europe/Amsterdam','YYYY-MM-DD HH24:MI') from public.events where id=(select ev from ids))=to_char(current_date+30,'YYYY-MM-DD')||' 22:00','a moved week still ends at 22:00');
-- Saved suggestions, meeting point, chat reading.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_action('admin_template',jsonb_build_object('kind','evening','weeks',jsonb_build_array(jsonb_build_object('week',1,'title','Dinner','venue','Rozey Alkmaar','cost','About €40'))));
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'programme') x where x->>'kind'='evening' and x->>'week'='1' and x->>'cost'='About €40'),'cost saved with the suggestion');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'programme') x where x->>'city'='Alkmaar' and x->>'week'='1'),'suggestions are stored per city');
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'programme') x where x->>'kind'='evening' and x->>'week'='1' and x->>'venue'='Rozey Alkmaar'),'suggestion saved');
select public.circle_action('admin_template',jsonb_build_object('kind','morning','weeks',jsonb_build_array(jsonb_build_object('week',2,'title','Coffee','venue','Kaldi','cost','You pay for yourself.'))));
select pg_temp.assert_true(exists(select 1 from jsonb_array_elements(public.circle_admin_snapshot()->'programme') x where x->>'kind'='morning' and x->>'week'='2' and x->>'title'='Coffee'),'morning suggestions can be saved');
select pg_temp.assert_true(jsonb_typeof(public.circle_admin_messages((select cid from ids)))='array','organiser can read the chat');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_admin_messages((select cid from ids))$q$),'members cannot use the organiser chat view');
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_action('admin_template','{"kind":"evening"}')$q$),'members cannot change suggestions');
rollback;
