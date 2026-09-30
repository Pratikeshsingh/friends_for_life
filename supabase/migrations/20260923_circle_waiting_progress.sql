-- Two additions to the member snapshot, both post-processing what the release
-- function already returns.
--
-- 1. nearest_slot: how close a waiting applicant actually is. For whichever of
--    their chosen slots has the most compatible people also waiting, return
--    that slot plus the number of OTHER waiting applicants who share it and
--    share at least one language. Counts only, never identities.
-- 2. The venue of a scheduled meetup is withheld until 24 hours before it
--    starts. Revealing the place late is deliberate: people commit to the
--    Circle, not to the restaurant. Redacting server-side rather than hiding
--    in the UI means the address is genuinely not in the payload yet.
begin;
create or replace function public.circle_snapshot() returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result jsonb:=public.circle_snapshot_release(); p public.profiles; a public.circle_applications; cid uuid:=(result->'circle'->>'id')::uuid;
begin
 select * into p from public.profiles where id=auth.uid();
 select * into a from public.circle_applications where profile_id=auth.uid();
 result:=result||jsonb_build_object('application',coalesce(result->'application','{}')||jsonb_build_object('name',coalesce(p.first_name,a.answers->>'name'),'date_of_birth',p.date_of_birth,'photo_path',p.profile_photo_path),
 'application_updated_at',a.updated_at,'application_submitted_at',a.submitted_at,
 'needs_details',a.status='waiting' and (p.date_of_birth is null or not public.circle_has_profile_photo(p.id) or not a.answers ? 'availability_slots'));
 if cid is not null then
  result:=result||jsonb_build_object('members',coalesce((select jsonb_agg(jsonb_build_object('id',m.profile_id,'name',coalesce(mp.first_name,ma.answers->>'name','Member'),'photo_path',mp.profile_photo_path,'bio',coalesce(nullif(ma.answers->>'intro',''),'Looking forward to meeting the Circle.'),'interests',ma.answers->'interests') order by m.created_at)
   from public.circle_memberships m join public.profiles mp on mp.id=m.profile_id left join public.circle_applications ma on ma.profile_id=m.profile_id where m.circle_id=cid and m.status<>'left'),'[]'));
 end if;
 if result->>'stage'='waiting' then
  result:=result||jsonb_build_object('nearest_slot',(
   select jsonb_build_object('slot',v.value,'peers',count(distinct o.profile_id))
   from jsonb_array_elements_text(coalesce(a.answers->'availability','[]'::jsonb)) v
   left join public.circle_applications o
     on o.profile_id<>auth.uid() and o.status='waiting'
    and o.answers->'availability' ? v.value
    and exists(select 1 from jsonb_array_elements_text(coalesce(a.answers->'languages','[]'::jsonb)) l
               where o.answers->'languages' ? l.value)
   group by v.value
   order by count(distinct o.profile_id) desc, v.value
   limit 1));
 end if;
 if jsonb_typeof(result->'meetups')='array' then
  result:=result||jsonb_build_object('meetups',coalesce((
   select jsonb_agg(case
     when m->>'week' is not null and m->>'date' is not null
      and (((m->>'date')::date + coalesce(m->>'time','19:30')::time) at time zone 'Europe/Amsterdam')
          > now()+interval '24 hours'
     then (m-'venue')||jsonb_build_object('venue_hidden',true)
     else m end order by ord)
   from jsonb_array_elements(result->'meetups') with ordinality t(m,ord)),'[]'::jsonb));
 end if;
 return result;
end;$$;
revoke all on function public.circle_snapshot() from public,anon;
grant execute on function public.circle_snapshot() to authenticated;
commit;
