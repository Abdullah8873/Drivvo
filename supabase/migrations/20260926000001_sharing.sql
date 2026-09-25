-- MotoLog sharing: users, access profiles, Transfer (docs/SHARING.md).
--
-- Adds, on top of 20260924000001_sync_tables.sql, …000002_account.sql and
-- 20260925000001_attachments_checklists.sql (run those first):
--   * created_by on the record tables (who made a record — the "own
--     records" scope), stamped by the server only;
--   * access_profiles (custom profiles; the three built-in ones live in
--     code and are inlined in profile_permissions() below) and
--     account_members (invited users), both synced like the other tables;
--   * can_access(): the permission check every table's row-level security
--     now uses for members, mirroring lib/core/calc/access_profile.dart and
--     lib/core/calc/member_access.dart;
--   * RPCs: my_invitations, accept_invitation, decline_invitation,
--     my_memberships, leave_account, create_transfer, my_transfers,
--     cancel_transfer, redeem_transfer;
--   * Storage policies so members (and buyers of a transferred vehicle)
--     can read the files they're allowed to see.
--
-- The owner's access is unchanged: every policy is still
-- "owner_id = auth.uid()" first; can_access() only runs for other users.
--
-- Run it once in the Supabase SQL editor. Safe to re-run (idempotent).

-- ---------------------------------------------------------------------------
-- 1. created_by on record tables
-- ---------------------------------------------------------------------------

-- Server-stamped: a row a member inserts gets the member's id; a row the
-- owner inserts (or a transfer copies) keeps null, which means "the
-- owner" (every check uses coalesce(created_by, owner_id)). Never changes
-- afterwards, whatever a device uploads. Leaving the owner's rows null
-- means the owner's devices don't re-download everything they upload.
create or replace function public.sync_stamp_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := case
      when auth.uid() is null or auth.uid() = new.owner_id then null
      else auth.uid()
    end;
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'refuelings', 'entries', 'routes', 'readings', 'reminders', 'checklists',
    'attachments'
  ]
  loop
    execute format(
      'alter table public.%I add column if not exists created_by uuid', t);
    -- Trigger names sort before "<t>_sync_before_write" ("c" < "s"), so
    -- created_by is settled before the last-write-wins comparison.
    execute format('drop trigger if exists %I on public.%I', t || '_created_by', t);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.sync_stamp_created_by()',
      t || '_created_by', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. New synced tables
-- ---------------------------------------------------------------------------

create table if not exists public.access_profiles (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  name text not null,
  -- AccessProfile.permissionsToJson() as JSON text (text, not jsonb, so the
  -- app syncs it like any other column; cast with ::jsonb when reading).
  permissions text not null,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table if not exists public.account_members (
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  id text collate "C" not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  email text not null,
  -- Set by accept_invitation() only (see account_members_guard). No
  -- foreign key: the guard trigger would fight an "on delete set null".
  member_id uuid,
  member_name text,
  profile_id text not null,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'declined', 'removed')),
  vehicle_ids text not null default '[]',
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create index if not exists account_members_member_idx
  on public.account_members (member_id) where member_id is not null;
create index if not exists account_members_email_idx
  on public.account_members (lower(email));

-- Clients (the owner, managers) may invite, re-invite, edit and remove,
-- but only accept_invitation() can attach a user and make them active —
-- otherwise anyone with Users access could add a stranger's account. A
-- member can't change their own row either (no raising their own
-- profile). The RPCs below are security definer, so they run as the
-- function owner, not as the client role, and skip these rules.
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
    -- Also runs on the insert half of an upsert that ends up updating
    -- (EXCLUDED), so only the one forbidden value is changed here; the
    -- update branch below compares with the stored row.
    new.member_id := null;
    new.member_name := null;
    if new.status = 'active' then
      new.status := 'pending';
    end if;
    return new;
  end if;
  if old.member_id = auth.uid() and new.owner_id <> auth.uid() then
    raise exception using
      errcode = '42501', message = 'motolog:own_membership';
  end if;
  new.member_id := old.member_id;
  new.member_name := old.member_name;
  if new.status is distinct from old.status then
    if new.status = 'removed' then
      null; -- removing is always allowed
    elsif new.status = 'pending' and old.status in ('declined', 'removed') then
      -- Re-invite: forget the previous acceptance.
      new.member_id := null;
      new.member_name := null;
    else
      new.status := old.status;
    end if;
  end if;
  -- An accepted invitation stays tied to that user's address.
  if new.member_id is not null then
    new.email := old.email;
  end if;
  return new;
