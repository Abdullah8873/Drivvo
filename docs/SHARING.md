# Sharing, users, profiles and Transfer — design

Decided 2026-09-25 (before building). UI verified against Drivvo: see
`docs/SPEC.md` "Users, Profiles, Transfer". Permission model:
`lib/core/calc/access_profile.dart` (pure, tested — build on it, don't fork it).

## Concepts

- **Account** = one owner's data (vehicles, records, catalogs, forms). The
  server already namespaces every row by `owner_id` (PK `(owner_id, id)`), so
  an account is simply "all rows with `owner_id = X`".
- **Member** = another signed-in user the owner invited, with one
  **access profile** (Administrator / Manager / Driver / custom) and, when the
  profile's vehicle scope is `assigned`, a list of assigned vehicles.
- The owner is always Administrator of their own account and can't be
  removed. Managers can manage members/profiles/vehicles but can't delete
  the account, transfer ownership, or remove the owner.

## One active account per device session (key decision)

A device works on **one account at a time**: the user's own (default) or a
shared account they joined. Each account has its **own local SQLite file**
(`motolog` for the user's own data — unchanged, so no migration of existing
installs — and `motolog_acct_<ownerId>` for each joined account).

Why: seeded catalog ids are the same in every account (`seed:fuel:petrol`),
and local primary keys are `id` only. Mixing accounts in one local DB would
mean changing every local PK and every query; a DB per account keeps all
existing screens, queries, reports and the sync engine unchanged — the sync
engine just runs with `ownerId = <active account owner>` instead of
`auth.uid()`.

- Switching: More → My account → "Account" row (only shown once the user
  belongs to a shared account) → pick "My data" or "<Owner name>'s account".
  The app closes the current DB, opens the other, resets providers (Riverpod
  scope rebuild) and syncs. Remember the choice per device.
- The `VehicleSwitcher` chip shows the account name under the vehicle when a
  shared account is active, so it's always obvious whose data you're editing.
- Offline-first still holds: records a driver adds offline go to the shared
  account's local DB and are pushed later; the server enforces permissions on
  push (RLS) — rejected rows are reported on `/sync` and rolled back locally
  by re-pulling the server version.

## Server (new SQL file, idempotent, never edit old ones)

- `created_by uuid` on every record table (default `auth.uid()`), plus a local
  nullable `created_by` column (schema bump, same migration rules). Needed for
  the "own records" scope.
- `access_profiles(owner_id, id, name, permissions jsonb, …sync columns)` —
  custom profiles only; built-ins live in code (`BuiltInProfile` ids) and the
  SQL function mirrors them. (Not called `profiles`: that table already holds
  the user's name/driver's license.)
- `account_members(owner_id, id, email citext, member_id uuid null,
  profile_id text, status pending|active|removed, invited_by, …)` and
  `member_vehicles(owner_id, member_row_id, vehicle_id)`.
- Invites have **no email sending** (owner decision: no SMTP). The owner adds
  an email; when that user signs in, the app calls `my_invitations()` (matches
  `auth.email()`, case-insensitive, verified email only) and shows a banner /
  dialog: "<Owner> invited you to their account as Driver — Accept /
  Decline". `accept_invitation(id)` sets `member_id` + `active`. The owner can
  also share an invite link/text via the share sheet ("Sign in to MotoLog with
  <email> to join").
- `public.can_access(owner uuid, area text, action text, vehicle_id text,
  created_by uuid) returns boolean` — `security definer`, `stable`: true when
  `owner = auth.uid()`, else looks up the caller's active membership + profile
  permissions (built-in JSON inlined) + vehicle assignment + record scope.
  Every data table's RLS becomes `owner_id = auth.uid() or can_access(...)`
  for select/insert/update/delete with the matching action (update = edit,
  insert = register). Child rows (refueling_fuels, entry_items,
  checklist_answers, attachments) check through their parent's vehicle; add a
  denormalized `vehicle_id` only if the parent lookup is too slow.
  Catalog rows map `kind` → catalog area; vehicles → `vehicles` area (drivers
  can always *view* their assigned vehicles).
- Storage policies: members may read/write `attachments/<owner>/…` objects
  whose attachment row they can access.
- Pull for a shared account uses the same `(server_updated_at, id)` cursor per
  `owner_id`; RLS filters what a member receives. When a member loses access
  to a vehicle, the next pull must remove those rows locally (the server
  can't send "deleted" for rows you can no longer see): after an access
  change, do a full re-pull of the shared account (drop local DB, resync) —
  simple and correct.
- Removing a member / leaving: membership `removed`; the member's device
  deletes that account's local DB file on next sync and falls back to "My
  data".

## Client-side permissions

A `currentAccessProvider` (Riverpod) exposes the active `AccessProfile` (the
owner gets `AccessProfile.administrator()`), and helpers used by the UI:
hide the speed-dial entries the profile can't `register`, hide Edit/Delete on
record detail, hide Reports tab content without `report.view` (show a short
"You don't have access to reports" empty state), hide More → Vehicles / Users
/ Profiles / Forms without administration view, filter the vehicle switcher
to assigned vehicles (the server already only sends those). UI checks are
convenience; RLS is the real guard.

## Transfer (More → Transfer)

"Send a **copy** of the history to the buyer" — the seller keeps theirs.

1. Seller: FAB → **Generate transfer code** → pick a vehicle → server RPC
   `create_transfer(vehicle_id)` returns an 8-character code (no ambiguous
   characters, e.g. `K7QM-3XPD`), valid **7 days**, single use; screen shows
   the code big with Copy/Share buttons and the expiry; the Transfer list
   shows pending/redeemed/expired codes (cancel a pending one).
2. Buyer (signed in): FAB → **Redeem transfer code** → enter code →
   `redeem_transfer(code)` (security definer) copies the vehicle, all its
   non-deleted records and child rows, the catalog items they reference
   (skip ones the buyer already has with the same id), into the buyer's
   `owner_id` with the same ids (PK is per owner, so no clash) and
   `created_by = buyer`. Reminders and checklists are included; attachments
   are included by copying their rows plus a Storage read grant on the
   seller's objects for that transfer, so the buyer's client downloads and
   re-uploads them under its own folder in the normal file step.
3. The buyer's next pull brings everything down. Redeeming your own code,
   an expired or used code, or a vehicle id the buyer already has → clear
   error messages.

Signed-out users see a "Sign in to use Transfer / Users" card with a button
to My account (local-only installs have nothing to share).

## Tests

- SQL: can't run Postgres here — keep functions small, reviewed, and mirror
  the permission logic in `InMemoryRemoteStore` (members, profiles,
  `can_access`, transfers) so sync/permission behaviour is unit-tested in
  Dart; the SQL is then verified live on Supabase (owner's Chrome) with two
  accounts.
- Widget tests for Users, Profiles, Profile editor, invite banner, Transfer
  (generate/redeem), permission-driven hiding.
