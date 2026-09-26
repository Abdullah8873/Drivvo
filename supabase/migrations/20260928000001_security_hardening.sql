-- MotoLog security & abuse hardening before sharing 1.0.0 with friends.
-- Findings and reasoning: docs/SECURITY.md (IDs S1… in the comments below).
--
-- Run it once in the Supabase SQL editor AFTER every earlier file in
-- supabase/migrations/. Safe to re-run (idempotent). Tested on a local
-- Postgres 16 with a stand-in for Supabase's auth/storage schemas
-- (tool/sql_test.sh, supabase/local-test/), never on the live project —
-- dry-run it inside begin … rollback first.
--
--   1. Guard triggers compare with the STORED owner (S2: a member could
--      bypass them by sending owner_id = themselves in a PATCH).
--   2. sync_row_exists() answers only for your own account or one you are
--      an active member of (S5: row-id probing across accounts).
--   3. Members can't pin a row with a far-future updated_at (S9).
--   4. Row size cap (64 KB) + per-account quota on synced rows (25 MB)
--      (S3: one account could fill the 500 MB database).
--   5. Storage: 3 MB per file, 50 MB per account folder (S4).
--   6. Transfer codes: failed redeems are rate limited (10/hour, 30/day
--      per user) and code creation is capped (20/day) (S6).
--   7. Length limits on profile fields (S12: invitation banner text).
--   8. Function/table privileges for everything above.

-- ---------------------------------------------------------------------------
-- 1. Guard triggers: check the stored row's owner, not the proposed one
-- ---------------------------------------------------------------------------

-- Same as 20260926000001_sharing.sql, except the own-membership check uses
-- old.owner_id: sync_before_write() (which resets owner_id to the stored
-- value) runs after this trigger, so a member who PATCHed their own row
-- with owner_id = their id slipped past `new.owner_id <> auth.uid()` and
-- could change their own profile_id / vehicle_ids.
create or replace function public.account_members_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  new.email := lower(trim(new.email));
  if tg_op = 'INSERT' then
    new.member_id := null;
    new.member_name := null;
    if new.status = 'active' then
      new.status := 'pending';
    end if;
    return new;
  end if;
  if old.member_id = auth.uid() and old.owner_id is distinct from auth.uid() then
    raise exception using
      errcode = '42501', message = 'motolog:own_membership';
  end if;
  new.member_id := old.member_id;
  new.member_name := old.member_name;
  if new.status is distinct from old.status then
    if new.status = 'removed' then
      null; -- removing is always allowed
    elsif new.status = 'pending' and old.status in ('declined', 'removed') then
      new.member_id := null;
      new.member_name := null;
    else
      new.status := old.status;
    end if;
  end if;
  if new.member_id is not null then
    new.email := old.email;
  end if;
  return new;
end;
$$;

-- Same bypass for profiles: decide by the stored owner, and check both the
-- old and the new id (a PATCH can change the id column too).
create or replace function public.access_profiles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_owner uuid := case when tg_op = 'UPDATE' then old.owner_id else new.owner_id end;
begin
  if current_user not in ('authenticated', 'anon')
     or v_owner = auth.uid() then
    return new;
  end if;
  if exists (
    select 1 from public.account_members m
    where m.owner_id = v_owner and m.member_id = auth.uid()
      and m.status = 'active' and m.deleted_at is null
      and (m.profile_id = new.id
           or (tg_op = 'UPDATE' and m.profile_id = old.id))
  ) then
    raise exception using
      errcode = '42501', message = 'motolog:own_profile';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. sync_row_exists(): no answers about accounts you don't belong to
-- ---------------------------------------------------------------------------

