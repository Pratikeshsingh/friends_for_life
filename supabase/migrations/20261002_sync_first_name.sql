-- One first name, the same everywhere.
--
-- The name lived in three places that drifted apart: profiles.first_name
-- (what the app shows), the Circle application answers, and the sign-in
-- account's metadata (where Supabase's "Display name" column looks).
-- profiles.first_name is now the source: whenever it is set, the first letter
-- is capitalised, and the answers and sign-in metadata follow. This covers
-- every screen that edits a name, old or new.
begin;

-- Capitalise on the way in: "robin" becomes "Robin". Only the first letter
-- changes, so "Marie-louise" or "McKenzie" keep the rest as typed.
create or replace function public.circle_case_first_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.first_name is not null then
    new.first_name := public.circle_name_case(new.first_name);
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_case_first_name on public.profiles;
create trigger profiles_case_first_name
before insert or update of first_name on public.profiles
for each row execute function public.circle_case_first_name();

-- Copy a changed name to the Circle answers and the sign-in account.
create or replace function public.circle_sync_first_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.first_name, '') = ''
     or new.first_name is not distinct from old.first_name then
    return new;
  end if;
  update public.circle_applications
     set answers = answers || jsonb_build_object('name', new.first_name)
   where profile_id = new.id
     and answers->>'name' is distinct from new.first_name;
  update auth.users
     set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
         || jsonb_build_object('first_name', new.first_name,
                               'display_name', new.first_name)
   where id = new.id;
  return new;
end;
$$;

revoke all on function public.circle_sync_first_name() from public, anon, authenticated;
revoke all on function public.circle_case_first_name() from public, anon, authenticated;

drop trigger if exists profiles_sync_first_name on public.profiles;
create trigger profiles_sync_first_name
after update of first_name on public.profiles
for each row execute function public.circle_sync_first_name();

-- Bring existing accounts in line.
-- 1. Profiles without a name take the one from their Circle answers.
update public.profiles p
   set first_name = a.answers->>'name'
  from public.circle_applications a
 where a.profile_id = p.id
   and coalesce(p.first_name, '') = ''
   and coalesce(a.answers->>'name', '') <> '';

-- 2. Capitalise every profile name; the trigger above syncs the answers.
update public.profiles
   set first_name = public.circle_name_case(first_name)
 where coalesce(first_name, '') <> ''
   and first_name <> public.circle_name_case(first_name);

-- 3. Names that were already capitalised did not change, so copy them
--    across explicitly as well.
update public.circle_applications a
   set answers = a.answers || jsonb_build_object('name', p.first_name)
  from public.profiles p
 where p.id = a.profile_id
   and coalesce(p.first_name, '') <> ''
   and a.answers->>'name' is distinct from p.first_name;

update auth.users u
   set raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb)
       || jsonb_build_object('first_name', p.first_name,
                             'display_name', p.first_name)
  from public.profiles p
 where p.id = u.id
   and coalesce(p.first_name, '') <> ''
   and (u.raw_user_meta_data->>'first_name' is distinct from p.first_name
        or u.raw_user_meta_data->>'display_name' is distinct from p.first_name);

commit;
