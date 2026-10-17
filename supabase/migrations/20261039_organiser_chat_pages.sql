-- The organiser reads a Circle's whole chat, not only the latest 200.
--
-- circle_admin_messages_before(circle, time, id) returns the 200 messages
-- before the given one, oldest first, in the same shape as
-- circle_admin_messages. Read-only; organisers only.
-- Can run again safely.

create or replace function public.circle_admin_messages_before(
  target_circle uuid, before_time timestamptz, before_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  return coalesce((
    select jsonb_agg(x.item order by x.created_at, x.id) from (
      select msg.created_at, msg.id, jsonb_build_object(
               'id', msg.id, 'created_at', msg.created_at,
               'name', case when msg.kind = 'system' then 'VriendTime' else coalesce(p.first_name, 'Member') end,
               'body', msg.body, 'system', msg.kind = 'system') item
        from public.messages msg
        join public.chat_threads t on t.id = msg.thread_id
        left join public.profiles p on p.id = msg.sender_id
       where t.circle_id = target_circle
         and (msg.created_at, msg.id) < (before_time, before_id)
       order by msg.created_at desc, msg.id desc limit 200) x), '[]'::jsonb);
end;
$$;
revoke all on function public.circle_admin_messages_before(uuid, timestamptz, uuid) from public, anon;
grant execute on function public.circle_admin_messages_before(uuid, timestamptz, uuid) to authenticated;