-- Any signed-in user could call it over /rest/v1/rpc and learn whether
-- (owner, id) exists in someone else's account. The insert policies only
-- need it for the caller's own account or one they are a member of; for
-- anyone else can_access() refuses the row whatever this returns.
create or replace function public.sync_row_exists(
  p_table text,
  p_owner uuid,
  p_id text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_found boolean;
begin
  if p_table not in (
    'vehicles', 'catalog_items', 'refuelings', 'refueling_fuels', 'entries',
    'entry_items', 'routes', 'readings', 'reminders', 'checklist_forms',
    'checklist_form_items', 'checklists', 'checklist_answers', 'attachments',
    'access_profiles', 'account_members'
  ) then
    return false;
  end if;
  if p_owner is distinct from auth.uid() and not exists (
    select 1 from public.account_members m
    where m.owner_id = p_owner and m.member_id = auth.uid()
      and m.status = 'active' and m.deleted_at is null
  ) then
    return false;
  end if;
  execute format(
    'select exists (select 1 from public.%I where owner_id = $1 and id = $2)',
    p_table)
    into v_found
    using p_owner, p_id;
  return v_found;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Last-write-wins: members can't pin rows with a future timestamp
-- ---------------------------------------------------------------------------

-- Same as 20260924000001_sync_tables.sql plus the first block: a client
-- writing into SOMEONE ELSE's account (a member) with updated_at more than
-- a day ahead gets the server's clock instead. Otherwise a member could
-- upload updated_at = 9999-12-31 and every later edit by the owner would
-- be ignored as "older". The owner's own writes and the security definer
-- RPCs are unchanged.
create or replace function public.sync_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon')
     and auth.uid() is distinct from
       (case when tg_op = 'UPDATE' then old.owner_id else new.owner_id end)
     and new.updated_at > clock_timestamp() + interval '1 day' then
    new.updated_at := clock_timestamp();
  end if;
  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at then
      return null;
    end if;
    if new.updated_at = old.updated_at
       and (to_jsonb(new) - 'server_updated_at')
         = (to_jsonb(old) - 'server_updated_at') then
      return null;
    end if;
    new.owner_id := old.owner_id;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Row size cap and per-account quota on synced rows
-- ---------------------------------------------------------------------------

-- Limits live in functions so the owner can change them with one
-- `create or replace` (no redeploy). A row's size is the length of its
-- text form (`row::text`): the same before and after Postgres compresses
-- it, so inserts and deletes add up exactly. On disk it is usually less
-- (compression), plus indexes and overhead.
create or replace function public.sync_max_row_bytes()
returns integer
language sql
immutable
set search_path = ''
as $$ select 65536 $$;

create or replace function public.sync_row_quota_bytes()
returns bigint
language sql
immutable
set search_path = ''
as $$ select 26214400::bigint $$; -- 25 MB per account (a heavy real account: ~5 MB)

-- One row per account: bytes of synced rows it owns. Maintained by the
-- statement triggers below; recount any time with sync_usage_recount().
create table if not exists public.sync_usage (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  row_bytes bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.sync_usage enable row level security;
revoke all on public.sync_usage from anon, authenticated;

-- BEFORE each row write: refuse a single oversized row (a 64 KB note is
-- already far beyond what the app's forms produce).
create or replace function public.sync_check_row_size()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_size integer := octet_length(new::text);
begin
  if v_size > public.sync_max_row_bytes() then
    raise exception using
      errcode = '54000', message = 'motolog:row_too_large',
      detail = format('%s row %s is %s bytes', tg_table_name, new.id, v_size);
  end if;
  return new;
end;
$$;

-- Adds p_delta bytes to p_owner's usage. Growth past the quota raises
-- (the whole statement — a push batch or a transfer — is rolled back).
-- Updates get 20% headroom so an account at its quota can still edit and
-- soft-delete records (a soft delete makes a row a few bytes bigger).
-- Shrinking never raises, and never inserts a usage row: account deletion
-- cascades through here while the auth.users row is going away.
create or replace function public.sync_usage_add(
  p_owner uuid,
  p_delta bigint,
  p_new_rows boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total bigint;
  v_limit bigint := public.sync_row_quota_bytes();
begin
  if p_owner is null or p_delta = 0 then
    return;
  end if;
  if p_delta < 0 then
    update public.sync_usage u
       set row_bytes = greatest(u.row_bytes + p_delta, 0), updated_at = now()
     where u.owner_id = p_owner;
    return;
  end if;
  insert into public.sync_usage as u (owner_id, row_bytes)
  values (p_owner, p_delta)
  on conflict (owner_id) do update
    set row_bytes = u.row_bytes + excluded.row_bytes, updated_at = now()
  returning u.row_bytes into v_total;
  if not p_new_rows then
    v_limit := v_limit + v_limit / 5;
  end if;
  if v_total > v_limit then
    raise exception using
      errcode = '53400', message = 'motolog:quota_exceeded',
      detail = format('account data would be %s bytes (limit %s)', v_total, v_limit);
  end if;
end;
$$;

-- AFTER each INSERT / UPDATE / DELETE statement (one call per statement and
-- account, not per row — a 500-row push batch costs one usage update).
-- Rows the last-write-wins trigger skipped are not in the transition
-- tables, so re-uploads cost nothing.
create or replace function public.sync_usage_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select n.owner_id, sum(octet_length(n::text))::bigint as bytes
    from new_rows n group by n.owner_id
  loop
    perform public.sync_usage_add(r.owner_id, r.bytes, true);
  end loop;
  return null;
end;
$$;

create or replace function public.sync_usage_after_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select x.owner_id, sum(x.bytes)::bigint as bytes
    from (
      select n.owner_id, octet_length(n::text)::bigint as bytes from new_rows n
      union all
      select o.owner_id, -octet_length(o::text)::bigint from old_rows o
    ) x
    group by x.owner_id
  loop
    perform public.sync_usage_add(r.owner_id, r.bytes, false);
  end loop;
  return null;
end;
$$;

create or replace function public.sync_usage_after_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select o.owner_id, sum(octet_length(o::text))::bigint as bytes
    from old_rows o group by o.owner_id
  loop
    perform public.sync_usage_add(r.owner_id, -r.bytes, false);
  end loop;
  return null;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'vehicles', 'catalog_items', 'refuelings', 'refueling_fuels', 'entries',
    'entry_items', 'routes', 'readings', 'reminders', 'checklist_forms',
    'checklist_form_items', 'checklists', 'checklist_answers', 'attachments',
    'access_profiles', 'account_members'
  ]
  loop
    -- "<t>_row_size" sorts after "<t>_created_by"/"account_members_guard"
    -- and before "<t>_sync_before_write" (BEFORE triggers run by name).
    execute format('drop trigger if exists %I on public.%I', t || '_row_size', t);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.sync_check_row_size()',
      t || '_row_size', t);

    execute format('drop trigger if exists %I on public.%I', t || '_usage_ins', t);
    execute format(
      'create trigger %I after insert on public.%I '
      'referencing new table as new_rows '
      'for each statement execute function public.sync_usage_after_insert()',
      t || '_usage_ins', t);
    execute format('drop trigger if exists %I on public.%I', t || '_usage_upd', t);
    execute format(
      'create trigger %I after update on public.%I '
      'referencing old table as old_rows new table as new_rows '
      'for each statement execute function public.sync_usage_after_update()',
      t || '_usage_upd', t);
    execute format('drop trigger if exists %I on public.%I', t || '_usage_del', t);
    execute format(
      'create trigger %I after delete on public.%I '
      'referencing old table as old_rows '
      'for each statement execute function public.sync_usage_after_delete()',
      t || '_usage_del', t);
  end loop;
end;
$$;

-- Recomputes every account's usage from scratch (run by this file, and by
-- the owner from the SQL editor whenever the numbers look off).
create or replace function public.sync_usage_recount()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t text;
begin
  delete from public.sync_usage where true;
  foreach t in array array[
    'vehicles', 'catalog_items', 'refuelings', 'refueling_fuels', 'entries',
    'entry_items', 'routes', 'readings', 'reminders', 'checklist_forms',
    'checklist_form_items', 'checklists', 'checklist_answers', 'attachments',
    'access_profiles', 'account_members'
  ]
  loop
    execute format(
      'insert into public.sync_usage as u (owner_id, row_bytes) '
      'select s.owner_id, sum(octet_length(s::text))::bigint '
      'from public.%I s group by s.owner_id '
      'on conflict (owner_id) do update '
      'set row_bytes = u.row_bytes + excluded.row_bytes, updated_at = now()',
      t);
  end loop;
end;
$$;

select public.sync_usage_recount();

-- ---------------------------------------------------------------------------
-- 5. Storage: 3 MB per file, 50 MB per account folder
-- ---------------------------------------------------------------------------

-- Matches RemoteFileStore.maxBytes in the app (photos are downscaled to
-- 1920 px / JPEG 80, typically well under 1 MB).
update storage.buckets
   set file_size_limit = 3145728
 where id = 'attachments';

create or replace function public.attachment_quota_bytes()
returns bigint
language sql
immutable
set search_path = ''
as $$ select 52428800::bigint $$; -- 50 MB per account

-- Whether a new object p_name (with p_metadata when Storage already knows
-- its size) fits in its account folder's quota. Counts what is already
-- stored in <owner>/ (the account's files, members' uploads included), so
-- a folder can overshoot by at most one file (3 MB). Answers only for
-- folders the caller may write to (no probing other accounts' usage).
create or replace function public.attachment_upload_allowed(
  p_name text,
  p_metadata jsonb default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_used bigint;
begin
  if auth.uid() is null then
    return false;
  end if;
  begin
    v_owner := ((storage.foldername(p_name))[1])::uuid;
  exception when others then
    return false;
  end;
  if v_owner is distinct from auth.uid()
     and not public.can_write_attachment_object(p_name) then
    return false;
  end if;
  -- v_owner is a uuid, so the LIKE pattern has no wildcards of its own.
  select coalesce(sum(coalesce((o.metadata ->> 'size')::bigint, 0)), 0)
    into v_used
  from storage.objects o
  where o.bucket_id = 'attachments'
    and o.name like v_owner::text || '/%'
    and o.name <> p_name;
  return v_used + coalesce((p_metadata ->> 'size')::bigint, 0)
    <= public.attachment_quota_bytes();
end;
$$;

drop policy if exists "attachments_insert" on storage.objects;
create policy "attachments_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_write_attachment_object(name))
    and public.attachment_upload_allowed(name, metadata)
  );

-- ---------------------------------------------------------------------------
-- 6. Transfer codes: rate limits
-- ---------------------------------------------------------------------------

-- Failed redeem attempts (unknown code), kept for a day. Only
-- redeem_transfer() touches it.
create table if not exists public.transfer_attempts (
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index if not exists transfer_attempts_user_idx
  on public.transfer_attempts (user_id, attempted_at);
alter table public.transfer_attempts enable row level security;
revoke all on public.transfer_attempts from anon, authenticated;

-- Same as 20260926000001_sharing.sql plus the daily cap: at most 20 codes
-- per seller per 24 hours (each code is a row nobody else can clean up).
create or replace function public.create_transfer(p_vehicle_id text)
returns setof public.transfers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text;
  v_code text;
  v_bytes bytea;
  v_byte int;
  c_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
begin
  if v_uid is null then
    raise exception 'motolog:not_signed_in';
  end if;
  if (select count(*) from public.transfers t
      where t.owner_id = v_uid
        and t.created_at > now() - interval '1 day') >= 20 then
    raise exception using
      errcode = '53400', message = 'motolog:transfer_rate_limited';
  end if;
  select v.name into v_name from public.vehicles v
  where v.owner_id = v_uid and v.id = p_vehicle_id and v.deleted_at is null;
  if v_name is null then
    raise exception 'motolog:vehicle_not_found';
  end if;
  loop
    v_code := '';
    while length(v_code) < 8 loop
      v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
      for i in 0..15 loop
        continue when i in (6, 8);
        v_byte := get_byte(v_bytes, i);
        if v_byte < 248 and length(v_code) < 8 then
          v_code := v_code || substr(c_alphabet, v_byte % 31 + 1, 1);
        end if;
      end loop;
    end loop;
    exit when not exists (select 1 from public.transfers t where t.code = v_code);
  end loop;
  insert into public.transfers (code, owner_id, vehicle_id, vehicle_name, expires_at)
  values (v_code, v_uid, p_vehicle_id, v_name, now() + interval '7 days');
  return query select * from public.transfers t where t.code = v_code;
end;
$$;

-- Same as 20260926000001_sharing.sql except the start:
--   * more than 10 unknown codes in the last hour (or 30 in a day) →
--     motolog:transfer_rate_limited, before looking the code up;
--   * an unknown code is recorded and returns NO ROWS instead of raising
--     (a raise would roll the attempt record back). The app reports an
--     empty result as "No transfer with this code"; older builds show
--     "Couldn't redeem this code."
-- 31^8 ≈ 8.5e11 codes and ≤ 240 guesses per user per day make guessing a
-- live code hopeless even with many throwaway accounts.
create or replace function public.redeem_transfer(p_code text)
returns table (vehicle_id text, vehicle_name text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  t public.transfers;
  v text;
  v_records text;
begin
  if v_uid is null then
    raise exception 'motolog:not_signed_in';
  end if;
  if (select count(*) from public.transfer_attempts a
      where a.user_id = v_uid
        and a.attempted_at > now() - interval '1 hour') >= 10
     or (select count(*) from public.transfer_attempts a
         where a.user_id = v_uid
           and a.attempted_at > now() - interval '1 day') >= 30 then
    raise exception using
      errcode = '53400', message = 'motolog:transfer_rate_limited';
  end if;
  select * into t from public.transfers x where x.code = v_code for update;
  if not found then
    delete from public.transfer_attempts a
     where a.user_id = v_uid and a.attempted_at < now() - interval '1 day';
    insert into public.transfer_attempts (user_id) values (v_uid);
    return;
  end if;
  if t.owner_id = v_uid then
    raise exception 'motolog:transfer_own';
  end if;
  if t.redeemed_at is not null then
    raise exception 'motolog:transfer_used';
  end if;
  if t.cancelled_at is not null then
    raise exception 'motolog:transfer_cancelled';
  end if;
  if t.expires_at <= now() then
    raise exception 'motolog:transfer_expired';
  end if;
  if exists (select 1 from public.vehicles x
             where x.owner_id = v_uid and x.id = t.vehicle_id) then
    raise exception 'motolog:vehicle_exists';
  end if;
  if not exists (select 1 from public.vehicles x
                 where x.owner_id = t.owner_id and x.id = t.vehicle_id
                   and x.deleted_at is null) then
    raise exception 'motolog:vehicle_not_found';
  end if;

  v := quote_literal(t.vehicle_id);
  v_records := format(
    'owner_id = s.owner_id and vehicle_id = %s and deleted_at is null', v);

  perform public.transfer_copy('vehicles', t.owner_id, v_uid, 's.id = ' || v);

  perform public.transfer_copy('catalog_items', t.owner_id, v_uid, format(
    's.id in ('
    'select gas_station_id from public.refuelings where %1$s union '
    'select payment_method_id from public.refuelings where %1$s union '
    'select reason_id from public.refuelings where %1$s union '
    'select f.fuel_id from public.refueling_fuels f join public.refuelings r '
    '  on r.owner_id = f.owner_id and r.id = f.refueling_id '
    '  where f.owner_id = s.owner_id and r.vehicle_id = %2$s '
    '  and r.deleted_at is null and f.deleted_at is null union '
    'select place_id from public.entries where %1$s union '
    'select payment_method_id from public.entries where %1$s union '
    'select reason_id from public.entries where %1$s union '
    'select i.type_id from public.entry_items i join public.entries e '
    '  on e.owner_id = i.owner_id and e.id = i.entry_id '
    '  where i.owner_id = s.owner_id and e.vehicle_id = %2$s '
    '  and e.deleted_at is null and i.deleted_at is null union '
    'select reason_id from public.routes where %1$s union '
    'select type_id from public.reminders where %1$s)',
    v_records, v), true);

  perform public.transfer_copy('checklist_forms', t.owner_id, v_uid, format(
    's.id in (select form_id from public.checklists where %s)', v_records), true);
  perform public.transfer_copy('checklist_form_items', t.owner_id, v_uid, format(
    's.form_id in (select form_id from public.checklists where %s)', v_records));

  perform public.transfer_copy('refuelings', t.owner_id, v_uid, 's.vehicle_id = ' || v);
  perform public.transfer_copy('entries', t.owner_id, v_uid, 's.vehicle_id = ' || v);
  perform public.transfer_copy('routes', t.owner_id, v_uid, 's.vehicle_id = ' || v);
  perform public.transfer_copy('readings', t.owner_id, v_uid, 's.vehicle_id = ' || v);
  perform public.transfer_copy('reminders', t.owner_id, v_uid, 's.vehicle_id = ' || v);
  perform public.transfer_copy('checklists', t.owner_id, v_uid, 's.vehicle_id = ' || v);

  perform public.transfer_copy('refueling_fuels', t.owner_id, v_uid, format(
    's.refueling_id in (select id from public.refuelings where %s)', v_records));
  perform public.transfer_copy('entry_items', t.owner_id, v_uid, format(
    's.entry_id in (select id from public.entries where %s)', v_records));
  perform public.transfer_copy('checklist_answers', t.owner_id, v_uid, format(
    's.checklist_id in (select id from public.checklists where %s)', v_records));
  perform public.transfer_copy('attachments', t.owner_id, v_uid, 's.vehicle_id = ' || v);

  update public.transfers x
     set redeemed_by = v_uid, redeemed_at = now()
   where x.code = t.code;

  return query select t.vehicle_id, t.vehicle_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Profile field lengths
-- ---------------------------------------------------------------------------

-- The name is shown to people you invite ("<First Last> invited you…"), so
-- keep it to a name's length. NOT VALID: existing rows aren't re-checked,
-- only new writes. The app's fields have the same maxLength.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_field_lengths'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles add constraint profiles_field_lengths check (
      char_length(first_name) <= 100
      and char_length(last_name) <= 100
      and char_length(license_number) <= 50
      and char_length(license_category) <= 50
    ) not valid;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Function privileges
-- ---------------------------------------------------------------------------

-- `create or replace` keeps a function's existing grants, but new
-- functions get Supabase's default "execute for anon + authenticated".
do $$
declare
  f text;
begin
  -- Called by clients, or evaluated as the client inside a policy.
  foreach f in array array[
    'public.sync_row_exists(text, uuid, text)',
    'public.create_transfer(text)',
    'public.redeem_transfer(text)',
    'public.attachment_upload_allowed(text, jsonb)',
    -- A constant, read by the row-size trigger as the writing client.
    'public.sync_max_row_bytes()'
  ]
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- Internal: triggers, limits and maintenance only.
  foreach f in array array[
    'public.sync_usage_add(uuid, bigint, boolean)',
    'public.sync_usage_recount()',
    'public.sync_usage_after_insert()',
    'public.sync_usage_after_update()',
    'public.sync_usage_after_delete()',
    'public.sync_check_row_size()',
    'public.sync_row_quota_bytes()',
    'public.attachment_quota_bytes()'
  ]
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end;
$$;
