-- 1. "Evening" now means 18:00–22:00 (it was 17:00–22:00): a meetup counts
--    as an evening one when it starts between 18:00 and 20:00. Morning and
--    afternoon are unchanged. The existing Circle meets at 19:00.
-- 2. admin@vriendtime.com becomes an organiser, so organiser alerts (safety
--    reports, overdue payments, "Circles can be formed") reach a real inbox.
--    Sign up in the app with admin@vriendtime.com BEFORE running this; if
--    that account does not exist yet, step 2 does nothing.
begin;

create or replace function public.circle_time_period(t time without time zone)
returns text
language sql
immutable
set search_path to 'public'
as $$
 select case when t between time '09:00' and time '10:00' then 'morning'
             when t between time '12:00' and time '15:00' then 'afternoon'
             when t between time '18:00' and time '20:00' then 'evening' end;
$$;

insert into public.circle_admins(profile_id)
select id from public.profiles where lower(email) = 'admin@vriendtime.com'
on conflict do nothing;

commit;
