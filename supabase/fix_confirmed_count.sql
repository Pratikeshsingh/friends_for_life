create or replace function public.refresh_event_confirmed_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  target_event_id := coalesce(new.event_id, old.event_id);

  update public.events
  set confirmed_count = (
    select count(*)
    from public.event_attendees
    where event_id = target_event_id
      and status = 'joined'
  )
  where id = target_event_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists event_attendees_refresh_count on public.event_attendees;

create trigger event_attendees_refresh_count
after insert or update or delete on public.event_attendees
for each row
execute function public.refresh_event_confirmed_count();

update public.events e
set confirmed_count = counts.joined_count
from (
  select
    event_id,
    count(*) filter (where status = 'joined')::integer as joined_count
  from public.event_attendees
  group by event_id
) counts
where e.id = counts.event_id;

update public.events
set confirmed_count = 0
where id not in (
  select distinct event_id
  from public.event_attendees
  where status = 'joined'
);
