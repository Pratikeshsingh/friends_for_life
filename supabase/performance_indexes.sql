create index if not exists events_status_starts_at_idx
on public.events (status, starts_at);

create index if not exists event_attendees_profile_status_idx
on public.event_attendees (profile_id, status);

create index if not exists event_attendees_event_status_idx
on public.event_attendees (event_id, status);

create index if not exists chat_participants_profile_thread_idx
on public.chat_participants (profile_id, thread_id);

create index if not exists messages_thread_created_at_idx
on public.messages (thread_id, created_at desc);
