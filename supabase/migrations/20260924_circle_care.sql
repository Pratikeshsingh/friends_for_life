-- Four things the pilot cannot honestly launch without.
--
-- 1. Notifications that leave the database. Everything the app promises to
--    tell someone — your Circle is ready, here is the venue, see you tomorrow
--    — is currently a row nobody sees unless they happen to open the app that
--    hour. This adds the delivery bookkeeping an email sender needs.
-- 2. A way out of a Circle after the 14-day cancellation window. Between day
--    15 and week 6 there was no exit in the app at all.
-- 3. "Don't match me with this person", enforced at the database so it holds
--    whichever code path forms the group.
-- 4. Alerts for the organiser: a group is formable, or someone has stopped
--    turning up. Both are things a human has to act on and could not see.
begin;

-- ---------------------------------------------------------------- delivery
alter table public.notifications
  add column if not exists emailed_at timestamptz,
  add column if not exists email_attempts integer not null default 0,
  add column if not exists email_error text;

-- Everything already in the table predates email and must never be sent: a
-- backlog blast on the morning of deployment is the worst possible first
-- impression. New rows arrive with emailed_at null and are picked up.
update public.notifications set emailed_at=now() where emailed_at is null;

create index if not exists notifications_pending_email_idx
  on public.notifications(created_at) where emailed_at is null;

-- Email is opt-out, per person, and the only way to stop it. A row is created
-- on first change; absence means enabled.
create table if not exists public.notification_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  email_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_settings enable row level security;
drop policy if exists notification_settings_own on public.notification_settings;
create policy notification_settings_own on public.notification_settings
  for all to authenticated using (profile_id=auth.uid()) with check (profile_id=auth.uid());
grant select,insert,update on public.notification_settings to authenticated;

-- The sender runs as the service role and never sees a person's other data.
-- Anything older than three days is abandoned rather than delivered late: a
-- reminder for a meetup that has already happened is worse than silence.
create or replace function public.notifications_pending_email(max_rows integer default 50)
returns table(id uuid, email text, first_name text, kind text, title text, body text)
language sql security definer set search_path=public as $$
  select n.id,p.email,p.first_name,n.kind,n.title,n.body
  from public.notifications n
  join public.profiles p on p.id=n.recipient_profile_id
  left join public.notification_settings s on s.profile_id=n.recipient_profile_id
  where n.emailed_at is null
    and n.email_attempts<3
    and n.created_at>now()-interval '3 days'
    and p.email is not null
    and coalesce(s.email_enabled,true)
  order by n.created_at
  limit greatest(1,least(coalesce(max_rows,50),200));
$$;
revoke all on function public.notifications_pending_email(integer) from public,anon,authenticated;
grant execute on function public.notifications_pending_email(integer) to service_role;

-- A failure records the reason and counts towards the three attempts, so a
-- permanently bad address stops being retried instead of looping forever.
create or replace function public.mark_notifications_emailed(ids uuid[], failure text default null)
returns integer language plpgsql security definer set search_path=public as $$
declare touched integer;
begin
  update public.notifications
    set emailed_at=case when failure is null then now() else null end,
        email_attempts=email_attempts+1,
        email_error=failure
    where id=any(ids);
  get diagnostics touched=row_count; return touched;
end;$$;
revoke all on function public.mark_notifications_emailed(uuid[],text) from public,anon,authenticated;
grant execute on function public.mark_notifications_emailed(uuid[],text) to service_role;

-- ------------------------------------------------------------- leaving
-- Cancelling within 14 days is a payment decision and already exists. This is
-- the different, later case: the programme has started and someone needs to
-- stop. It never moves money — a refund stays a conversation with the
-- organiser — and it never tells the group who left or why.
create or replace function public.circle_leave(reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); m public.circle_memberships;
begin
  if uid is null then raise exception 'Sign in first.'; end if;
  if length(coalesce(reason,''))>2000 then raise exception 'Please shorten your note.'; end if;
  select * into m from public.circle_memberships where profile_id=uid and status<>'left' for update;
  if m.circle_id is null then raise exception 'You are not in a Circle.'; end if;
  if m.status<>'joined' then raise exception 'Decline the invitation instead.'; end if;

  update public.circle_memberships set status='left' where circle_id=m.circle_id and profile_id=uid;
  update public.circle_applications set status='withdrawn',updated_at=now() where profile_id=uid;
  -- Remove them from meetups that have not happened, so headcounts stay true.
  delete from public.event_attendees ea using public.events e
    where ea.event_id=e.id and ea.profile_id=uid and e.circle_id=m.circle_id and e.starts_at>now();

  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
  select cm.profile_id,'update','A change in your Circle',
         'Someone has stepped away. Your remaining meetups are unchanged.',
         'circle-left:'||m.circle_id||':'||uid
  from public.circle_memberships cm
  where cm.circle_id=m.circle_id and cm.status='joined' and cm.profile_id<>uid
  on conflict do nothing;

  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
  select a.profile_id,'support','A member left a Circle',
         coalesce(nullif(trim(reason),''),'No reason given.'),
         'circle-left-admin:'||m.circle_id||':'||uid
  from public.circle_admins a on conflict do nothing;

  insert into public.circle_audit(actor,action,target_id) values(uid,'left_circle',m.circle_id);
