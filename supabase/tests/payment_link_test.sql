-- Per-Circle payment link and the "tapped Pay" time. Rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
create function pg_temp.refused(sql text) returns boolean language plpgsql as $$ begin execute sql; return false; exception when others then return true; end; $$;
insert into auth.users(id,email) select ('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'pay'||i||'@example.test' from generate_series(1,3) i;
insert into auth.users(id,email) values('00000000-0000-0000-0000-000000000008','organiser@example.test');
insert into public.circle_admins values('00000000-0000-0000-0000-000000000008');
insert into public.circles(id,name,schedule,start_date,local_time,status) values('10000000-0000-0000-0000-000000000001','C','Monday',current_date+10,'19:00','offered');
insert into public.circle_memberships(circle_id,profile_id,status) select '10000000-0000-0000-0000-000000000001',('00000000-0000-0000-0000-'||lpad(i::text,12,'0'))::uuid,'invited' from generate_series(1,2) i;
insert into public.circle_payments(profile_id,circle_id) values('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001');
set local role authenticated;
-- Only organisers set the link, and it must be a full https link.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_set_payment_link('10000000-0000-0000-0000-000000000001','https://tikkie.me/pay/x')$q$),'members cannot set the link');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select pg_temp.assert_true(pg_temp.refused($q$select public.circle_set_payment_link('10000000-0000-0000-0000-000000000001','javascript:alert(1)')$q$),'only https links');
select public.circle_set_payment_link('10000000-0000-0000-0000-000000000001','  https://tikkie.me/pay/Tikkie/abc123  ');
reset role;
select pg_temp.assert_true((select payment_link='https://tikkie.me/pay/Tikkie/abc123' from public.circles where id='10000000-0000-0000-0000-000000000001'),'the link is saved trimmed');
-- A member who accepted records the tap; someone without an agreement does not.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.circle_payment_opened();
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.circle_payment_opened();
reset role;
select pg_temp.assert_true((select payment_opened_at is not null from public.circle_payments where profile_id='00000000-0000-0000-0000-000000000001'),'the tap time is recorded');
select pg_temp.assert_true((select status='awaiting_payment' from public.circle_payments where profile_id='00000000-0000-0000-0000-000000000001'),'tapping Pay never marks a payment received');
select pg_temp.assert_true((select count(*)=1 from public.circle_payments),'no agreement is created by tapping');
-- Clearing the link.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000008',true);
select public.circle_set_payment_link('10000000-0000-0000-0000-000000000001','');
reset role;
select pg_temp.assert_true((select payment_link is null from public.circles where id='10000000-0000-0000-0000-000000000001'),'an empty link clears it');
rollback;
