create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text unique,
  first_name text,
  phone text,
  address text,
  city text,
  date_of_birth date,
  gender text,
  language text,
  availability text,
  energy text,
  group_preference text,
  conversation_goals text,
  dietary_notes text,
  interests text[] not null default '{}',
  selected_event_ids text[] not null default '{}',
  has_profile_photo boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles
  add column if not exists profile_photo_path text,
  add column if not exists profile_photo_name text,
  add column if not exists secondary_photo_path text,
  add column if not exists secondary_photo_name text;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  city text not null,
  venue_area text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  capacity integer not null check (capacity > 0),
  status text not null default 'draft' check (status in ('draft', 'open', 'full', 'closed', 'cancelled')),
  host_profile_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.events
  add column if not exists description text,
  add column if not exists activity_type text,
  add column if not exists vibe text,
  add column if not exists minimum_attendees integer not null default 4,
  add column if not exists confirmed_count integer not null default 0,
  add column if not exists tags text[] not null default '{}',
  add column if not exists languages text[] not null default '{}',
  add column if not exists price_note text,
  add column if not exists venue_name text,
  add column if not exists venue_address text,
  add column if not exists reveal_venue_at timestamptz,
  add column if not exists image_url text,
  add column if not exists is_featured boolean not null default false;

create table if not exists public.event_attendees (
  event_id uuid not null references public.events (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'joined' check (status in ('joined', 'cancelled', 'waitlist', 'no_show')),
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (event_id, profile_id)
);

alter table public.event_attendees
  drop constraint if exists event_attendees_status_check;

alter table public.event_attendees
  add constraint event_attendees_status_check
  check (status in ('joined', 'cancelled', 'waitlist', 'no_show'));

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  event_id uuid unique references public.events (id) on delete cascade,
  title text not null,
  kind text not null default 'event' check (kind in ('event', 'direct', 'group')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.chat_participants (
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (thread_id, profile_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) > 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.interest_options (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.city_options (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

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

insert into public.city_options (label, sort_order)
values
  ('Alkmaar', 10),
  ('Amsterdam', 20),
  ('Haarlem', 30),
  ('Utrecht', 40)
on conflict (label) do nothing;

insert into public.interest_options (label, sort_order, is_active)
values
  ('Coffee', 10, true),
  ('Lunch', 20, true),
  ('Dinner', 30, true)
on conflict (label) do update
set
  sort_order = excluded.sort_order,
  is_active = true;

update public.interest_options
set is_active = false
where label not in ('Coffee', 'Lunch', 'Dinner');

insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', false)
on conflict (id) do nothing;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.validate_profile_age()
returns trigger
language plpgsql
as $$
begin
  if new.date_of_birth is not null
    and new.date_of_birth > (current_date - interval '18 years')::date then
    raise exception 'Members must be at least 18 years old.';
  end if;

  return new;
end;
$$;

create or replace function public.email_exists(check_email text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  return exists (
    select 1
    from auth.users
    where lower(email) = lower(check_email)
  );
end;
$$;

revoke all on function public.email_exists(text) from public;
grant execute on function public.email_exists(text) to anon, authenticated;

create or replace function public.refresh_event_confirmed_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  target_event_id := coalesce(new.event_id, old.event_id);

  update public.events
  set confirmed_count = (
    select count(*)
    from public.event_attendees
    where event_id = target_event_id
      and status = 'joined'
  )
  where id = target_event_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists profiles_validate_age on public.profiles;
create trigger profiles_validate_age
before insert or update on public.profiles
for each row
execute function public.validate_profile_age();

drop trigger if exists event_attendees_refresh_count on public.event_attendees;
create trigger event_attendees_refresh_count
after insert or update or delete on public.event_attendees
for each row
execute function public.refresh_event_confirmed_count();

update public.events
set confirmed_count = counts.confirmed_count
from (
  select
    event_id,
    count(*) filter (where status = 'joined')::integer as confirmed_count
  from public.event_attendees
  group by event_id
) counts
where counts.event_id = public.events.id;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    first_name,
    phone,
    address,
    city,
    date_of_birth,
    gender,
    language,
    availability,
    energy,
    group_preference,
    conversation_goals,
    dietary_notes,
    interests,
    selected_event_ids,
    profile_photo_path,
    profile_photo_name,
    secondary_photo_path,
    secondary_photo_name,
    has_profile_photo
  )
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'first_name',
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'address',
    new.raw_user_meta_data ->> 'city',
    nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date,
    new.raw_user_meta_data ->> 'gender',
    new.raw_user_meta_data ->> 'language',
    new.raw_user_meta_data ->> 'availability',
    new.raw_user_meta_data ->> 'energy',
    new.raw_user_meta_data ->> 'group_preference',
    new.raw_user_meta_data ->> 'conversation_goals',
    new.raw_user_meta_data ->> 'dietary_notes',
    coalesce(
      array(
        select jsonb_array_elements_text(coalesce(new.raw_user_meta_data -> 'interests', '[]'::jsonb))
      ),
      '{}'
    ),
    coalesce(
      array(
        select jsonb_array_elements_text(coalesce(new.raw_user_meta_data -> 'selected_event_ids', '[]'::jsonb))
      ),
      '{}'
    ),
    new.raw_user_meta_data ->> 'profile_photo_path',
    new.raw_user_meta_data ->> 'profile_photo_name',
    new.raw_user_meta_data ->> 'secondary_photo_path',
    new.raw_user_meta_data ->> 'secondary_photo_name',
    coalesce((new.raw_user_meta_data ->> 'has_profile_photo')::boolean, false)
  )
  on conflict (id) do update
  set
    email = excluded.email,
    first_name = excluded.first_name,
    phone = excluded.phone,
    address = excluded.address,
    city = excluded.city,
    date_of_birth = excluded.date_of_birth,
    gender = excluded.gender,
    language = excluded.language,
    availability = excluded.availability,
    energy = excluded.energy,
    group_preference = excluded.group_preference,
    conversation_goals = excluded.conversation_goals,
    dietary_notes = excluded.dietary_notes,
    interests = excluded.interests,
    selected_event_ids = excluded.selected_event_ids,
    profile_photo_path = excluded.profile_photo_path,
    profile_photo_name = excluded.profile_photo_name,
    secondary_photo_path = excluded.secondary_photo_path,
    secondary_photo_name = excluded.secondary_photo_name,
    has_profile_photo = excluded.has_profile_photo;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_attendees enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.messages enable row level security;
alter table public.interest_options enable row level security;
alter table public.city_options enable row level security;

drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "authenticated can read open events" on public.events;
create policy "authenticated can read open events"
on public.events
for select
to anon, authenticated
using (status in ('open', 'full', 'closed'));

drop policy if exists "everyone can read active interest options" on public.interest_options;
create policy "everyone can read active interest options"
on public.interest_options
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "everyone can read active city options" on public.city_options;
create policy "everyone can read active city options"
on public.city_options
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "users can read own event attendance" on public.event_attendees;
create policy "users can read own event attendance"
on public.event_attendees
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "users can join themselves to events" on public.event_attendees;
create policy "users can join themselves to events"
on public.event_attendees
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "users can update own event attendance" on public.event_attendees;
create policy "users can update own event attendance"
on public.event_attendees
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "participants can read threads" on public.chat_threads;
create policy "participants can read threads"
on public.chat_threads
for select
to authenticated
using (
  exists (
    select 1
    from public.chat_participants participants
    where participants.thread_id = id
      and participants.profile_id = auth.uid()
  )
);

drop policy if exists "participants can read chat participants" on public.chat_participants;
create policy "participants can read chat participants"
on public.chat_participants
for select
to authenticated
using (
  profile_id = auth.uid()
  or exists (
    select 1
    from public.chat_participants participants
    where participants.thread_id = thread_id
      and participants.profile_id = auth.uid()
  )
);

drop policy if exists "participants can read messages" on public.messages;
create policy "participants can read messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.chat_participants participants
    where participants.thread_id = messages.thread_id
      and participants.profile_id = auth.uid()
  )
);

drop policy if exists "participants can send messages" on public.messages;
create policy "participants can send messages"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.chat_participants participants
    where participants.thread_id = messages.thread_id
      and participants.profile_id = auth.uid()
  )
);

drop policy if exists "users can read own profile photos" on storage.objects;
create policy "users can read own profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can upload own profile photos" on storage.objects;
create policy "users can upload own profile photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can update own profile photos" on storage.objects;
create policy "users can update own profile photos"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "users can delete own profile photos" on storage.objects;
create policy "users can delete own profile photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
