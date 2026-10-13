-- The six-week programme, new time slots, gender, and smaller fixes.
--
-- 1. Time slots: Tue–Thu late morning (10:30) and evening, Fri–Sun
--    afternoon (14:00) and evening. A Circle may start anywhere in its part
--    of the day: morning 09:00–11:00, afternoon 12:00–15:00, evening
--    18:00–20:00. Applications also keep a private gender and a free-text
--    "other times".
-- 2. The organiser plans all six weeks before creating a Circle: weeks 1–4
--    fixed, weeks 5–6 a default the group may change. Saved suggestions per
--    part of the day (daytime / evening) pre-fill the plan.
-- 3. The place is shown from the invitation on (no longer hidden until the
--    day before).
-- 4. Meetups complete 24 hours after they end. Weeks 5–6 get a reminder of
--    their default plan six days before.
-- 5. Saving a plan can skip the email to members ("notify": false).
-- 6. The pay-by date is never later than the first meetup's day.
-- 7. Organisers can read a Circle's chat (it is moderated; members are told).
begin;

-- 1. Time windows ------------------------------------------------------------------
create or replace function public.circle_time_period(t time without time zone)
returns text
language sql
immutable
set search_path to 'public'
as $$
 select case when t between time '09:00' and time '11:00' then 'morning'
             when t between time '12:00' and time '15:00' then 'afternoon'
             when t between time '18:00' and time '20:00' then 'evening' end;
$$;

