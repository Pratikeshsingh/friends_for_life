-- Organiser alerts: one 'Circles can be formed' summary a day instead of one
-- per language and time slot, counting only people with a WhatsApp number.
-- Built on the live queue_circle_alerts as of 2026-10-02; the other alerts in
-- it are unchanged.
begin;

CREATE OR REPLACE FUNCTION public.queue_circle_alerts()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare total integer:=0; added integer;
begin
  -- Circles can be formed: one summary a day per organiser, not one per
  -- language and time. The same people are often free on several evenings,
  -- so per-slot alerts repeated the same group. People count as ready only
  -- with a birthday, photo, times and a WhatsApp number, like the panel.
  with ready as (
    select a.profile_id, a.answers
    from public.circle_applications a
    join public.profiles p on p.id=a.profile_id
    where a.status='waiting' and p.date_of_birth is not null
      and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots'
      and coalesce(a.answers->>'phone','')<>''
  ), pairs as (
    select l.value as lang, s.value as slot, r.profile_id
    from ready r
    cross join lateral jsonb_array_elements_text(coalesce(r.answers->'languages','[]'::jsonb)) l
    cross join lateral jsonb_array_elements_text(coalesce(r.answers->'availability','[]'::jsonb)) s
  ), formable as (
    select lang, slot from pairs group by 1,2 having count(distinct profile_id)>=5
  ), people as (
    select count(distinct pr.profile_id) as n
    from pairs pr join formable f on f.lang=pr.lang and f.slot=pr.slot
  )
  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
  select ad.profile_id,'support','Circles can be formed',
         (select n from people)||' people are ready to be grouped. Open Form Circles to see the groups.',
         'circle-formable:'||current_date
  from public.circle_admins ad
  where exists(select 1 from formable)
  on conflict do nothing;
  get diagnostics added=row_count; total:=total+added;

  -- Someone has missed two meetups. Five people carry a Circle; four is a
  -- different evening, and the organiser should hear about it from us.
  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
  select ad.profile_id,'support','A member is missing meetups',
         coalesce(g.first_name,'A member')||' has missed '||g.missed||' meetups.',
         'circle-absent:'||g.circle_id||':'||g.profile_id||':'||g.missed
  from public.circle_admins ad
  cross join (
    select e.circle_id, ea.profile_id, p.first_name, count(*) as missed
    from public.events e
    join public.event_attendees ea on ea.event_id=e.id
    join public.profiles p on p.id=ea.profile_id
    join public.circle_memberships cm on cm.circle_id=e.circle_id and cm.profile_id=ea.profile_id
    where e.circle_id is not null and e.completed_at is not null
      and ea.attended is false and cm.status='joined'
    group by 1,2,3 having count(*)>=2
  ) g
  on conflict do nothing;
  get diagnostics added=row_count; return total+added;
end;$function$;

commit;
