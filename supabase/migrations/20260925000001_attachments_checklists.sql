-- MotoLog schema v4: attachments + checklists (templates and records), and
-- the private Storage bucket that holds attachment files.
--
-- Same conventions as 20260924000001_sync_tables.sql (read its header):
-- same snake_case columns as the app's local SQLite tables, plus owner_id
-- and server_updated_at; primary key (owner_id, id) (the default checklist
-- template has a deterministic "seed:..." id in every install); no foreign
-- keys between tables; last-write-wins via public.sync_before_write().
--
-- The local-only table `attachment_files` (the on-device bytes) is NOT
-- mirrored here: the files themselves go to Storage, bucket "attachments",
-- at <owner_id>/<attachment_id>/<file_name>.
--
-- Requires 20260924000001_sync_tables.sql (for sync_before_write()).
-- Run it once in the Supabase SQL editor, or with `supabase db push`.
-- Safe to re-run (idempotent).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.checklist_forms (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  name text not null,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.checklist_form_items (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  form_id text not null,
  "position" integer not null,
  label text not null,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.checklists (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  "date" timestamptz not null,
  odometer double precision,
  form_id text,
  title text not null,
  driver text,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.checklist_answers (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  checklist_id text not null,
  "position" integer not null,
  label text not null,
  status text,
  note text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.attachments (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text,
  parent_table text not null,
  parent_id text not null,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null,
  storage_path text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

-- ---------------------------------------------------------------------------
-- Row-level security, pull index, last-write-wins trigger and grants
-- (identical to the v3 tables)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'checklist_forms', 'checklist_form_items', 'checklists',
    'checklist_answers', 'attachments'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_select_own', t);
    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using (owner_id = (select auth.uid()))',
      t || '_select_own', t);

    execute format('drop policy if exists %I on public.%I', t || '_insert_own', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      'with check (owner_id = (select auth.uid()))',
      t || '_insert_own', t);

    execute format('drop policy if exists %I on public.%I', t || '_update_own', t);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      'using (owner_id = (select auth.uid())) '
      'with check (owner_id = (select auth.uid()))',
      t || '_update_own', t);

    execute format('drop policy if exists %I on public.%I', t || '_delete_own', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      'using (owner_id = (select auth.uid()))',
      t || '_delete_own', t);

    execute format(
      'create index if not exists %I on public.%I '
      '(owner_id, server_updated_at, id)',
      t || '_owner_server_updated_at_idx', t);

    execute format('drop trigger if exists %I on public.%I', t || '_sync_before_write', t);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.sync_before_write()',
      t || '_sync_before_write', t);

    execute format(
      'grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: private bucket for attachment files
-- ---------------------------------------------------------------------------

-- 10 MB per file (the app rejects bigger files and compresses photos);
-- images and PDFs only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic',
        'image/heif', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Owner-only: object keys start with the user's id
-- (<uid>/<attachment_id>/<file_name>), so the first folder must be auth.uid().
-- Account deletion removes the files through the Storage API from the app
-- first (Supabase blocks `delete from storage.objects` in SQL).
drop policy if exists "attachments_select_own" on storage.objects;
create policy "attachments_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "attachments_insert_own" on storage.objects;
create policy "attachments_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "attachments_update_own" on storage.objects;
create policy "attachments_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "attachments_delete_own" on storage.objects;
create policy "attachments_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
