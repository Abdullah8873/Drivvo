-- MotoLog cloud sync: server-side mirror of the app's local SQLite tables.
--
-- One table per synced local table (same snake_case columns as drift
-- generates), plus:
--   owner_id           the Supabase user who owns the row (auth.uid()).
--   server_updated_at  set by the server on every real write; the app pulls
--                      "rows changed since my cursor" ordered by
--                      (server_updated_at, id).
-- Primary key is (owner_id, id): the default catalog rows use the same
-- deterministic ids ("seed:fuel:petrol", ...) in every install, so ids are
-- only unique per user. There are deliberately NO foreign keys between these
-- tables: rows are soft-deleted (deleted_at) and may arrive out of order.
--
-- Conflict rule (last write wins), enforced by the trigger below so that a
-- plain upsert from any device is always safe to repeat:
--   * an incoming row older than the stored one (updated_at) is ignored;
--   * an identical row with the same updated_at is ignored (re-uploading
--     never bumps server_updated_at, so devices can't ping-pong);
--   * a row with the same updated_at but different data is applied.
--
-- Run it once in the Supabase SQL editor, or with `supabase db push`.
-- Safe to re-run (idempotent).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.vehicles (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  name text not null,
  "type" text not null,
  manufacturer text,
  model text,
  plate text,
  "year" integer,
  tank_count integer not null default 1,
  tank1_kind text not null default 'liquid',
  tank1_capacity double precision,
  tank2_kind text,
  tank2_capacity double precision,
  distance_unit text not null default 'km',
  vin text,
  registration_id text,
  purchase_price double precision,
  sale_price double precision,
  active boolean not null default true,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.catalog_items (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  kind text not null,
  name text not null,
  fuel_kind text,
  address text,
  latitude double precision,
  longitude double precision,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.refuelings (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  "date" timestamptz not null,
  odometer double precision not null,
  full_tank boolean not null default true,
  missed_previous boolean not null default false,
  gas_station_id text,
  payment_method_id text,
  reason_id text,
  driver text,
  discount double precision,
  total_cost double precision not null,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.refueling_fuels (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  refueling_id text not null,
  fuel_id text not null,
  price_per_unit double precision not null,
  total double precision not null,
  volume double precision not null,
  tank integer not null default 1,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.entries (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  kind text not null,
  "date" timestamptz not null,
  odometer double precision,
  title text,
  place_id text,
  payment_method_id text,
  reason_id text,
  driver text,
  discount double precision,
  total_cost double precision not null,
  parent_id text,
  installment_no integer not null default 1,
  installment_count integer not null default 1,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.entry_items (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  entry_id text not null,
  type_id text not null,
  amount double precision not null,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.routes (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  mode text not null default 'trip',
  origin text,
  start_date timestamptz not null,
  start_odometer double precision not null,
  destination text,
  end_date timestamptz,
  end_odometer double precision,
  value_per_distance double precision,
  total double precision,
  cargo_type text,
  contractor text,
  cargo_unit text,
  cargo_amount double precision,
  cargo_weight double precision,
  cargo_volume double precision,
  freight_value double precision,
  installments integer not null default 1,
  driver text,
  reason_id text,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.readings (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  "date" timestamptz not null,
  odometer double precision not null,
  driver text,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.reminders (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  vehicle_id text not null,
  target text not null,
  type_id text not null,
  "repeat" boolean not null default false,
  by_distance boolean not null default true,
  due_odometer double precision,
  every_distance double precision,
  by_date boolean not null default false,
  due_date timestamptz,
  every_amount integer,
  every_unit text,
  last_done_odometer double precision,
  last_done_date timestamptz,
  active boolean not null default true,
  notes text,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

-- ---------------------------------------------------------------------------
-- Last-write-wins trigger (shared by every table)
-- ---------------------------------------------------------------------------

create or replace function public.sync_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    -- Stale write from a device that hadn't seen the newer version.
    if new.updated_at < old.updated_at then
      return null;
    end if;
    -- Re-upload of exactly what is stored: keep server_updated_at as is.
    if new.updated_at = old.updated_at
       and (to_jsonb(new) - 'server_updated_at')
         = (to_jsonb(old) - 'server_updated_at') then
      return null;
    end if;
    -- A row never changes owner.
    new.owner_id := old.owner_id;
  end if;
  -- clock_timestamp() (not now()) so rows written later in a long
  -- transaction still sort after earlier ones.
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Row-level security, pull index, trigger and grants for every table
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'vehicles', 'catalog_items', 'refuelings', 'refueling_fuels', 'entries',
    'entry_items', 'routes', 'readings', 'reminders'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);

    -- Owner-only access. Sharing a vehicle with other users (a later
    -- milestone) extends these USING clauses, e.g.
    --   owner_id = (select auth.uid()) or exists (select 1 from
    --   public.vehicle_members m where m.owner_id = <table>.owner_id and
    --   m.vehicle_id = <table>.vehicle_id and m.user_id = (select auth.uid()))
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

    -- Pulls: where owner_id = me order by server_updated_at, id.
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
