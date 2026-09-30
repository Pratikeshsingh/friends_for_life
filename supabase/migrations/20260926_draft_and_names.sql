-- Two fixes to circle_action, both reported from the running app.
--
-- 1. Editing one answer used to drop a waiting applicant off the waiting
--    list. The client saves an edit as a 'draft', and a draft sets
--    status='draft', so someone who changed their availability was quietly
--    returned to onboarding ("Your application is waiting for you").
--    A draft from a waiting applicant now keeps them waiting.
-- 2. Names are stored exactly as typed, and profiles.first_name wins over
--    the application answer everywhere it is read. On the web the client's
--    capitalisation never fires, so people saw a lower-case first name.
--    Capitalise the FIRST letter only, server-side, on every write path —
--    deliberately not initcap(), which would turn "van der Berg" into
--    "Van Der Berg".
begin;

create or replace function public.circle_name_case(value text) returns text
language sql immutable as $$
  select case when coalesce(trim(value),'')='' then trim(value)
         else upper(left(trim(value),1))||substr(trim(value),2) end;
$$;
create or replace function public.circle_action(action text,payload jsonb default '{}') returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); dob date; value jsonb; day text; label text; part text; available jsonb:='[]'; clean jsonb; photo text; prior text;
begin
 if uid is null then raise exception 'Sign in first.'; end if;
 if octet_length(payload::text)>16000 then raise exception 'This request is too large.'; end if;
 if action in ('draft','apply') then
  if payload->>'date_of_birth' is not null then
   if (payload->>'date_of_birth') !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Choose a valid date of birth.'; end if;
   dob:=(payload->>'date_of_birth')::date;
   if dob>current_date or dob<current_date-interval '120 years' then raise exception 'Choose a valid date of birth.'; end if;
  end if;
  if jsonb_typeof(payload->'languages') is distinct from 'array' or exists(select 1 from jsonb_array_elements_text(payload->'languages') l where l.value not in ('English','Dutch')) then raise exception 'Our first Circles run in English and Dutch.'; end if;
  if payload->>'city' is distinct from 'Alkmaar' then raise exception 'Our first Circles are in Alkmaar.'; end if;
  if jsonb_typeof(payload->'availability_slots') is distinct from 'object' then raise exception 'Choose your days and times.'; end if;
  for day,value in select * from jsonb_each(payload->'availability_slots') loop
   label:=case day when 'mon' then 'Monday' when 'tue' then 'Tuesday' when 'wed' then 'Wednesday' when 'thu' then 'Thursday' when 'fri' then 'Friday' when 'sat' then 'Saturday' when 'sun' then 'Sunday' end;
   if label is null or jsonb_typeof(value)<>'array' then raise exception 'Choose valid days and times.'; end if;
   if action='apply' and jsonb_array_length(value)=0 then raise exception 'Choose a time for each selected day.'; end if;
   for part in select jsonb_array_elements_text(value) loop
    if part not in ('morning','afternoon','evening') then raise exception 'Choose morning, afternoon or evening.'; end if;
    available:=available||jsonb_build_array(label||' '||part);
   end loop;
  end loop;
  if jsonb_typeof(payload->'goals') is distinct from 'array' or exists(select 1 from jsonb_array_elements_text(payload->'goals') g where g.value not in ('Regular plans','Shared hobbies','Local friends')) then raise exception 'Choose what you would like to find.'; end if;
  if jsonb_typeof(payload->'life_context') is distinct from 'array' or exists(select 1 from jsonb_array_elements_text(payload->'life_context') g where g.value not in ('New to the area','Working from home','A new chapter','Making more time','New job or studies','Friends moved away','A fresh start','More free time now')) then raise exception 'Choose one of the optional contexts.'; end if;
  if coalesce(length(payload->>'intro'),0)>160 or coalesce(length(payload->>'name'),0)>60 then raise exception 'Please keep your profile short.'; end if;
  if (payload->>'energy')::int not in (0,2,4) or payload->>'energy' is null then raise exception 'Choose a social style.'; end if;
  if action='apply' then
   if dob is null or extract(year from age(current_date,dob))<18 then raise exception 'Circles are for adults 18+. Add your date of birth.'; end if;
   select profile_photo_path into photo from public.profiles where id=uid;
   if not public.circle_has_profile_photo(uid) then raise exception 'Add a clear profile photo before applying.'; end if;
  end if;
  clean:=jsonb_build_object('name',trim(payload->>'name'),'city','Alkmaar','date_of_birth',dob,'languages',payload->'languages','availability_slots',payload->'availability_slots','availability',available,'interests',payload->'interests','activities',payload->'activities','energy',payload->'energy','goals',payload->'goals','life_context',payload->'life_context','intro',trim(coalesce(payload->>'intro','')),'commitment',coalesce((payload->>'commitment')::boolean,false));
  select status into prior from public.circle_applications where profile_id=uid;
  perform public.circle_action_release(action,clean);
  -- A waiting applicant editing one answer stays on the waiting list.
  if action='draft' and prior='waiting' then
   update public.circle_applications set status='waiting',updated_at=now() where profile_id=uid;
  end if;
  update public.profiles set first_name=coalesce(nullif(public.circle_name_case(payload->>'name'),''),first_name),date_of_birth=coalesce(dob,date_of_birth),city='Alkmaar' where id=uid;
  return;
 elsif action='edit_circle_profile' then
  if coalesce(length(trim(payload->>'name')),0) not between 1 and 60 or coalesce(length(payload->>'intro'),0)>160 then raise exception 'Add your name and keep your introduction under 160 characters.'; end if;
  update public.circle_applications set answers=answers||jsonb_build_object('name',public.circle_name_case(payload->>'name'),'intro',trim(coalesce(payload->>'intro',''))) where profile_id=uid;
  if not found then raise exception 'Save your matching details first.'; end if;
  update public.profiles set first_name=public.circle_name_case(payload->>'name') where id=uid;
  return;
 elsif action='refresh_commitment' then
  update public.circle_applications set updated_at=now() where profile_id=uid and status='waiting';
  if not found then raise exception 'Submit your application first.'; end if;
  return;
 end if;
 perform public.circle_action_release(action,payload);
end;$$;
revoke all on function public.circle_action(text,jsonb) from public,anon;
grant execute on function public.circle_action(text,jsonb) to authenticated;
-- Bring names already stored in lower case up to the same rule.
update public.profiles set first_name=public.circle_name_case(first_name)
  where first_name is not null and first_name<>public.circle_name_case(first_name);
update public.circle_applications
  set answers=answers||jsonb_build_object('name',public.circle_name_case(answers->>'name'))
  where answers->>'name' is not null
    and answers->>'name'<>public.circle_name_case(answers->>'name');
commit;
