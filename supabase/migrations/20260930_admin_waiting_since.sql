-- Organiser panel: send each waiting applicant's application date, so the
-- panel can show how long they have waited and rank groups fairly.
-- Run after 20260929_contact_details.sql; this is a full superset of the
-- admin snapshot defined there (it keeps the 'contacts' map).
begin;

CREATE OR REPLACE FUNCTION public.circle_admin_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare result jsonb:=public.circle_admin_snapshot_release();
begin
 result:=result||jsonb_build_object('applications',coalesce((select jsonb_agg((a.answers-'date_of_birth'-'age')||jsonb_build_object('profile_id',a.profile_id,'status',a.status,'age',extract(year from age(current_date,p.date_of_birth))::int,'photo_path',p.profile_photo_path,'submitted_at',a.submitted_at,'ready',p.date_of_birth is not null and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots') order by a.submitted_at) from public.circle_applications a join public.profiles p on p.id=a.profile_id where a.status='waiting'),'[]'));
 -- Contact details for the organiser only: WhatsApp number and optional address.
 result:=result||jsonb_build_object('contacts',coalesce((
  select jsonb_object_agg(a.profile_id::text,jsonb_build_object('phone',a.answers->>'phone','address',a.answers->>'address'))
  from public.circle_applications a
  where a.status in ('waiting','invited','joined') or exists(select 1 from public.circle_memberships m where m.profile_id=a.profile_id and m.status<>'left')),'{}'::jsonb));
 return result||jsonb_build_object('exclusions',coalesce((
  select jsonb_agg(distinct jsonb_build_array(
    least(x.profile_id::text,x.excluded_profile_id::text),
    greatest(x.profile_id::text,x.excluded_profile_id::text)))
  from public.circle_exclusions x),'[]'::jsonb));
end;$function$;

revoke all on function public.circle_admin_snapshot() from public,anon;
grant execute on function public.circle_admin_snapshot() to authenticated;
commit;
