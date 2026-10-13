-- Running late in one tap; the booking name defaults to the Circle's name;
-- the same four smileys for coffees and places.
--
-- 1. "I'm running late" (5, 10, 15 or 30 minutes), close to a group meetup
--    or a coffee: posts a message in the group chat in the member's
--    language, and tells the coffee partner directly.
-- 2. A week without a booking name uses the Circle's name.
-- 3. Coffee feedback and "how was the place?" use the check-in smileys.
begin;

-- 2. Booking name: the Circle's name unless the plan says otherwise -------------------
do $$
declare d text := pg_get_functiondef('public.circle_action_before_coffee(text, jsonb)'::regprocedure);
begin
  d := replace(d, 'booking_name = nullif(left(trim(coalesce(w->>''booking'', '''')), 120), ''''), updated_by = uid',
                  'booking_name = coalesce(nullif(left(trim(coalesce(w->>''booking'', '''')), 120), ''''),
                                  (select c.name from public.circles c where c.id = cid)), updated_by = uid');
  if position('select c.name from public.circles c where c.id = cid' in d) = 0 then
    raise exception 'booking default patch did not apply';
  end if;
  execute d;
end;
$$;
update public.circle_programme_template set booking_name = null where booking_name = 'VriendTime';

-- 3. Smileys ----------------------------------------------------------------------------
alter table public.circle_coffee_feedback drop constraint if exists circle_coffee_feedback_rating_check;
alter table public.circle_coffee_feedback add constraint circle_coffee_feedback_rating_check
  check (rating in ('great', 'good', 'okay', 'not', 'bad', 'no_show'));
alter table public.circle_check_ins add column if not exists place_feeling text
  check (place_feeling is null or length(place_feeling) <= 40);

do $$
declare d text := pg_get_functiondef('public.circle_action_before_details(text, jsonb)'::regprocedure);
begin
  d := replace(d, 'not in (''good'', ''bad'', ''no_show'')', 'not in (''great'', ''good'', ''okay'', ''not'', ''no_show'')');
  -- Confirmation of a coffee: running late is now a button.
  d := replace(d, '''. Running late? Say so in the group chat.''', '''. Running late? Let them know in the app.''');
  if position('''okay''' in d) = 0 or position('Let them know in the app' in d) = 0 then
    raise exception 'coffee patch did not apply';
  end if;
  execute d;
  d := pg_get_functiondef('public.queue_coffee_reminders(boolean)'::regprocedure);
  d := replace(d, '''. Running late? Say so in the group chat.''', '''. Running late? Let them know in the app.''');
  if position('Let them know in the app' in d) = 0 then raise exception 'reminder patch did not apply'; end if;
  execute d;
end;
$$;

-- 1 + 3. The top of circle_action -----------------------------------------------------------
create or replace function public.circle_action(action text, payload jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  minutes integer;
  k public.circle_coffees;
  e public.events;
  cid uuid;
  other uuid;
  nl boolean;
  me text;
  other_name text;
  tid uuid;
  body text;
begin
  if action = 'running_late' then
    if uid is null then raise exception 'Sign in first.'; end if;
    minutes := nullif(payload->>'minutes', '')::integer;
    if minutes is null or minutes not in (5, 10, 15, 30) then raise exception 'Choose how late you’ll be.'; end if;
    select coalesce(language, 'en') = 'nl', coalesce(first_name, 'Someone') into nl, me
      from public.profiles where id = uid;
    if payload->>'kind' = 'coffee' then
      select * into k from public.circle_coffees where id = nullif(payload->>'id', '')::uuid;
      if k.id is null or uid not in (k.a, k.b) or k.status <> 'confirmed'
         or k.starts_at not between now() - interval '1 hour' and now() + interval '3 hours' then
        raise exception 'You can only say this on the day, close to the time.';
      end if;
      cid := k.circle_id;
      other := case when k.a = uid then k.b else k.a end;
      select coalesce(first_name, 'your match') into other_name from public.profiles where id = other;
      body := case when nl then 'Ik ben ongeveer ' || minutes || ' minuten later voor onze koffie, ' || other_name || '.'
                   else 'Running about ' || minutes || ' minutes late for our coffee, ' || other_name || '.' end;
      insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata)
      values (other, 'reminder', me || ' is running late',
              'About ' || minutes || ' minutes. Your coffee at '
                || to_char(k.starts_at at time zone 'Europe/Amsterdam', 'HH24:MI') || ' at ' || k.place || '.',
              'late:' || k.id || ':' || uid || ':' || minutes, jsonb_build_object('open', 'messages'))
      on conflict do nothing;
    else
      select ev.* into e from public.events ev
       where ev.id = nullif(payload->>'id', '')::uuid and ev.circle_id is not null and ev.status <> 'cancelled';
      if e.id is null or not exists (select 1 from public.circle_memberships
                                      where circle_id = e.circle_id and profile_id = uid and status = 'joined')
         or e.starts_at not between now() - interval '1 hour' and now() + interval '3 hours' then
        raise exception 'You can only say this on the day, close to the time.';
      end if;
      cid := e.circle_id;
      body := case when nl then 'Ik ben ongeveer ' || minutes || ' minuten later.'
                   else 'Running about ' || minutes || ' minutes late.' end;
    end if;
    -- Once per meetup or coffee: a second tap does not post again.
    if exists (select 1 from public.notifications
                where recipient_profile_id = uid and dedupe_key = 'late-sent:' || coalesce(k.id, e.id)) then
      raise exception 'Your Circle already knows you’re running late.';
    end if;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, read_at, emailed_at)
    values (uid, 'update', 'You let your Circle know', body, 'late-sent:' || coalesce(k.id, e.id), now(), now());
    select id into tid from public.chat_threads where circle_id = cid;
    insert into public.messages(thread_id, sender_id, body) values (tid, uid, body);
    return;
  end if;

  perform public.circle_action_before_details(action, payload - 'go_back' - 'booking' - 'place_feeling');
  if action = 'check_in' and jsonb_typeof(payload->'go_back') = 'boolean' then
    update public.circle_check_ins set go_back = (payload->>'go_back')::boolean
     where profile_id = uid and event_id = nullif(payload->>'id', '')::uuid;
  end if;
  if action = 'check_in' and coalesce(payload->>'place_feeling', '') <> '' then
    update public.circle_check_ins set place_feeling = left(payload->>'place_feeling', 40)
     where profile_id = uid and event_id = nullif(payload->>'id', '')::uuid;
  elsif action = 'admin_schedule' and payload ? 'booking' and public.circle_is_admin() then
    update public.events set booking_name = nullif(left(trim(payload->>'booking'), 120), '')
     where id = nullif(payload->>'id', '')::uuid and circle_id is not null;
  end if;
