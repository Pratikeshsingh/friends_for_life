-- An applicant may give only their own times ("Mondays after 22:00") when
-- none of the offered slots fit. They join the waiting list like anyone
-- else; the organiser sees their times and can add a slot if enough people
-- need the same one.
begin;
do $$
declare d text := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
begin
  d := replace(d, 'or coalesce(jsonb_array_length(payload->''availability''),0)=0',
                  'or (coalesce(jsonb_array_length(payload->''availability''),0)=0 and coalesce(length(trim(payload->>''other_times'')),0)=0)');
  if position('payload->>''other_times''' in d) = 0 then raise exception 'other times patch did not apply'; end if;
  execute d;
end;
$$;
commit;
