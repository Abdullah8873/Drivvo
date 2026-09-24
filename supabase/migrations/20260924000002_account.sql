-- My account (optional cloud login) — see CLAUDE.md "Decisions already
-- made" and docs/PLAN.md section 6 "Cloud".
--
-- `public.profiles` holds Drivvo's "My account" fields (name, driver's
-- license) for users who chose to sign in; most users will never have a row
-- here, since the app works fully offline without an account.
--
-- `public.delete_my_account()` backs the app's "Delete account" button: it
-- lets a signed-in user erase their own `auth.users` row (and, through the
-- foreign key below, their `profiles` row) even though a normal
-- "authenticated" role has no delete permission on `auth.users`.
--
-- Owned by feature/auth. Do not edit from feature/sync or
-- feature/notifications — see their own migrations
-- (20260924000001_sync_tables.sql, etc.).

-- profiles.id mirrors auth.users.id (one-to-one). Tying the primary key to
-- the auth user id — rather than a separate generated id — is what makes
-- the `id = auth.uid()` RLS check below correct and cheap (no join needed).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  license_number text not null default '',
  license_category text not null default '',
  license_expiry date,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A user may only ever see or touch their own row — no policy allows
-- reading or writing anyone else's profile, and there is no "select all"
-- policy for admins.
create policy "profiles: select own" on public.profiles
  for select
  using (id = auth.uid());

create policy "profiles: insert own" on public.profiles
  for insert
  with check (id = auth.uid());

create policy "profiles: update own" on public.profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- "Delete account" in the app: erases the user's cloud account. Local,
-- on-device data is untouched — deleting here only removes what was synced.
--
-- `security definer` lets this run with the privileges of the function's
-- owner (who can delete from auth.users) instead of the caller's; `auth
-- .uid()` inside the function body is still resolved from the caller's own
-- JWT, so a user can only ever delete *their own* row — never anyone
-- else's. `set search_path = ''` stops the function from being fooled by a
-- same-named object planted earlier in another schema on the search path
-- (the classic security-definer trap); every reference here is written
-- fully qualified (`auth.users`) so it still resolves correctly.
create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

-- No one gets to call this except a signed-in ("authenticated") user, and
-- only to delete themselves (enforced above, not here).
revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
