-- Disposable Supabase-shaped auth/storage schema. No external connections.
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create schema storage;
create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}', created_at timestamptz default now());
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid default gen_random_uuid() primary key,bucket_id text,name text,owner uuid,unique(bucket_id,name));
create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name,'/') $$;
alter table storage.objects enable row level security;
grant usage on schema public,auth,storage to anon,authenticated,service_role;
grant all on all tables in schema auth,storage to service_role;
grant all on storage.objects to authenticated;
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;
