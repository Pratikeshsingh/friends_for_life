begin;
-- Apply message restrictions to direct table writes as well as the app RPC.
create function public.guard_circle_message() returns trigger language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 select circle_id into cid from public.chat_threads where id=new.thread_id;
 if cid is not null then
  if not exists(select 1 from public.circle_memberships m join public.circles c on c.id=m.circle_id where m.circle_id=cid and m.profile_id=new.sender_id and m.status='joined' and m.payment_status='paid' and c.status in ('active','completed')) then raise exception 'An active paid membership is required.'; end if;
  if length(trim(new.body)) not between 1 and 2000 then raise exception 'Messages must be 1–2000 characters.'; end if;
  if (select count(*) from public.messages where sender_id=new.sender_id and created_at>now()-interval '1 minute')>=12 then raise exception 'Please wait a moment before sending more messages.'; end if;
 end if;
 return new;
end;$$;
revoke all on function public.guard_circle_message() from public,anon,authenticated;
create trigger guard_circle_message before insert on public.messages for each row execute function public.guard_circle_message();
-- The production project has pg_cron; disposable databases can omit it.
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('vriendtime-circle-notifications','15 * * * *','select public.queue_circle_notifications();');
 end if;
end $$;
commit;
