-- The photo and birthday repair only fills empty fields from data that
-- still exists, and leaves everything else alone. Rolled back.
begin;
create function pg_temp.assert_true(value boolean,message text) returns void language plpgsql as $$ begin if value is distinct from true then raise exception 'ASSERTION FAILED: %',message; end if; end; $$;
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-000000000001','a@example.test'),
 ('00000000-0000-0000-0000-000000000002','b@example.test');
insert into storage.objects(bucket_id,name,created_at) values
 ('profile-photos','00000000-0000-0000-0000-000000000001/old.jpg',now()-interval '2 days'),
 ('profile-photos','00000000-0000-0000-0000-000000000001/new.jpg',now()-interval '1 day'),
 ('profile-photos','00000000-0000-0000-0000-000000000002/mine.jpg',now());
update public.profiles set profile_photo_path='00000000-0000-0000-0000-000000000002/mine.jpg' where id='00000000-0000-0000-0000-000000000002';
insert into public.circle_applications(profile_id,answers,status) values('00000000-0000-0000-0000-000000000001','{"date_of_birth":"1990-05-01"}','waiting');
-- Re-run the repair inside this test.
update public.profiles p set profile_photo_path=latest.name, has_profile_photo=true
  from (select distinct on (split_part(o.name,'/',1)) split_part(o.name,'/',1) as owner,o.name from storage.objects o
         where o.bucket_id='profile-photos' and o.name ~ '^[0-9a-f-]{36}/[^/]+$' order by split_part(o.name,'/',1),o.created_at desc) latest
 where p.id::text=latest.owner and p.profile_photo_path is null;
update public.profiles p set date_of_birth=(a.answers->>'date_of_birth')::date from public.circle_applications a
 where a.profile_id=p.id and p.date_of_birth is null and coalesce(a.answers->>'date_of_birth','') ~ '^\d{4}-\d{2}-\d{2}$';
select pg_temp.assert_true((select profile_photo_path from public.profiles where id='00000000-0000-0000-0000-000000000001')='00000000-0000-0000-0000-000000000001/new.jpg','the newest photo is restored');
select pg_temp.assert_true((select has_profile_photo from public.profiles where id='00000000-0000-0000-0000-000000000001'),'the photo flag is set');
select pg_temp.assert_true((select date_of_birth from public.profiles where id='00000000-0000-0000-0000-000000000001')='1990-05-01','the birthday is restored');
select pg_temp.assert_true((select profile_photo_path from public.profiles where id='00000000-0000-0000-0000-000000000002')='00000000-0000-0000-0000-000000000002/mine.jpg','an existing photo is untouched');
rollback;
