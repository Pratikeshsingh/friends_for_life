-- The database already refuses to put two people who asked not to be matched
-- into the same Circle. That protects them, but it leaves the organiser
-- picking a group and only discovering the problem when the save fails. Send
-- the pairs to the organiser screen so the suggester can avoid them instead.
--
-- Pairs only, and only as ids the organiser can already see — never who asked.
begin;
create or replace function public.circle_admin_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb:=public.circle_admin_snapshot_release();
begin
 result:=result||jsonb_build_object('applications',coalesce((select jsonb_agg((a.answers-'date_of_birth'-'age')||jsonb_build_object('profile_id',a.profile_id,'status',a.status,'age',extract(year from age(current_date,p.date_of_birth))::int,'photo_path',p.profile_photo_path,'ready',p.date_of_birth is not null and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots') order by a.submitted_at) from public.circle_applications a join public.profiles p on p.id=a.profile_id where a.status='waiting'),'[]'));
 return result||jsonb_build_object('exclusions',coalesce((
  select jsonb_agg(distinct jsonb_build_array(
    least(x.profile_id::text,x.excluded_profile_id::text),
    greatest(x.profile_id::text,x.excluded_profile_id::text)))
  from public.circle_exclusions x),'[]'::jsonb));
end;$$;
revoke all on function public.circle_admin_snapshot() from public,anon;
grant execute on function public.circle_admin_snapshot() to authenticated;
commit;
