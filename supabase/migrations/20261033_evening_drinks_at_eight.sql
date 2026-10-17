-- Evening one-to-ones start at 20:00, after dinner, as daytime coffees start
-- at 14:00 after lunch: the places are quieter and a table is easier to find.
-- Coffees already planned keep their time. One statement, safe to run again.
do $$
declare d text := pg_get_functiondef('public.circle_coffee_slot(uuid, uuid, uuid, date, date)'::regprocedure);
begin
  if position('else time ''20:00'' end' in d) = 0 then
    if position('else time ''19:00'' end' in d) = 0 then
      raise exception 'evening time patch did not apply';
    end if;
    execute replace(d, 'else time ''19:00'' end', 'else time ''20:00'' end');
  end if;
end;
$$;
