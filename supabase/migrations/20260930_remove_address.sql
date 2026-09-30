-- Stop collecting home addresses. The app no longer asks for one, the
-- database no longer stores one, and any address already saved is removed.
-- Built on the live definitions of these two functions as of 2026-09-30.
begin;

CREATE OR REPLACE FUNCTION public.circle_action(action text, payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid:=auth.uid(); dob date; value jsonb; day text; label text; part text; available jsonb:='[]'; clean jsonb; photo text; prior text; phone text;
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
  -- WhatsApp number: stored in international form, e.g. +31612345678.
  phone:=regexp_replace(coalesce(payload->>'phone',''),'[\s().-]','','g');
  if phone like '00%' then phone:='+'||substr(phone,3); end if;
  if phone ~ '^06\d{8}$' then phone:='+31'||substr(phone,2); end if;
  if phone='' then phone:=null; end if;
  if phone is not null and phone !~ '^\+[1-9]\d{7,14}$' then raise exception 'Add a valid WhatsApp number, for example 06 12345678.'; end if;
  if action='apply' then
   if phone is null then raise exception 'Add your WhatsApp number so the organiser can reach you.'; end if;
   if dob is null or extract(year from age(current_date,dob))<18 then raise exception 'Circles are for adults 18+. Add your date of birth.'; end if;
   select profile_photo_path into photo from public.profiles where id=uid;
   if not public.circle_has_profile_photo(uid) then raise exception 'Add a clear profile photo before applying.'; end if;
  end if;
  clean:=jsonb_build_object('name',trim(payload->>'name'),'city','Alkmaar','date_of_birth',dob,'languages',payload->'languages','availability_slots',payload->'availability_slots','availability',available,'interests',payload->'interests','activities',payload->'activities','energy',payload->'energy','goals',payload->'goals','life_context',payload->'life_context','intro',trim(coalesce(payload->>'intro','')),'commitment',coalesce((payload->>'commitment')::boolean,false),'phone',phone);
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
end;$function$;

CREATE OR REPLACE FUNCTION public.circle_admin_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare result jsonb:=public.circle_admin_snapshot_release();
begin
 result:=result||jsonb_build_object('applications',coalesce((select jsonb_agg((a.answers-'date_of_birth'-'age')||jsonb_build_object('profile_id',a.profile_id,'status',a.status,'age',extract(year from age(current_date,p.date_of_birth))::int,'photo_path',p.profile_photo_path,'submitted_at',a.submitted_at,'ready',p.date_of_birth is not null and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots') order by a.submitted_at) from public.circle_applications a join public.profiles p on p.id=a.profile_id where a.status='waiting'),'[]'));
 -- Contact details for the organiser only: the WhatsApp number.
 result:=result||jsonb_build_object('contacts',coalesce((
  select jsonb_object_agg(a.profile_id::text,jsonb_build_object('phone',a.answers->>'phone'))
  from public.circle_applications a
  where a.status in ('waiting','invited','joined') or exists(select 1 from public.circle_memberships m where m.profile_id=a.profile_id and m.status<>'left')),'{}'::jsonb));
 return result||jsonb_build_object('exclusions',coalesce((
  select jsonb_agg(distinct jsonb_build_array(
    least(x.profile_id::text,x.excluded_profile_id::text),
    greatest(x.profile_id::text,x.excluded_profile_id::text)))
  from public.circle_exclusions x),'[]'::jsonb));
end;$function$;

update public.circle_applications set answers = answers - 'address'
 where answers ? 'address';

commit;
