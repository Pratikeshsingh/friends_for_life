-- A place can't be released while the member says they've paid: check the
-- payment first (Tikkie or bank), then confirm it or release the place.
-- Prevents money arriving for a place that was just given away.
begin;
do $$
declare d text := pg_get_functiondef('public.circle_admin_release_place(uuid, uuid)'::regprocedure);
begin
  d := regexp_replace(d,
    '(raise exception ''Only an unpaid place can be released\.'';\s*end if;)',
    E'\\1\n  if exists (select 1 from public.circle_payments p\n              where p.profile_id = member and p.circle_id = target_circle\n                and p.status = ''awaiting_payment'' and p.payment_reported_at is not null) then\n    raise exception ''This member says they’ve paid. Check Tikkie first, then confirm or release.'';\n  end if;');
  if position('says they’ve paid. Check Tikkie first' in d) = 0 then
    raise exception 'release guard patch did not apply';
  end if;
  execute d;
end;
$$;
commit;
