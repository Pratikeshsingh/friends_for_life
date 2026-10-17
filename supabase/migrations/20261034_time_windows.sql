-- Meetups as time windows, and morning and afternoon plans.
--
-- 1. A Circle meetup runs to the end of its part of the day: morning ones
--    until 12:00, afternoon ones until 16:00, evening ones until 22:00
--    (never less than an hour and a half). So 10:30–12:00, 14:00–16:00 and
--    19:00–22:00: an end time for reservations, and people can stay longer.
--    Planned meetups that still had the old two hours get the new end too.
--    Extra meetups the group adds keep two hours.
-- 2. The daytime plan is split into a morning plan (week 1: brunch at
--    Hofman, which takes online bookings) and an afternoon plan (week 1:
--    lunch at Rozey, open for lunch Friday to Sunday). Weeks 2–6 start as
--    the daytime plan was. The daytime plan stays for the older app.
-- 3. Rozey's address in the evening plan.
-- Every statement stands alone and can run again safely.

create or replace function public.circle_window_end(starts timestamptz)
returns timestamptz
language sql
stable
set search_path = public
as $$
  select greatest(
           ((starts at time zone 'Europe/Amsterdam')::date
             + case when extract(hour from starts at time zone 'Europe/Amsterdam') < 12 then time '12:00'
                    when extract(hour from starts at time zone 'Europe/Amsterdam') < 17 then time '16:00'
                    else time '22:00' end) at time zone 'Europe/Amsterdam',
           starts + interval '90 minutes');
$$;
revoke all on function public.circle_window_end(timestamptz) from public, anon, authenticated;

-- Creating a Circle and rescheduling a week (patched in place).
do $$
declare
  d text := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
  created text := $o$(((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours'$o$;
  moved text := $o$ends_at=((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')+interval '2 hours'$o$;
begin
  if position('circle_window_end' in d) = 0 then
    if position(created in d) = 0 or position(moved in d) = 0 then
      raise exception 'meetup end patch did not apply';
    end if;
    d := replace(d, created, $n$public.circle_window_end(((proposed_date+(i-1)*7)+proposed_time) at time zone 'Europe/Amsterdam')$n$);
    d := replace(d, moved, $n$ends_at=public.circle_window_end((proposed_date+proposed_time) at time zone 'Europe/Amsterdam')$n$);
    execute d;
  end if;
end;
$$;

-- Moving a week to another day.
do $$
declare
  d text := pg_get_functiondef('public.circle_action_before_moves(text, jsonb)'::regprocedure);
  moved text := $o$ends_at=case when circle_week is not null then ends_at else dt+interval '2 hours' end$o$;
begin
  if position('circle_window_end' in d) = 0 then
    if position(moved in d) = 0 then raise exception 'meetup move patch did not apply'; end if;
    execute replace(d, moved, $n$ends_at=case when circle_week is not null then public.circle_window_end(dt) else dt+interval '2 hours' end$n$);
  end if;
end;
$$;

update public.events
   set ends_at = public.circle_window_end(starts_at)
 where circle_week is not null and starts_at > now()
   and ends_at = starts_at + interval '2 hours';

-- 2. Morning and afternoon plans ------------------------------------------------------
alter table public.circle_programme_template drop constraint if exists circle_programme_template_kind_check;
alter table public.circle_programme_template add constraint circle_programme_template_kind_check
  check (kind in ('morning', 'afternoon', 'daytime', 'evening'));

-- Saving suggestions accepts the new parts of the day (patched in place).
do $$
declare d text := pg_get_functiondef('public.circle_action_before_coffee(text, jsonb)'::regprocedure);
begin
  if position('''morning'', ''afternoon''' in d) = 0 then
    if position('payload->>''kind'' not in (''daytime'', ''evening'')' in d) = 0 then
      raise exception 'suggestions patch did not apply';
    end if;
    execute replace(d, 'payload->>''kind'' not in (''daytime'', ''evening'')',
                       'payload->>''kind'' not in (''morning'', ''afternoon'', ''daytime'', ''evening'')');
  end if;
end;
$$;

insert into public.circle_programme_template(city, kind, week, title, venue, address, cost, booking_name)
select t.city, k.kind, t.week, t.title, t.venue, t.address, t.cost, t.booking_name
  from public.circle_programme_template t
 cross join (values ('morning'), ('afternoon')) k(kind)
 where t.kind = 'daytime'
on conflict (city, kind, week) do nothing;

update public.circle_programme_template
   set title = 'Brunch together', venue = 'Hofman', address = 'Kerkplein 7',
       cost = 'You pay for yourself.', booking_name = null
 where city = 'Alkmaar' and kind = 'morning' and week = 1;

update public.circle_programme_template
   set title = 'Lunch together', venue = 'Rozey Alkmaar', address = 'Gedempte Nieuwesloot 4B',
       cost = 'About €35 per person: all you can eat, drinks included.', booking_name = null
 where city = 'Alkmaar' and kind = 'afternoon' and week = 1;

-- 3. Rozey's address.
update public.circle_programme_template
   set address = 'Gedempte Nieuwesloot 4B'
 where venue = 'Rozey Alkmaar' and address is null;

-- Kaldi's address (week 2 of the daytime plans).
update public.circle_programme_template
   set address = 'Marktstraat 13'
 where venue = 'Kaldi' and address is null;