end;
$$;
revoke all on function public.circle_action(text, jsonb) from public, anon;
grant execute on function public.circle_action(text, jsonb) to authenticated;

-- Organisers see how the place felt, per meetup.
create or replace function public.circle_admin_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb := public.circle_admin_snapshot_before_details();
begin
  return result || jsonb_build_object('circles', coalesce((
    select jsonb_agg(c || jsonb_build_object('meetups', coalesce((
             select jsonb_agg(m || jsonb_build_object(
                      'booking_name', e.booking_name,
                      'go_back_yes', (select count(*) from public.circle_check_ins ci where ci.event_id = e.id and ci.go_back),
                      'go_back_no', (select count(*) from public.circle_check_ins ci where ci.event_id = e.id and not ci.go_back),
                      'place_feelings', coalesce((select jsonb_object_agg(f.place_feeling, f.n)
                                                    from (select ci.place_feeling, count(*) n from public.circle_check_ins ci
                                                           where ci.event_id = e.id and ci.place_feeling is not null
                                                           group by 1) f), '{}'::jsonb))
                    order by mo)
               from jsonb_array_elements(coalesce(c->'meetups', '[]'::jsonb)) with ordinality t2(m, mo)
               left join public.events e on e.id::text = m->>'id'),
             '[]'::jsonb)) order by ord)
      from jsonb_array_elements(coalesce(result->'circles', '[]'::jsonb)) with ordinality t(c, ord)),
    '[]'::jsonb));
end;
$$;
revoke all on function public.circle_admin_snapshot() from public, anon;
grant execute on function public.circle_admin_snapshot() to authenticated;

-- The home page shows coffees between the weekly meetups: each member's own
-- coffees and free weeks per round.
create or replace function public.circle_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result jsonb := public.circle_snapshot_before_details();
  cid uuid := nullif(result->'circle'->>'id', '')::uuid;
begin
  if jsonb_typeof(result->'meetups') = 'array' then
    result := result || jsonb_build_object('meetups', coalesce((
      select jsonb_agg(m || jsonb_build_object('booking_name', e.booking_name) order by ord)
        from jsonb_array_elements(result->'meetups') with ordinality t(m, ord)
        left join public.events e on e.id::text = m->>'id'), '[]'::jsonb));
  end if;
  if jsonb_typeof(result->'coffees') = 'object' and cid is not null then
    result := jsonb_set(result, '{coffees,rounds}', coalesce((
      select jsonb_agg(jsonb_build_object(
               'round', r.round,
               'decided', r.decided_at is not null,
               'coffee', (select jsonb_build_object('starts_at', k.starts_at, 'status', k.status, 'place', k.place,
                                                    'name', coalesce(o.first_name, 'Member'))
                            from public.circle_coffees k
                            join public.profiles o on o.id = case when k.a = uid then k.b else k.a end
                           where k.circle_id = cid and k.round = r.round and uid in (k.a, k.b) and k.status <> 'off'
                           order by k.created_at desc limit 1)) order by r.round)
        from public.circle_coffee_rounds r where r.circle_id = cid), '[]'::jsonb));
  end if;
  return result;
end;
$$;
revoke all on function public.circle_snapshot() from public, anon;
grant execute on function public.circle_snapshot() to authenticated;

commit;