end;$$;
revoke all on function public.circle_leave(text) from public,anon;
grant execute on function public.circle_leave(text) to authenticated;

-- ---------------------------------------------------------- exclusions
-- Alkmaar is small enough that an ex-partner or a manager will turn up in the
-- pool. You can only exclude someone you have actually shared a Circle with,
-- so this cannot be used to probe who else is on the platform.
create table if not exists public.circle_exclusions (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  excluded_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(profile_id,excluded_profile_id),
  check(profile_id<>excluded_profile_id)
);
alter table public.circle_exclusions enable row level security;
drop policy if exists circle_exclusions_own on public.circle_exclusions;
-- Readable only by the person who set it: the excluded member is never told.
create policy circle_exclusions_own on public.circle_exclusions
  for select to authenticated using (profile_id=auth.uid());
grant select on public.circle_exclusions to authenticated;
create index if not exists circle_exclusions_excluded_idx
  on public.circle_exclusions(excluded_profile_id);

create or replace function public.circle_exclude(target uuid, active boolean default true)
returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Sign in first.'; end if;
  if target is null or target=uid then raise exception 'Choose someone else.'; end if;
  if not exists(
    select 1 from public.circle_memberships a
    join public.circle_memberships b on b.circle_id=a.circle_id
    where a.profile_id=uid and b.profile_id=target)
  then raise exception 'You can only do this for someone from one of your Circles.'; end if;
  if active then
    insert into public.circle_exclusions(profile_id,excluded_profile_id)
      values(uid,target) on conflict do nothing;
  else
    delete from public.circle_exclusions where profile_id=uid and excluded_profile_id=target;
  end if;
end;$$;
revoke all on function public.circle_exclude(uuid,boolean) from public,anon;
grant execute on function public.circle_exclude(uuid,boolean) to authenticated;

-- Enforced here rather than in the matcher, so it holds however a membership
-- is created: the organiser screen, a future automatic matcher, or by hand.
create or replace function public.guard_circle_exclusion() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if exists(
    select 1 from public.circle_memberships m
    join public.circle_exclusions x
      on (x.profile_id=new.profile_id and x.excluded_profile_id=m.profile_id)
      or (x.profile_id=m.profile_id and x.excluded_profile_id=new.profile_id)
    where m.circle_id=new.circle_id and m.status<>'left' and m.profile_id<>new.profile_id)
  then raise exception 'Someone here asked not to be matched with this person.'; end if;
  return new;
end;$$;
revoke all on function public.guard_circle_exclusion() from public,anon,authenticated;
drop trigger if exists guard_circle_exclusion on public.circle_memberships;
create trigger guard_circle_exclusion before insert on public.circle_memberships
  for each row execute function public.guard_circle_exclusion();

-- ------------------------------------------------------ organiser alerts
-- Both of these are things only a person can act on, and neither was visible
-- anywhere: you had to open the organiser screen and notice.
create or replace function public.queue_circle_alerts() returns integer
language plpgsql security definer set search_path=public as $$
declare total integer:=0; added integer;
begin
  -- Enough compatible people are waiting to form a Circle today.
  insert into public.notifications(recipient_profile_id,kind,title,body,dedupe_key)
  select ad.profile_id,'support','A Circle can be formed',
         g.people||' people are waiting who share '||g.lang||' and '||g.slot||'.',
         'circle-formable:'||g.lang||':'||g.slot||':'||current_date
  from public.circle_admins ad
  cross join (
    select l.value as lang, s.value as slot, count(distinct a.profile_id) as people
    from public.circle_applications a
    join public.profiles p on p.id=a.profile_id
    cross join lateral jsonb_array_elements_text(coalesce(a.answers->'languages','[]'::jsonb)) l
    cross join lateral jsonb_array_elements_text(coalesce(a.answers->'availability','[]'::jsonb)) s
    where a.status='waiting' and p.date_of_birth is not null
      and public.circle_has_profile_photo(p.id) and a.answers ? 'availability_slots'
    group by 1,2 having count(distinct a.profile_id)>=5
  ) g
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
end;$$;
revoke all on function public.queue_circle_alerts() from public,anon,authenticated;
grant execute on function public.queue_circle_alerts() to service_role;

do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('vriendtime-circle-alerts','45 * * * *','select public.queue_circle_alerts();');
 end if;
end $$;

commit;
