-- Flexible themes for weeks 2 and 3; preserve organiser-chosen titles.
begin;
do $migration$
declare definition text;
begin
  definition := pg_get_functiondef('public.circle_action_core(text,jsonb)'::regprocedure);
  if position('''Bowling together'',''A walk & a warm drink''' in definition) = 0 then
    raise exception 'Expected week defaults not found; review circle_action_core before applying.';
  end if;
  execute replace(definition, '''Bowling together'',''A walk & a warm drink''', '''Go beyond “what do you do?”'',''Find out who’s secretly competitive.''');
end;
$migration$;
update public.events set title='Go beyond “what do you do?”'
 where circle_week=2 and title='Bowling together' and completed_at is null;
update public.events set title='Find out who’s secretly competitive.'
 where circle_week=3 and title='A walk & a warm drink' and completed_at is null;
commit;
