# MotoLog — current status / session handoff

_Last updated: 2026-09-24 (evening). Read this first when starting a new
session, then CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, 395 tests passing in ~1.5 min, web release build OK)
- M1 app shell · M2 database (drift; schema **v3**: seeded catalogs with
  deterministic ids, v2 dedupe, v3 `sync_outbox` + triggers) · vehicles ·
  settings · catalogs
- M3 all record forms · M4 History · M5 Reports (+ audit fixes: no L + kg sums,
  fuel chips, balance = cost − income, chart freeze on float-noise ranges,
  duplicate axis labels) · narrow-phone UI fixes (hands-on QA'd at 360×640)
- **M6 cloud (code done, never run against a real server):**
  - Optional login (`lib/features/account/`): email+password, 6-digit email
    codes (sign-in, sign-up confirm, password reset — no deep links), Google
    (web OAuth redirect; Android native `google_sign_in` v7 → ID token),
    My account (name, driver's license fields → `profiles`), sign out,
    delete account (`delete_my_account()` RPC).
  - Sync (`lib/core/sync/`): SQLite triggers fill `sync_outbox` on every
    change → push in batches; pull by `(server_updated_at, id)` cursor with a
    30 s overlap; last-write-wins by `updatedAt` (server trigger skips older
    and identical writes); pull before push, parents before children;
    `/sync` screen; different-user dialog; auto-sync on sign-in/resume/edits.
  - SQL: `supabase/migrations/20260924000001_sync_tables.sql`,
    `…000002_account.sql` (RLS owner-only everywhere; reviewed; idempotent).
  - Config: `lib/core/cloud/` — `env/cloud.json` (git-ignored) via
    `--dart-define-from-file`; no config ⇒ offline-only build.
- **M7 extras done:** reminder notifications (planner in
  `core/calc/notification_plan.dart`, flutter_local_notifications; Settings →
  "Send test notification"; gas-station notifications out of scope), export
  CSV/Excel/PDF (`/export`, History ⬇), backup/restore JSON (Settings →
  Backup & restore; excludes this device's `sync_state`), Flex calculator
  (`/flex`), Achievements (`/achievements`, 20 badges verified in Drivvo) +
  achievement rows in History (presentation-only, never in totals).

## Next — pick up here
1. **Cloud end-to-end test — blocked on the owner** doing
   `docs/SETUP-CLOUD.md`. When they say "cloud is set up": run with
   `--dart-define-from-file=env/cloud.json`, test sign-up (code email),
   sync between two browser profiles (create/edit/delete, conflict),
   different-user dialog, delete account; fix what the real server reveals
   (unverified: SQL trigger/grants, the `.or()` pull-page query, Google).
2. **Next build batch (2–3 grouped agents):**
   - (Opus or Sonnet) **One schema-v4 agent**: attachments table + Supabase
     Storage bucket/policies + attach/view UI on every form + More → Storage
     screen; checklist templates ("Forms") + checklist records; place
     latitude/longitude already exist in `catalog_items` — My places map
     (flutter_map/OSM) + list. One agent owns the migration; add new tables
     to sync (triggers/outbox, SQL) and to backup.
   - (Sonnet) dark theme polish + brand list for vehicle manufacturer.
   - Later, alone: sharing/users/profiles/Transfer (needs working cloud), then
     i18n (touches every string — run last, by itself).
3. Hands-on QA of the new M6/M7 screens on the phone-sized preview
   (`motolog-qa`, port 8086) before asking the owner to review.
4. M8 Ship: APK on phone, web deploy, CI/CD re-enable (parked in
   `.github/workflows-disabled/`).

## Needs the owner (batch these)
- **`docs/SETUP-CLOUD.md`** — Supabase project + keys in `env/cloud.json`,
  run the 2 SQL files, email templates with `{{ .Token }}`, redirect URLs,
  Google OAuth (web now, Android later).
- Android Studio first-run wizard (Android SDK) + Windows Developer Mode
  (plugin symlinks for the Windows build).
- On a phone later: notification permission prompt, "Send test
  notification", notifications after reboot, share sheet for export/backup.

## Working rules (see memory)
Complete agent instructions up front (incl. "make WIP commits", "no Python on
this PC") · default **2–3 agents, each a group of related tasks** (max 7 only
for independent work at the start of a fresh usage window) · cheapest
capable model (Haiku small/mechanical, Sonnet UI, Opus hard
logic/sync/security/migrations) · tests: `flutter test --timeout 45s -r
expanded > file` (never `| tail`), DB created in `setUp`, never inside
`testWidgets` · verify against real Drivvo (BlueStacks, view only) before
building · self-review before asking the owner · push every merge ·
**one session per milestone** — update this file and start fresh.
