-- Email goes live, and the WhatsApp number becomes optional.
--
-- Run this AFTER the send-notifications function is deployed and the
-- vault secret 'notification_cron_secret' exists (see docs/RUNBOOK.md).
--
-- 1. pg_net, so the database scheduler can call the email worker.
-- 2. defer_notification_email: the worker hands a notification back without
--    using up an attempt when the email provider says "not now" (daily cap),
--    or when it runs out of time in one run.
-- 3. Notifications created before today are not emailed: they are old news,
--    and some are test messages.
-- 4. A schedule that calls the worker every 10 minutes, only when something
--    is waiting.
-- 5. Members are reached by email now, so the WhatsApp number is optional:
--    applying, being "ready" for matching, the daily organiser summary and
--    inviting someone no longer require it. These functions are copied from
--    the live database with only those checks removed.
begin;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  end if;
end;
$$;

create or replace function public.defer_notification_email(
  notification_id uuid, lease_token uuid, retry_in_seconds integer default 0, reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nothing was sent, so this try does not count. When it was the first try,
  -- the provider's 24-hour duplicate window has not started either.
  update public.notifications n
     set email_attempts = greatest(n.email_attempts - 1, 0),
         email_first_claimed_at = case when n.email_attempts <= 1 then null else n.email_first_claimed_at end,
         email_lease_until = null, email_lease_token = null,
         email_retry_at = now() + make_interval(secs => greatest(coalesce(retry_in_seconds, 0), 0)),
         email_error = left(reason, 300)
   where n.id = notification_id and n.email_lease_token = defer_notification_email.lease_token;
  if not found then raise exception 'Email lease expired or was replaced.'; end if;
end;
$$;
revoke all on function public.defer_notification_email(uuid, uuid, integer, text) from public, anon, authenticated;
grant execute on function public.defer_notification_email(uuid, uuid, integer, text) to service_role;

update public.notifications
   set email_attempts = greatest(email_attempts, 5),
       email_error = 'Created before email delivery started; not emailed.'
 where emailed_at is null and created_at < current_date;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron')
     and exists (select 1 from pg_namespace where nspname = 'net') then
    perform cron.schedule('vriendtime-send-emails', '*/10 * * * *', $cron$
      select net.http_post(
        url := 'https://sageyiqyvzgoayehahyq.supabase.co/functions/v1/send-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets
                             where name = 'notification_cron_secret')),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000)
      where exists (select 1 from public.notifications
                     where emailed_at is null and email_attempts < 5
                       and created_at > now() - interval '3 days'
                       and (email_retry_at is null or email_retry_at <= now()));
    $cron$);
  end if;
end;
$$;

-- WhatsApp number optional ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.circle_action_before_hardening(action text, payload jsonb DEFAULT '{}'::jsonb)
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
  -- WhatsApp number (optional): stored in international form, e.g. +31612345678.
  phone:=regexp_replace(coalesce(payload->>'phone',''),'[\s().-]','','g');
  if phone like '00%' then phone:='+'||substr(phone,3); end if;
  if phone ~ '^06\d{8}$' then phone:='+31'||substr(phone,2); end if;
  if phone='' then phone:=null; end if;
  if phone is not null and phone !~ '^\+[1-9]\d{7,14}$' then raise exception 'Add a valid WhatsApp number, for example 06 12345678.'; end if;
  if action='apply' then
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

CREATE OR REPLACE FUNCTION public.circle_snapshot_before_hardening()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end;$function$;

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
  -- with a birthday, photo and times, like the panel.
  with ready as (
    select a.profile_id, a.answers
    from public.circle_applications a
    join public.profiles p on p.id=a.profile_id
    where a.status='waiting' and p.date_of_birth is not null
      and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots'
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

CREATE OR REPLACE FUNCTION public.circle_admin_invite(target_circle uuid, member uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.circles;
  a public.circle_applications;
  slot text;
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  select * into c from public.circles where id = target_circle for update;
  if not found or c.status not in ('offered', 'active') then
    raise exception 'Only an upcoming or active Circle can take a new member.';
  end if;
  if exists (select 1 from public.events where circle_id = target_circle and circle_week = 1 and starts_at <= now()) then
    raise exception 'This Circle has already had its first meetup.';
  end if;
  if (select count(*) from public.circle_memberships where circle_id = target_circle and status <> 'left') >= 6 then
    raise exception 'This Circle is full (6 people).';
  end if;
  select * into a from public.circle_applications where profile_id = member for update;
  if not found or a.status <> 'waiting' then raise exception 'This applicant is no longer waiting. Refresh first.'; end if;
  if exists (select 1 from public.profiles p where p.id = member
              and (p.date_of_birth is null or not public.circle_has_profile_photo(p.id)))
     or not a.answers ? 'availability_slots' then
    raise exception 'Ask this applicant to finish their birthday, photo and times first.';
  end if;
  slot := trim(to_char(c.start_date, 'Day')) || ' ' || public.circle_time_period(c.local_time);
  if not (coalesce(a.answers->'availability', '[]'::jsonb) ? slot) then
    raise exception 'This applicant is not free on the Circle''s day and time.';
  end if;
  if exists (
    select 1 from public.circle_memberships o
      join public.circle_applications oa on oa.profile_id = o.profile_id
     where o.circle_id = target_circle and o.status <> 'left'
       and not exists (select 1 from jsonb_array_elements_text(coalesce(a.answers->'languages', '[]'::jsonb)) l
                        where oa.answers->'languages' ? l.value)) then
    raise exception 'This applicant does not share a language with everyone in the Circle.';
  end if;
  if exists (
    select 1 from public.circle_exclusions x
      join public.circle_memberships o on o.circle_id = target_circle and o.status <> 'left'
     where (x.profile_id = member and x.excluded_profile_id = o.profile_id)
        or (x.profile_id = o.profile_id and x.excluded_profile_id = member)) then
    raise exception 'Someone in this Circle asked not to be matched with this applicant.';
  end if;
  insert into public.circle_memberships(circle_id, profile_id, status, payment_status, created_at)
  values (target_circle, member, 'invited', 'unpaid', now())
  on conflict (circle_id, profile_id) do update
    set status = 'invited', payment_status = 'unpaid', created_at = now();
  update public.circle_applications set status = 'invited', updated_at = now() where profile_id = member;
  insert into public.notifications(recipient_profile_id, kind, title, body)
  values (member, 'update', 'Your Circle is ready', 'Your Circle invitation and six-week schedule are ready to review.');
  insert into public.circle_audit(actor, action, target_id) values (auth.uid(), 'invite_to_circle', target_circle);
end;
$function$;

commit;
