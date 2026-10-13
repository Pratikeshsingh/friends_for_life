-- A coffee stops being "this week's coffee" an hour after it starts, before
-- "How was your coffee?" appears (90 minutes after), so the two never show
-- together.
begin;
do $$
declare d text := pg_get_functiondef('public.circle_snapshot()'::regprocedure);
begin
  d := replace(d, 'and k.starts_at > now() - interval ''3 hours''', 'and k.starts_at > now() - interval ''1 hour''');
  if position('k.starts_at > now() - interval ''1 hour''' in d) = 0 then
    raise exception 'snapshot patch did not apply';
  end if;
  execute d;
end;
$$;
commit;
