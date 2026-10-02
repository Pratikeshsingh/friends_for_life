begin;
alter table public.notifications add column email_lease_until timestamptz,
 add column email_lease_token uuid, add column email_first_claimed_at timestamptz,
 add column email_retry_at timestamptz, add column email_snapshot jsonb;
alter function public.notifications_pending_email(integer) rename to notifications_pending_email_legacy;
revoke all on function public.notifications_pending_email_legacy(integer) from public,anon,authenticated,service_role;
create function public.notifications_pending_email(max_rows integer default 50)
returns table(id uuid,email text,first_name text,kind text,title text,body text,lease_token uuid)
language plpgsql security definer set search_path=public as $$
begin
 -- Never retry an uncertain send after the provider's 24-hour dedupe window.
 update public.notifications set email_error='Delivery needs manual review: retry window expired.'
  where emailed_at is null and email_first_claimed_at<now()-interval '23 hours';
 return query
 with candidates as (
  select n.id from public.notifications n join public.profiles p on p.id=n.recipient_profile_id
  left join public.notification_settings s on s.profile_id=n.recipient_profile_id
  where n.emailed_at is null and n.email_attempts<5 and n.created_at>now()-interval '3 days'
   and (n.email_first_claimed_at is null or n.email_first_claimed_at>now()-interval '23 hours')
   and (n.email_lease_until is null or n.email_lease_until<now())
   and (n.email_retry_at is null or n.email_retry_at<=now()) and p.email is not null and coalesce(s.email_enabled,true)
  order by n.created_at limit greatest(1,least(coalesce(max_rows,50),50)) for update of n skip locked
 ), claimed as (
  update public.notifications n set email_lease_until=now()+interval '5 minutes',email_lease_token=gen_random_uuid(),
   email_first_claimed_at=coalesce(n.email_first_claimed_at,now()),email_attempts=n.email_attempts+1,
   email_snapshot=coalesce(n.email_snapshot,jsonb_build_object('email',p.email,'first_name',p.first_name,'kind',n.kind,'title',n.title,'body',n.body))
  from candidates c, public.profiles p where n.id=c.id and p.id=n.recipient_profile_id returning n.*
 ) select c.id,c.email_snapshot->>'email',c.email_snapshot->>'first_name',c.email_snapshot->>'kind',c.email_snapshot->>'title',c.email_snapshot->>'body',c.email_lease_token from claimed c;
end;$$;
revoke all on function public.notifications_pending_email(integer) from public,anon,authenticated;
grant execute on function public.notifications_pending_email(integer) to service_role;
create function public.ack_notification_email(notification_id uuid,lease_token uuid,failure text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 update public.notifications n set emailed_at=case when failure is null then now() else null end,
  email_error=left(failure,300),email_lease_until=null,email_lease_token=null,
  email_retry_at=case when failure is null then null else now()+interval '5 minutes'*power(2,least(n.email_attempts,5)) end
 where n.id=notification_id and n.email_lease_token=lease_token;
 if not found then raise exception 'Email lease expired or was replaced.'; end if;
end;$$;
revoke all on function public.ack_notification_email(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ack_notification_email(uuid,uuid,text) to service_role;
-- Retire the unsafe acknowledgement route for workers running old code.
revoke all on function public.mark_notifications_emailed(uuid[],text) from service_role;
commit;