end;
$$;

drop trigger if exists account_members_guard on public.account_members;
create trigger account_members_guard
  before insert or update on public.account_members
  for each row execute function public.account_members_guard();

-- A member with Profiles access can't widen the profile they have
-- themselves.
create or replace function public.access_profiles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon')
     or new.owner_id = auth.uid() then
    return new;
  end if;
  if exists (
    select 1 from public.account_members m
    where m.owner_id = new.owner_id and m.member_id = auth.uid()
      and m.status = 'active' and m.deleted_at is null
      and m.profile_id = new.id
  ) then
    raise exception using
      errcode = '42501', message = 'motolog:own_profile';
  end if;
  return new;
end;
$$;

drop trigger if exists access_profiles_guard on public.access_profiles;
create trigger access_profiles_guard
  before insert or update on public.access_profiles
  for each row execute function public.access_profiles_guard();

do $$
declare
  t text;
begin
  foreach t in array array['access_profiles', 'account_members']
  loop
    execute format('alter table public.%I enable row level security', t);
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
-- 3. Permissions
-- ---------------------------------------------------------------------------

-- Effective permission JSON of a profile in an account (built-ins inlined;
-- must match AccessProfile.administrator/manager/driver in
-- lib/core/calc/access_profile.dart — test/sharing_model_test.dart
-- checks the JSON). Null for an unknown/deleted custom profile.
create or replace function public.profile_permissions(p_owner uuid, p_profile_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    -- Constants (not built per call: this runs for every row a member
    -- pulls). Same JSON as AccessProfile.permissionsToJson().
    when p_profile_id in ('builtin:administrator', 'builtin:manager') then
      '{"vehicleScope":"all","recordScope":"all","areas":{"refueling":["view","register","edit","delete"],"expense":["view","register","edit","delete"],"income":["view","register","edit","delete"],"service":["view","register","edit","delete"],"route":["view","register","edit","delete"],"checklist":["view","register","edit","delete"],"reminder":["view","register","edit","delete"],"reading":["view","register","edit","delete"],"report":["view"],"fuel":["view","register","edit","delete"],"gasStation":["view","register","edit","delete"],"place":["view","register","edit","delete"],"expenseType":["view","register","edit","delete"],"serviceType":["view","register","edit","delete"],"incomeType":["view","register","edit","delete"],"reason":["view","register","edit","delete"],"paymentMethod":["view","register","edit","delete"],"vehicles":["view","register","edit","delete"],"users":["view","register","edit","delete"],"profiles":["view","register","edit","delete"],"forms":["view","register","edit","delete"]}}'::jsonb
    when p_profile_id = 'builtin:driver' then
      '{"vehicleScope":"assigned","recordScope":"own","areas":{"refueling":["view","register","edit"],"expense":["view","register","edit"],"income":["view","register","edit"],"service":["view","register","edit"],"route":["view","register","edit"],"checklist":["view","register","edit"],"reminder":["view","register","edit"],"reading":["view","register","edit"],"fuel":["view","register","edit"],"gasStation":["view","register","edit"],"place":["view","register","edit"],"expenseType":["view","register","edit"],"serviceType":["view","register","edit"],"incomeType":["view","register","edit"],"reason":["view","register","edit"],"paymentMethod":["view","register","edit"]}}'::jsonb
    else (
      select p.permissions::jsonb
      from public.access_profiles p
      where p.owner_id = p_owner and p.id = p_profile_id
        and p.deleted_at is null)
  end;
$$;

-- Whether the signed-in user may do p_action (view/register/edit/delete)
-- on p_area (an AccessArea name; null = skip the switch check, used for
-- viewing vehicles) of p_owner's account, for a row of vehicle
-- p_vehicle_id (null = not vehicle-scoped) created by p_created_by
-- (null = not record-scoped; records pass coalesce(created_by, owner_id)).
create or replace function public.can_access(
  p_owner uuid,
  p_area text,
  p_action text,
  p_vehicle_id text,
  p_created_by uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile text;
  v_vehicles text;
  v_perms jsonb;
  v_granted jsonb;
begin
  if v_uid is null then
    return false;
  end if;
  if p_owner = v_uid then
    return true;
  end if;
  select m.profile_id, m.vehicle_ids into v_profile, v_vehicles
  from public.account_members m
  where m.owner_id = p_owner and m.member_id = v_uid
    and m.status = 'active' and m.deleted_at is null
  order by m.updated_at desc
  limit 1;
  if v_profile is null then
    return false;
  end if;
  v_perms := public.profile_permissions(p_owner, v_profile);
  if v_perms is null then
    return false;
  end if;
  -- A switch needs View too (AccessProfile.can).
  if p_area is not null then
    v_granted := coalesce(v_perms -> 'areas' -> p_area, '[]'::jsonb);
    if not (v_granted ? p_action and v_granted ? 'view') then
      return false;
    end if;
  end if;
  if p_vehicle_id is not null
     and coalesce(v_perms ->> 'vehicleScope', 'assigned') <> 'all'
     and not (coalesce(nullif(v_vehicles, ''), '[]')::jsonb ? p_vehicle_id) then
    return false;
  end if;
  if p_created_by is not null
     and coalesce(v_perms ->> 'recordScope', 'own') <> 'all'
     and p_created_by <> v_uid then
    return false;
  end if;
  return true;
end;
$$;

-- Child rows (fuel lines, entry items, checklist answers, attachments) are
-- checked through their parent record.
create or replace function public.can_access_parent(
  p_owner uuid,
  p_parent_table text,
  p_parent_id text,
  p_action text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_area text;
  v_vehicle text;
  v_created uuid;
begin
  if p_owner = auth.uid() then
    return true;
  end if;
  case p_parent_table
    when 'refuelings' then
      select 'refueling', r.vehicle_id, coalesce(r.created_by, r.owner_id)
        into v_area, v_vehicle, v_created
      from public.refuelings r where r.owner_id = p_owner and r.id = p_parent_id;
    when 'entries' then
      select e.kind, e.vehicle_id, coalesce(e.created_by, e.owner_id)
        into v_area, v_vehicle, v_created
      from public.entries e where e.owner_id = p_owner and e.id = p_parent_id;
    when 'routes' then
      select 'route', r.vehicle_id, coalesce(r.created_by, r.owner_id)
        into v_area, v_vehicle, v_created
      from public.routes r where r.owner_id = p_owner and r.id = p_parent_id;
    when 'readings' then
      select 'reading', r.vehicle_id, coalesce(r.created_by, r.owner_id)
        into v_area, v_vehicle, v_created
      from public.readings r where r.owner_id = p_owner and r.id = p_parent_id;
    when 'reminders' then
      select 'reminder', r.vehicle_id, coalesce(r.created_by, r.owner_id)
        into v_area, v_vehicle, v_created
      from public.reminders r where r.owner_id = p_owner and r.id = p_parent_id;
    when 'checklists' then
      select 'checklist', c.vehicle_id, coalesce(c.created_by, c.owner_id)
        into v_area, v_vehicle, v_created
      from public.checklists c where c.owner_id = p_owner and c.id = p_parent_id;
    else
      return false;
  end case;
  if v_area is null then
    return false; -- parent not uploaded (or rejected)
  end if;
  return public.can_access(p_owner, v_area, p_action, v_vehicle, v_created);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Row-level security: owner, or a member allowed by can_access()
-- ---------------------------------------------------------------------------
--
-- Per table: a "view" expression and a "write" template ({a} = the
-- action). select = view; insert = register; update = view the old row,
-- then edit (or delete, when the new row is soft-deleted); delete =
-- delete. Child tables: any write = edit of the parent (a new child row
-- may also come with registering the parent). The app only soft-deletes,
-- so the delete policy is there for completeness.

do $$
declare
  r record;
  v_write_new text;
  v_insert text;
  v_delete text;
begin
  for r in
    select * from (values
      ('vehicles', false,
       'public.can_access(owner_id, null, ''view'', id, null)',
       'public.can_access(owner_id, ''vehicles'', {a}, id, null)'),
      ('catalog_items', false,
       'public.can_access(owner_id, kind, ''view'', null, null)',
       'public.can_access(owner_id, kind, {a}, null, null)'),
      ('refuelings', false,
       'public.can_access(owner_id, ''refueling'', ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, ''refueling'', {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('entries', false,
       'public.can_access(owner_id, kind, ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, kind, {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('routes', false,
       'public.can_access(owner_id, ''route'', ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, ''route'', {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('readings', false,
       'public.can_access(owner_id, ''reading'', ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, ''reading'', {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('reminders', false,
       'public.can_access(owner_id, ''reminder'', ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, ''reminder'', {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('checklists', false,
       'public.can_access(owner_id, ''checklist'', ''view'', vehicle_id, coalesce(created_by, owner_id))',
       'public.can_access(owner_id, ''checklist'', {a}, vehicle_id, coalesce(created_by, owner_id))'),
      ('refueling_fuels', true,
       'public.can_access_parent(owner_id, ''refuelings'', refueling_id, ''view'')',
       'public.can_access_parent(owner_id, ''refuelings'', refueling_id, {a})'),
      ('entry_items', true,
       'public.can_access_parent(owner_id, ''entries'', entry_id, ''view'')',
       'public.can_access_parent(owner_id, ''entries'', entry_id, {a})'),
      ('checklist_answers', true,
       'public.can_access_parent(owner_id, ''checklists'', checklist_id, ''view'')',
       'public.can_access_parent(owner_id, ''checklists'', checklist_id, {a})'),
      ('attachments', true,
       'public.can_access_parent(owner_id, parent_table, parent_id, ''view'')',
       'public.can_access_parent(owner_id, parent_table, parent_id, {a})'),
      -- Checklist templates: whoever can view checklists needs them to fill
      -- one in; changing them is the Forms (administration) switch.
      ('checklist_forms', false,
       '(public.can_access(owner_id, ''forms'', ''view'', null, null) or public.can_access(owner_id, ''checklist'', ''view'', null, null))',
       'public.can_access(owner_id, ''forms'', {a}, null, null)'),
      ('checklist_form_items', false,
       '(public.can_access(owner_id, ''forms'', ''view'', null, null) or public.can_access(owner_id, ''checklist'', ''view'', null, null))',
       'public.can_access(owner_id, ''forms'', {a}, null, null)'),
      ('access_profiles', false,
       'public.can_access(owner_id, ''profiles'', ''view'', null, null)',
       'public.can_access(owner_id, ''profiles'', {a}, null, null)'),
      ('account_members', false,
       'public.can_access(owner_id, ''users'', ''view'', null, null)',
       'public.can_access(owner_id, ''users'', {a}, null, null)')
    ) as t(tbl, is_child, view_expr, write_tpl)
  loop
    if r.is_child then
      v_insert := '(' || replace(r.write_tpl, '{a}', '''register''') || ' or '
        || replace(r.write_tpl, '{a}', '''edit''') || ')';
      v_write_new := replace(r.write_tpl, '{a}', '''edit''');
      v_delete := replace(r.write_tpl, '{a}', '''edit''');
    else
      v_insert := replace(r.write_tpl, '{a}', '''register''');
      v_write_new := replace(r.write_tpl, '{a}',
        'case when deleted_at is null then ''edit'' else ''delete'' end');
      v_delete := replace(r.write_tpl, '{a}', '''delete''');
    end if;

    -- Old owner-only policies (sync_tables / attachments_checklists) and
    -- this file's own, so a re-run starts clean.
    execute format('drop policy if exists %I on public.%I', r.tbl || '_select_own', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_insert_own', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_update_own', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_delete_own', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_select', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_insert', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_update', r.tbl);
    execute format('drop policy if exists %I on public.%I', r.tbl || '_delete', r.tbl);

    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using (owner_id = (select auth.uid()) or %s)',
      r.tbl || '_select', r.tbl, r.view_expr);
    -- The app uploads with INSERT … ON CONFLICT DO UPDATE, and Postgres
    -- checks the insert policy on the proposed row even when it ends up
    -- updating an existing one. For an existing row, seeing it is enough
    -- here: the update policy then requires Edit (or Delete).
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      'with check (owner_id = (select auth.uid()) or case when exists '
      '(select 1 from public.%I x where x.owner_id = %I.owner_id '
      'and x.id = %I.id) then %s else %s end)',
      r.tbl || '_insert', r.tbl, r.tbl, r.tbl, r.tbl, r.view_expr, v_insert);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      'using (owner_id = (select auth.uid()) or %s) '
      'with check (owner_id = (select auth.uid()) or %s)',
      r.tbl || '_update', r.tbl, r.view_expr, v_write_new);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      'using (owner_id = (select auth.uid()) or %s)',
      r.tbl || '_delete', r.tbl, v_delete);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Invitations and memberships (RPCs)
