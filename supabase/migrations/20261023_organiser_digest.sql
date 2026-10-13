-- One organiser email instead of one per alert.
--
-- Organiser alerts are no longer emailed one by one. At 09:00, 13:00 and
-- 18:00 (Netherlands time) each organiser gets one "Things to do in
-- VriendTime" email, but only when something new came in since the last one:
--   * live counts: payments to confirm, refund requests, open reports
--     (so anything already handled is not listed);
--   * the other new alerts the organiser hasn't opened in the app yet.
-- Safety reports ("A member reported a concern") are still emailed at once.
-- In the app every alert still shows on its own.
begin;

-- The email queue skips organiser alerts, except safety reports and the digest.
do $$
declare d text := pg_get_functiondef('public.notifications_pending_email_v2(integer)'::regprocedure);
begin
  d := replace(d, '       and p.email is not null
',
'       and p.email is not null
       and not (n.kind = ''support'' and n.title <> ''A member reported a concern''
                and coalesce(n.metadata->>''digest'', '''') <> ''true''
                and exists (select 1 from public.circle_admins ca where ca.profile_id = n.recipient_profile_id))
');
  if position('A member reported a concern' in d) = 0 then
    raise exception 'email queue patch did not apply';
  end if;
  execute d;
end;
$$;

create or replace function public.queue_organiser_digest(force boolean default false)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
  lines text[];
  n_pay integer; n_ref integer; n_rep integer;
  added integer := 0;
begin
  if not force and extract(hour from now() at time zone 'Europe/Amsterdam') not in (9, 13, 18) then
    return 0;
  end if;
  select count(*) into n_pay from public.circle_payments
   where status = 'awaiting_payment' and payment_reported_at is not null;
  select count(*) into n_ref from public.circle_refund_requests where status = 'requested';
  select count(*) into n_rep from public.circle_reports where resolved_at is null;

  for a in select ca.profile_id from public.circle_admins ca
             left join public.notification_settings s on s.profile_id = ca.profile_id
            where coalesce(s.email_organiser, true) loop
    -- Only when something new came in since the last email.
    continue when not exists (
      select 1 from public.notifications n
       where n.recipient_profile_id = a.profile_id and n.kind = 'support' and n.emailed_at is null
         and n.title <> 'A member reported a concern' and coalesce(n.metadata->>'digest', '') <> 'true'
         and n.created_at > now() - interval '3 days');
    lines := '{}';
    if n_pay > 0 then
      lines := lines || (n_pay || case when n_pay = 1 then ' payment to confirm' else ' payments to confirm' end);
    end if;
    if n_ref > 0 then
      lines := lines || (n_ref || case when n_ref = 1 then ' refund request to review' else ' refund requests to review' end);
    end if;
    if n_rep > 0 then
      lines := lines || (n_rep || case when n_rep = 1 then ' open report' else ' open reports' end);
    end if;
    -- Other new alerts, unless already opened in the app. Payments and
    -- refunds are covered by the counts above.
    lines := lines || array(
      select n.title || ': ' || n.body
        from public.notifications n
       where n.recipient_profile_id = a.profile_id and n.kind = 'support' and n.emailed_at is null
         and n.read_at is null and coalesce(n.metadata->>'digest', '') <> 'true'
         and n.created_at > now() - interval '3 days'
         and n.title not in ('A member reported a concern', 'Someone says they paid',
                             'Payment needs verification', 'A member asked for a refund')
       order by n.created_at
       limit 10);
    update public.notifications n set emailed_at = now()
     where n.recipient_profile_id = a.profile_id and n.kind = 'support' and n.emailed_at is null
       and n.title <> 'A member reported a concern' and coalesce(n.metadata->>'digest', '') <> 'true';
    continue when coalesce(array_length(lines, 1), 0) = 0;
    insert into public.notifications(recipient_profile_id, kind, title, body, dedupe_key, metadata, read_at)
    values (a.profile_id, 'support', 'Things to do in VriendTime',
            '• ' || array_to_string(lines, E'\n• '),
            'digest:' || a.profile_id || ':' || to_char(now() at time zone 'Europe/Amsterdam', 'YYYY-MM-DD-HH24'),
            jsonb_build_object('digest', true, 'open', 'organiser:todo'), now())
    on conflict do nothing;
    added := added + 1;
  end loop;
  return added;
end;
$$;
revoke all on function public.queue_organiser_digest(boolean) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('vriendtime-organiser-digest', '0 * * * *', 'select public.queue_organiser_digest();');
  end if;
end;
$$;

commit;
