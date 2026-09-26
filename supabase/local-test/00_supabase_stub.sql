-- Minimal stand-in for the parts of a Supabase project the migrations use,
-- so they can run on a throwaway LOCAL Postgres (never the live project).
-- Used by tool/sql_test.sh. Not a migration: never run this on Supabase.
--
-- Mirrors: the anon/authenticated/service_role roles, the default
-- privileges Supabase grants on new objects in `public`, auth.users +
-- auth.uid()/auth.email() (read from the request.jwt.claim.sub setting like
-- PostgREST sets it), and storage.buckets/objects + storage.foldername().

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end;
$$;

create extension if not exists citext;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  email_confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.email() returns text
language sql stable as $$
  select u.email from auth.users u where u.id = auth.uid();
$$;

grant execute on function auth.uid() to anon, authenticated, service_role;
grant execute on function auth.email() to anon, authenticated, service_role;

create schema if not exists storage;
grant usage on schema storage to anon, authenticated, service_role;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid,
  metadata jsonb,
  created_at timestamptz default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to anon, authenticated;

create or replace function storage.foldername(name text) returns text[]
language plpgsql as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end;
$$;
grant execute on function storage.foldername(text) to anon, authenticated;
