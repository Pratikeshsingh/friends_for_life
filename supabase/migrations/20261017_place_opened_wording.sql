-- 1. "A place opened" is also sent when someone who had accepted gives up
--    their place, so it must not say they "declined the invitation".
-- 2. Someone removed by the organiser sees that, not "You've left".
begin;
create or replace function public.circle_notify_place_opened()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'invited' and new.status = 'left' and not public.circle_is_admin() then
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key)
    select a.profile_id, 'support', 'A place opened in a Circle',
           coalesce((select first_name from public.profiles where id = new.profile_id), 'Someone')
             || ' is no longer joining ' || coalesce((select name from public.circles where id = new.circle_id), 'a Circle')
             || '. Invite someone from the Circles tab.',
           'place-opened:' || new.circle_id || ':' || new.profile_id
      from public.circle_admins a
    on conflict do nothing;
  end if;
  return null;
end;
$$;
revoke all on function public.circle_notify_place_opened() from public, anon, authenticated;
do $$
declare d text := pg_get_functiondef('public.circle_snapshot()'::regprocedure);
begin
  d := replace(d, 'select c.name, r.status as refund, a.status as app',
                  'select c.id, c.name, r.status as refund, a.status as app');
  d := replace(d, 'jsonb_build_object(''name'', last_left.name, ''refund'', last_left.refund)',
                  'jsonb_build_object(''name'', last_left.name, ''refund'', last_left.refund,
          ''removed'', exists (select 1 from public.circle_audit au
                               where au.action = ''remove_member'' and au.target_id = last_left.id
                                 and au.details like uid::text || '':%''))');
  if position('''removed''' in d) = 0 then raise exception 'snapshot patch did not apply'; end if;
  execute d;
end;
$$;

commit;
