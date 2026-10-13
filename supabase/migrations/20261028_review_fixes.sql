-- Review fixes.
-- 1. "Running late" says what it is about: "…for my coffee with Anna" or
--    "…for “Find out who’s secretly competitive”".
-- 2. The survey after week six also accepts an honest "No".
begin;
do $$
declare d text := pg_get_functiondef('public.circle_action(text, jsonb)'::regprocedure);
begin
  d := replace(d, '''Ik ben ongeveer '' || minutes || '' minuten later voor onze koffie, '' || other_name || ''.''',
                  '''Ik ben ongeveer '' || minutes || '' minuten later voor mijn koffie met '' || other_name || ''.''');
  d := replace(d, '''Running about '' || minutes || '' minutes late for our coffee, '' || other_name || ''.''',
                  '''Running about '' || minutes || '' minutes late for my coffee with '' || other_name || ''.''');
  d := replace(d, '''Ik ben ongeveer '' || minutes || '' minuten later.''',
                  '''Ik ben ongeveer '' || minutes || '' minuten later voor “'' || e.title || ''”.''');
  d := replace(d, '''Running about '' || minutes || '' minutes late.''',
                  '''Running about '' || minutes || '' minutes late for “'' || e.title || ''”.''');
  if position('for my coffee with' in d) = 0 or position('late for “''' in d) = 0 then
    raise exception 'running late patch did not apply';
  end if;
  execute d;

  d := pg_get_functiondef('public.circle_action_core(text, jsonb)'::regprocedure);
  d := replace(d, 'x.value not in (''Yes'',''Not yet'')', 'x.value not in (''Yes'',''Not yet'',''No'')');
  d := replace(d, 'Choose Yes or Not yet for the outcome questions.', 'Choose Yes, Not yet or No for the outcome questions.');
  if position('''Not yet'',''No''' in d) = 0 then raise exception 'outcome patch did not apply'; end if;
  execute d;
end;
$$;
-- 3. The 90-day question is no longer only yes or not yet.
do $$
declare d text := pg_get_functiondef('public.circle_notification_copy()'::regprocedure);
begin
  d := replace(d, 'Answer four quick yes-or-not-yet questions about whether you’re still in touch.',
                  'Answer four quick questions about whether you’re still in touch.');
  if position('Answer four quick questions' in d) = 0 then raise exception 'notification copy patch did not apply'; end if;
  execute d;
end;
$$;
commit;
