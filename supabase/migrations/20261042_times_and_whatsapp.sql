-- Times for one-to-ones, other times to the organiser, and WhatsApp groups
-- people already have (17 October, second round).
--
-- 1. One-to-ones can have their own times ("Choose separately"); without
--    them, the group times are used as before.
-- 2. "None of these work?": a note about other times goes to the organiser,
--    who gets in touch (a free-text time can't be matched automatically).
-- 3. The WhatsApp question gets a third answer: "We already have a group".
-- Every statement can run again safely.

-- 1. One-to-one times -------------------------------------------------------------------
-- Only known days and parts of the day, nothing else; null when empty.
create or replace function public.circle_clean_slots(raw jsonb)
returns jsonb
language sql
immutable
set search_path = public
as $$
  select nullif(coalesce((
    select jsonb_object_agg(d.key, d.parts)
      from (select e.key, jsonb_agg(distinct p.value) parts
              from jsonb_each(case when jsonb_typeof(raw) = 'object' then raw else '{}'::jsonb end) e
              cross join lateral jsonb_array_elements_text(
                case when jsonb_typeof(e.value) = 'array' then e.value else '[]'::jsonb end) p
             where e.key in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')
               and p.value in ('morning', 'afternoon', 'evening')
             group by e.key) d), '{}'::jsonb), '{}'::jsonb);
$$;
revoke all on function public.circle_clean_slots(jsonb) from public, anon, authenticated;

do $$
declare
  fixes text[][] := array[
    ['circle_action_before_hardening(text, jsonb)',
     '''life_context_other'',nullif(left(trim(coalesce(payload->>''life_context_other'','''')),80),''''));',
     '''life_context_other'',nullif(left(trim(coalesce(payload->>''life_context_other'','''')),80),''''),''coffee_slots'',public.circle_clean_slots(payload->''coffee_slots''));'],
    ['circle_coffee_slot(uuid, uuid, uuid, date, date)',
     'select coalesce(answers->''availability_slots'', ''{}''::jsonb), answers->>''gender'' into sx, gx',
     'select coalesce(answers->''coffee_slots'', answers->''availability_slots'', ''{}''::jsonb), answers->>''gender'' into sx, gx'],
    ['circle_coffee_slot(uuid, uuid, uuid, date, date)',
     'select coalesce(answers->''availability_slots'', ''{}''::jsonb), answers->>''gender'' into sy, gy',
     'select coalesce(answers->''coffee_slots'', answers->''availability_slots'', ''{}''::jsonb), answers->>''gender'' into sy, gy'],
    ['circle_action(text, jsonb)',
     'if coalesce(payload->>''answer'', '''') not in (''yes'', ''no'') then raise exception ''Choose yes or no.''; end if;',
     'if coalesce(payload->>''answer'', '''') not in (''yes'', ''no'', ''have'') then raise exception ''Choose an answer.''; end if;']];
  d text;
begin
  for i in 1 .. array_length(fixes, 1) loop
    d := pg_get_functiondef(('public.' || fixes[i][1])::regprocedure);
    if position(fixes[i][3] in d) = 0 then
      if position(fixes[i][2] in d) = 0 then
        raise exception 'times-and-whatsapp patch % did not apply: %', i, fixes[i][1];
      end if;
      execute replace(d, fixes[i][2], fixes[i][3]);
    end if;
  end loop;
end;
$$;

-- 2. Other times go to the organiser ----------------------------------------------------
create or replace function public.circle_notify_other_times()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare note text := nullif(trim(coalesce(new.answers->>'other_times', '')), '');
begin
  if note is not null and note is distinct from nullif(trim(coalesce(
       case when tg_op = 'UPDATE' then old.answers->>'other_times' end, '')), '') then
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select a.profile_id, 'support', 'Someone needs other times',
           coalesce(nullif(trim(new.answers->>'name'), ''), 'An applicant') || ': “' || left(note, 300)
             || '”. Get in touch with them.',
           'other-times:' || new.profile_id || ':' || md5(note)
      from public.circle_admins a
    on conflict do nothing;
  end if;
  return null;
end;
$$;
revoke all on function public.circle_notify_other_times() from public, anon, authenticated;
drop trigger if exists circle_notify_other_times on public.circle_applications;
create trigger circle_notify_other_times after insert or update of answers on public.circle_applications
  for each row execute function public.circle_notify_other_times();

-- 3. "We already have a group" ----------------------------------------------------------
alter table public.circle_whatsapp drop constraint if exists circle_whatsapp_answer_check;
alter table public.circle_whatsapp add constraint circle_whatsapp_answer_check
  check (answer in ('yes', 'no', 'have'));
