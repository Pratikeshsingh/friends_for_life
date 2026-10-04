-- Restore profile photos and birthdays erased by sign-in.
--
-- Until 4 October 2026 the app overwrote the whole profile row on every
-- sign-in with values from the sign-in account's metadata. The Circle app
-- stores the photo and birthday on the profile itself, so those were set back
-- to empty. The files and answers still exist; this points the profile at
-- them again. Safe to run more than once: it only fills empty fields.
begin;

-- The newest photo in each member's own folder.
update public.profiles p
   set profile_photo_path = latest.name,
       has_profile_photo = true
  from (
    select distinct on (split_part(o.name, '/', 1))
           split_part(o.name, '/', 1) as owner, o.name
      from storage.objects o
     where o.bucket_id = 'profile-photos'
       and o.name ~ '^[0-9a-f-]{36}/[^/]+$'
     order by split_part(o.name, '/', 1), o.created_at desc
  ) latest
 where p.id::text = latest.owner
   and p.profile_photo_path is null;

-- Birthdays that are still in the Circle application.
update public.profiles p
   set date_of_birth = (a.answers->>'date_of_birth')::date
  from public.circle_applications a
 where a.profile_id = p.id
   and p.date_of_birth is null
   and coalesce(a.answers->>'date_of_birth', '') ~ '^\d{4}-\d{2}-\d{2}$';

commit;