-- Gender and other times in the application (copied from the live function,
-- only the validation and the stored answers extended).
do $$
declare d text := pg_get_functiondef('public.circle_action_before_hardening(text, jsonb)'::regprocedure);
begin
  d := replace(d, '  clean:=jsonb_build_object(',
    '  if coalesce(payload->>''gender'','''') not in ('''',''man'',''woman'',''non_binary'',''prefer_not'') then raise exception ''Choose one of the options.''; end if;
  if coalesce(length(payload->>''other_times''),0)>300 then raise exception ''Please keep your other times under 300 characters.''; end if;
  clean:=jsonb_build_object(');
  d := replace(d, '''phone'',phone);',
    '''phone'',phone,''gender'',nullif(payload->>''gender'',''''),''other_times'',nullif(trim(coalesce(payload->>''other_times'','''')),''''));');
  if position('other_times' in d) = 0 or position('Choose one of the options.' in d) = 0 then
    raise exception 'application patch did not apply';
  end if;
  execute d;
end;
$$;

-- 2. Programme suggestions -----------------------------------------------------------
-- Per city, so a new city gets its own suggestions in the same table.
create table if not exists public.circle_programme_template (
  city text not null default 'Alkmaar' check (length(city) between 1 and 80),
  kind text not null check (kind in ('daytime', 'evening')),
  week integer not null check (week between 1 and 6),
  title text not null check (length(title) between 1 and 120),
  venue text not null check (length(venue) between 1 and 180),
  address text check (address is null or length(address) <= 200),
  cost text check (cost is null or length(cost) <= 300),
  primary key (city, kind, week)
);
alter table public.circle_programme_template enable row level security;

create table if not exists public.circle_settings (
  key text primary key,
  value text not null check (length(value) <= 300)
);
alter table public.circle_settings enable row level security;

-- What each week costs is shown with the plan, so nobody is surprised.
insert into public.circle_programme_template(kind, week, title, venue, address, cost) values
  ('evening', 1, 'Dinner together', 'Rozey Alkmaar', null, 'About €40 per person: all you can eat, drinks included.'),
  ('evening', 2, 'Drinks and a good conversation', 'Het Alkmaars Koffiehuis', 'Gedempte Nieuwesloot 42', 'You pay for yourself.'),
  ('evening', 3, 'Find out who’s secretly competitive', 'The Boules Club Alkmaar', 'Noorderkade 108', 'About €5–7 per person (€27.50 per court per hour, shared), plus drinks.'),
  ('evening', 4, 'Bowling and a drink', 'Victorie Plaza', 'Terborchlaan 327', 'About €5 per person (€20–25 per lane per hour, shared), plus drinks.'),
  ('evening', 5, 'Drinks', 'Mr. Gold', null, 'You pay for yourself.'),
  ('evening', 6, 'Drinks', 'Mr. Gold', null, 'You pay for yourself.'),
  ('daytime', 1, 'Lunch together', 'SOEPP', 'Hekelstraat 31', 'You pay for yourself.'),
  ('daytime', 2, 'Coffee and a walk', 'Kaldi', null, 'You pay for yourself.'),
  ('daytime', 3, 'Find out who’s secretly competitive', 'The Boules Club Alkmaar', 'Noorderkade 108', 'About €5–7 per person (€27.50 per court per hour, shared), plus drinks.'),
  ('daytime', 4, 'Board games', 'De Spellentoren', 'Schoutenstraat 28', 'About €5 per person, plus drinks.'),
  ('daytime', 5, 'Coffee', 'De Koffiemolen', 'Ritsevoort 26', 'You pay for yourself.'),
  ('daytime', 6, 'Coffee', 'De Koffiemolen', 'Ritsevoort 26', 'You pay for yourself.')
on conflict do nothing;

-- 3. The place is visible from the invitation on ------------------------------------
do $$
declare d text;
begin
  d := pg_get_functiondef('public.circle_snapshot_before_moves()'::regprocedure);
  d := regexp_replace(d, 'e\.circle_week between 1 and 3 and e\.starts_at>now\(\)\+interval ''24 hours''', 'false', 'g');
  if position('interval ''24 hours''' in d) > 0 then raise exception 'snapshot (moves) patch incomplete'; end if;
  execute d;
  d := pg_get_functiondef('public.circle_snapshot_before_hardening()'::regprocedure);
  d := regexp_replace(d, '>\s*now\(\)\+interval ''24 hours''', '> ''infinity''::timestamptz', 'g');
  execute d;
end;
$$;

-- Members change weeks 5–6 (no longer 4–6) ------------------------------------------
do $$
declare d text;
begin
  d := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
  d := replace(d, 'circle_week>=4', 'circle_week>=5');
  d := replace(d, 'Only upcoming weeks 4–6 can be changed by members.', 'Only upcoming weeks 5 and 6 can be changed by members.');
  execute d;
  d := pg_get_functiondef('public.circle_action_before_moves(text, jsonb)'::regprocedure);
  d := replace(d, 'e.circle_week<4', 'e.circle_week<5');
  execute d;
end;
$$;

-- 6. Pay-by never after the first meetup's day ------------------------------------
create or replace function public.circle_pay_by(invited_at timestamptz, start_date date)
returns date
language sql
immutable
set search_path = public
as $$
  select least(start_date, greatest(
    (invited_at at time zone 'Europe/Amsterdam')::date + 1,
    least((invited_at at time zone 'Europe/Amsterdam')::date + 5, start_date - 3)));
$$;

-- 4. Housekeeping: 24 hours, the Circle ends a week after its last meetup,
--    and the weeks 5–6 reminder --------------------------
create or replace function public.queue_meetup_housekeeping()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare n integer := 0; added integer;
begin
  update public.events
     set completed_at = ends_at
   where circle_id is not null and circle_week is not null
     and completed_at is null and status <> 'cancelled'
     and ends_at < now() - interval '24 hours';
  get diagnostics added = row_count; n := n + added;

  update public.circles c set status = 'completed'
   where c.status = 'active'
     and (select count(*) from public.events e
           where e.circle_id = c.id and e.circle_week is not null and e.completed_at is not null) >= 6
     -- The week after the last meetup is for one-to-ones; the Circle ends after it.
     and not exists (select 1 from public.events e
                      where e.circle_id = c.id and e.circle_week is not null and e.status <> 'cancelled'
                        and e.ends_at > now() - interval '7 days');

  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key)
  select a.profile_id, e.id, 'support', 'A meetup has no place yet',
         c.name || ' · week ' || e.circle_week || ' on '
           || to_char(e.starts_at at time zone 'Europe/Amsterdam', 'Dy DD Mon')
           || ': add the place so members know where to go.',
         'no-venue:' || e.id
    from public.events e
    join public.circles c on c.id = e.circle_id
    cross join public.circle_admins a
   where c.status in ('offered', 'active') and e.circle_week between 1 and 6
     and e.status <> 'cancelled' and coalesce(trim(e.venue_name), '') = ''
     and e.starts_at > now() and e.starts_at <= now() + interval '3 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;

  -- Weeks 5 and 6: remind the group of the default plan, once, unless a
  -- member already changed it.
  insert into public.notifications(recipient_profile_id, event_id, kind, title, body, dedupe_key, metadata)
  select m.profile_id, e.id, 'reminder', 'Your plan for week ' || e.circle_week,
         'Week ' || e.circle_week || ' of ' || c.name || ' is planned as ' || e.title
           || coalesce(' at ' || nullif(trim(e.venue_name), ''), '')
           || '. Want to do something else? Change it together in the app.',
         'week-plan:' || e.id || ':' || m.profile_id,
         jsonb_build_object('open', 'meetup:' || e.id)
    from public.events e
    join public.circles c on c.id = e.circle_id
    join public.circle_memberships m on m.circle_id = e.circle_id and m.status = 'joined'
   where c.status = 'active' and e.circle_week between 5 and 6 and e.status <> 'cancelled'
     and (e.updated_by is null or exists (select 1 from public.circle_admins x where x.profile_id = e.updated_by))
     and e.starts_at > now() and e.starts_at <= now() + interval '6 days'
  on conflict do nothing;
  get diagnostics added = row_count; n := n + added;
  return n;
end;
$$;
revoke all on function public.queue_meetup_housekeeping() from public, anon, authenticated;

-- 2 + 5. Creating a Circle with its six-week plan; saving without email ------------
do $$
declare d text := pg_get_functiondef('public.circle_action(text, jsonb)'::regprocedure);
begin
  d := replace(d, '  tid uuid;', '  tid uuid;
  before_ids uuid[];');
  d := replace(d, '  if action in (''join_again'', ''stop_looking'') then',
'  if action = ''admin_create'' then
    if not public.circle_is_admin() then raise exception ''Organiser access required.''; end if;
    -- No plan sent (older app): use the saved suggestions for this part of the day.
    if payload->''weeks'' is null then
      payload := payload || jsonb_build_object(''weeks'', (
        select jsonb_agg(jsonb_build_object(''title'', t.title, ''venue'', t.venue, ''address'', t.address, ''cost'', t.cost) order by t.week)
          from public.circle_programme_template t
         where t.city = coalesce(nullif(payload->>''city'', ''''), ''Alkmaar'')
           and t.kind = case when public.circle_time_period((payload->>''time'')::time) = ''evening'' then ''evening'' else ''daytime'' end));
    end if;
    if jsonb_typeof(payload->''weeks'') is distinct from ''array'' or jsonb_array_length(payload->''weeks'') <> 6
       or exists (select 1 from jsonb_array_elements(payload->''weeks'') w
                   where coalesce(length(trim(w->>''title'')), 0) not between 1 and 120
                      or coalesce(length(trim(w->>''venue'')), 0) not between 1 and 180) then
      raise exception ''Add an activity and a place for all six weeks.'';
    end if;
    perform public.circle_action_before_second_circle(action, payload - ''weeks'');
    select ca.target_id into cid from public.circle_audit ca
     where ca.actor = uid and ca.action = ''admin_create'' order by ca.created_at desc limit 1;
    update public.events e
       set title = trim(w->>''title''), venue_name = trim(w->>''venue''),
           venue_address = nullif(trim(coalesce(w->>''address'', '''')), ''''),
           cost_notes = nullif(left(trim(coalesce(w->>''cost'', '''')), 300), ''''), updated_by = uid
      from jsonb_array_elements(payload->''weeks'') with ordinality t(w, i)
     where e.circle_id = cid and e.circle_week = t.i;
    return;
  elsif action = ''admin_schedule'' and coalesce((payload->>''notify'')::boolean, true) = false then
    -- Saved without telling members: drop only the update notices this save queues.
    select coalesce(array_agg(n.id), ''{}'') into before_ids from public.notifications n
     where n.event_id = (payload->>''id'')::uuid;
    perform public.circle_action_before_second_circle(action, payload - ''notify'');
    delete from public.notifications n
     where n.event_id = (payload->>''id'')::uuid and not (n.id = any(before_ids))
       and n.title in (''Your Circle plan changed'', ''Your Circle has a plan update'');
    return;
  elsif action = ''admin_template'' then
    if not public.circle_is_admin() then raise exception ''Organiser access required.''; end if;
    if payload->>''kind'' not in (''daytime'', ''evening'') then raise exception ''Choose daytime or evening.''; end if;
    insert into public.circle_programme_template(city, kind, week, title, venue, address, cost)
    select coalesce(nullif(trim(payload->>''city''), ''''), ''Alkmaar''), payload->>''kind'', (w->>''week'')::int, trim(w->>''title''), trim(w->>''venue''),
           nullif(trim(coalesce(w->>''address'', '''')), ''''),
           nullif(left(trim(coalesce(w->>''cost'', '''')), 300), '''')
      from jsonb_array_elements(coalesce(payload->''weeks'', ''[]''::jsonb)) w
    on conflict (city, kind, week) do update
      set title = excluded.title, venue = excluded.venue, address = excluded.address, cost = excluded.cost;
    insert into public.circle_audit(actor, action, target_id) values (uid, action, uid);
    return;
  end if;
  if action in (''join_again'', ''stop_looking'') then');
  if position('admin_template' in d) = 0 then raise exception 'circle_action patch did not apply'; end if;
  execute d;
end;
$$;

-- Organiser snapshot: suggestions and meeting points ---------------------------------
alter function public.circle_admin_snapshot() rename to circle_admin_snapshot_before_programme;
revoke all on function public.circle_admin_snapshot_before_programme() from public, anon, authenticated;

create function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return public.circle_admin_snapshot_before_programme() || jsonb_build_object(
    'programme', coalesce((select jsonb_agg(to_jsonb(t) order by t.city, t.kind, t.week)
                             from public.circle_programme_template t), '[]'::jsonb),
    'settings', coalesce((select jsonb_object_agg(s.key, s.value) from public.circle_settings s), '{}'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- 7. Organisers read a Circle's chat (moderation) ------------------------------------
create or replace function public.circle_admin_messages(target_circle uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  return coalesce((
    select jsonb_agg(x.item order by x.created_at) from (
      select msg.created_at, jsonb_build_object(
               'id', msg.id, 'created_at', msg.created_at,
               'name', coalesce(p.first_name, 'Member'), 'body', msg.body) item
        from public.messages msg
        join public.chat_threads t on t.id = msg.thread_id
        left join public.profiles p on p.id = msg.sender_id
       where t.circle_id = target_circle
       order by msg.created_at desc limit 200) x), '[]'::jsonb);
end;
$$;
revoke all on function public.circle_admin_messages(uuid) from public, anon;
grant execute on function public.circle_admin_messages(uuid) to authenticated;

commit;