-- ---------------------------------------------------------------------------

-- "First Last" from My account, else the email.
create or replace function public.account_display_name(p_user uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), ''),
    u.email,
    '')
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = p_user;
$$;

create or replace function public.profile_label(p_owner uuid, p_profile_id text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case p_profile_id
    when 'builtin:administrator' then 'Administrator'
    when 'builtin:manager' then 'Manager'
    when 'builtin:driver' then 'Driver'
    else coalesce(
      (select p.name from public.access_profiles p
       where p.owner_id = p_owner and p.id = p_profile_id),
      'Custom profile')
  end;
$$;

-- Pending invitations addressed to the signed-in user's verified email.
create or replace function public.my_invitations()
returns table (owner_id uuid, id text, owner_name text, profile_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select m.owner_id, m.id,
         public.account_display_name(m.owner_id),
         public.profile_label(m.owner_id, m.profile_id)
  from public.account_members m
  join auth.users u on u.id = auth.uid()
  where m.status = 'pending'
    and m.deleted_at is null
    and u.email_confirmed_at is not null
    and lower(m.email) = lower(u.email)
    and m.owner_id <> u.id
  order by m.created_at;
$$;

create or replace function public.accept_invitation(p_owner uuid, p_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_confirmed timestamptz;
begin
  if v_uid is null then
    raise exception 'motolog:not_signed_in';
  end if;
  if p_owner = v_uid then
    raise exception 'motolog:own_account';
  end if;
  select u.email, u.email_confirmed_at into v_email, v_confirmed
  from auth.users u where u.id = v_uid;
  if v_confirmed is null then
    raise exception 'motolog:email_not_verified';
  end if;
  update public.account_members m
     set member_id = v_uid,
         member_name = public.account_display_name(v_uid),
         status = 'active',
         -- Newer than whatever a device last wrote, so last-write-wins
         -- applies it and every device pulls it.
         updated_at = greatest(now(), m.updated_at + interval '1 millisecond')
   where m.owner_id = p_owner and m.id = p_id
     and m.status = 'pending' and m.deleted_at is null
     and lower(m.email) = lower(v_email);
  if not found then
    raise exception 'motolog:invitation_not_found';
  end if;
end;
$$;

create or replace function public.decline_invitation(p_owner uuid, p_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  if auth.uid() is null then
    raise exception 'motolog:not_signed_in';
  end if;
  select u.email into v_email from auth.users u
  where u.id = auth.uid() and u.email_confirmed_at is not null;
  if v_email is null then
    raise exception 'motolog:email_not_verified';
  end if;
  update public.account_members m
     set status = 'declined',
         updated_at = greatest(now(), m.updated_at + interval '1 millisecond')
   where m.owner_id = p_owner and m.id = p_id
     and m.status = 'pending' and m.deleted_at is null
     and lower(m.email) = lower(v_email);
  if not found then
    raise exception 'motolog:invitation_not_found';
  end if;
end;
$$;

-- Accounts the signed-in user is an active member of, with the resolved
-- permissions (the app caches them to work offline).
create or replace function public.my_memberships()
returns table (
  owner_id uuid,
  member_id uuid,
  owner_name text,
  profile_id text,
  profile_name text,
  permissions text,
  vehicle_ids text
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.owner_id, m.member_id,
         public.account_display_name(m.owner_id),
         m.profile_id,
         public.profile_label(m.owner_id, m.profile_id),
         public.profile_permissions(m.owner_id, m.profile_id)::text,
         m.vehicle_ids
  from public.account_members m
  where m.member_id = auth.uid()
    and m.status = 'active'
    and m.deleted_at is null
    and m.owner_id <> auth.uid()
  order by m.created_at;
$$;

create or replace function public.leave_account(p_owner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'motolog:not_signed_in';
  end if;
  update public.account_members m
     set status = 'removed',
         updated_at = greatest(now(), m.updated_at + interval '1 millisecond')
   where m.owner_id = p_owner and m.member_id = auth.uid()
     and m.status = 'active';
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Transfer (send a copy of a vehicle's history to its buyer)
-- ---------------------------------------------------------------------------

create table if not exists public.transfers (
  -- 8 characters from TransferCode.alphabet, stored without the dash.
  code text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  vehicle_id text not null,
  vehicle_name text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_by uuid references auth.users (id) on delete set null,
  redeemed_at timestamptz,
  cancelled_at timestamptz
);

create index if not exists transfers_owner_idx on public.transfers (owner_id, created_at);
create index if not exists transfers_redeemed_by_idx
  on public.transfers (redeemed_by) where redeemed_by is not null;

-- Only the functions below touch it (no policies = no direct access).
alter table public.transfers enable row level security;
revoke all on public.transfers from anon, authenticated;

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
  select v.name into v_name from public.vehicles v
  where v.owner_id = v_uid and v.id = p_vehicle_id and v.deleted_at is null;
  if v_name is null then
    raise exception 'motolog:vehicle_not_found';
  end if;
  loop
    v_code := '';
    while length(v_code) < 8 loop
      -- 16 random bytes from a v4 UUID; bytes 6 and 8 carry its fixed
      -- version/variant bits, so they're skipped. Bytes >= 248 are
      -- rejected to keep "% 31" unbiased.
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

create or replace function public.my_transfers()
returns setof public.transfers
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.transfers t
  where t.owner_id = auth.uid()
  order by t.created_at desc
  limit 100;
$$;

create or replace function public.cancel_transfer(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.transfers t
     set cancelled_at = now()
   where t.code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
     and t.owner_id = auth.uid()
     and t.redeemed_at is null and t.cancelled_at is null;
end;
$$;

-- Copies p_from's live rows of p_table matching p_where (a trusted SQL
-- condition on alias "s", built only by redeem_transfer) into p_to's
-- account with the same ids, skipping ids p_to already has. Timestamps are
-- kept; the triggers stamp server_updated_at (so the buyer's next pull
-- brings them down) and leave created_by null (= the buyer).
create or replace function public.transfer_copy(
  p_table text,
  p_from uuid,
  p_to uuid,
  p_where text,
  p_include_deleted boolean default false
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  execute format(
    'insert into public.%1$I '
    'select c.* from public.%1$I s '
    'cross join lateral jsonb_populate_record(null::public.%1$I, '
    '  to_jsonb(s) || jsonb_build_object(''owner_id'', $2::uuid)) c '
    'where s.owner_id = $1 and (%2$s) and (%3$s or s.deleted_at is null) '
    'on conflict (owner_id, id) do nothing',
    p_table, p_where, p_include_deleted)
  using p_from, p_to;
end;
$$;

revoke all on function public.transfer_copy(text, uuid, uuid, text, boolean)
  from public, anon, authenticated;

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
  select * into t from public.transfers x where x.code = v_code for update;
  if not found then
    raise exception 'motolog:transfer_not_found';
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
  -- "live records of the vehicle" for the child/catalog lookups.
  v_records := format(
    'owner_id = s.owner_id and vehicle_id = %s and deleted_at is null', v);

  perform public.transfer_copy('vehicles', t.owner_id, v_uid, 's.id = ' || v);

  -- Catalog items the records use (deleted ones too, so names resolve).
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

  -- Checklist templates the checklists came from.
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
  -- Attachment rows keep the seller's storage_path; the buyer's app
  -- downloads each file (allowed by can_read_attachment_object) and
  -- re-uploads it under its own folder.
  perform public.transfer_copy('attachments', t.owner_id, v_uid, 's.vehicle_id = ' || v);

  update public.transfers x
     set redeemed_by = v_uid, redeemed_at = now()
   where x.code = t.code;

  return query select t.vehicle_id, t.vehicle_name;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Storage: members and transfer buyers
-- ---------------------------------------------------------------------------

-- Object keys are <owner_id>/<attachment_id>/<file_name>.
create or replace function public.can_read_attachment_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_id text;
begin
  if auth.uid() is null then
    return false;
  end if;
  begin
    v_owner := ((storage.foldername(p_name))[1])::uuid;
  exception when others then
    return false;
  end;
  if v_owner = auth.uid() then
    return true;
  end if;
  -- Matched by the attachment id in the key, not by storage_path alone
  -- (a client can write any storage_path into a row it may edit).
  v_id := (storage.foldername(p_name))[2];
  -- A member who can see the record the file is attached to.
  if exists (
    select 1 from public.attachments a
    where a.owner_id = v_owner and a.id = v_id and a.storage_path = p_name
      and public.can_access_parent(v_owner, a.parent_table, a.parent_id, 'view')
  ) then
    return true;
  end if;
  -- The buyer of a vehicle transferred from the folder's owner: only the
  -- files whose attachment rows were copied to them.
  return exists (
    select 1
    from public.transfers t
    join public.attachments s
      on s.owner_id = t.owner_id and s.vehicle_id = t.vehicle_id
    where t.owner_id = v_owner and t.redeemed_by = auth.uid()
      and s.id = v_id and s.storage_path = p_name
      and exists (
        select 1 from public.attachments b
        where b.owner_id = auth.uid() and b.id = v_id)
  );
end;
$$;

-- Upload/replace/remove under the owner's folder: a member who can edit
-- (or register) the record of attachment <attachment_id> — its row is
-- uploaded before the file.
create or replace function public.can_write_attachment_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_id text;
begin
  if auth.uid() is null then
    return false;
  end if;
  begin
    v_owner := ((storage.foldername(p_name))[1])::uuid;
  exception when others then
    return false;
  end;
  if v_owner = auth.uid() then
    return true;
  end if;
  v_id := (storage.foldername(p_name))[2];
  return exists (
    select 1 from public.attachments a
    where a.owner_id = v_owner and a.id = v_id
      and (public.can_access_parent(v_owner, a.parent_table, a.parent_id, 'edit')
           or public.can_access_parent(v_owner, a.parent_table, a.parent_id, 'register'))
  );
end;
$$;

drop policy if exists "attachments_select_own" on storage.objects;
drop policy if exists "attachments_insert_own" on storage.objects;
drop policy if exists "attachments_update_own" on storage.objects;
drop policy if exists "attachments_delete_own" on storage.objects;
drop policy if exists "attachments_select" on storage.objects;
drop policy if exists "attachments_insert" on storage.objects;
drop policy if exists "attachments_update" on storage.objects;
drop policy if exists "attachments_delete" on storage.objects;

create policy "attachments_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_read_attachment_object(name))
  );

create policy "attachments_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_write_attachment_object(name))
  );

create policy "attachments_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_write_attachment_object(name))
  )
  with check (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_write_attachment_object(name))
  );

create policy "attachments_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or public.can_write_attachment_object(name))
  );

-- ---------------------------------------------------------------------------
-- 8. Function privileges
-- ---------------------------------------------------------------------------

-- Supabase grants execute on new public functions to anon by default.
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.can_access(uuid, text, text, text, uuid)',
    'public.can_access_parent(uuid, text, text, text)',
    'public.my_invitations()',
    'public.accept_invitation(uuid, text)',
    'public.decline_invitation(uuid, text)',
    'public.my_memberships()',
    'public.leave_account(uuid)',
    'public.create_transfer(text)',
    'public.my_transfers()',
    'public.cancel_transfer(text)',
    'public.redeem_transfer(text)',
    'public.can_read_attachment_object(text)',
    'public.can_write_attachment_object(text)'
  ]
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- Internal helpers (called only from the security definer functions
  -- above): not callable by clients, or anyone could look up any user's
  -- name/email by id.
  foreach f in array array[
    'public.profile_permissions(uuid, text)',
    'public.account_display_name(uuid)',
    'public.profile_label(uuid, text)'
  ]
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end;
$$;
