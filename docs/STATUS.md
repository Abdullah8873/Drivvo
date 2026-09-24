# MotoLog — current status / session handoff

_Last updated: 2026-09-25. Read this first when starting a new
session, then CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, 398 tests passing in ~1.5 min, web release build OK)
- M1 app shell · M2 database (drift; schema **v3**: seeded catalogs with
  deterministic ids, v2 dedupe, v3 `sync_outbox` + triggers) · vehicles ·
  settings · catalogs
- M3 all record forms · M4 History · M5 Reports (+ audit fixes: no L + kg sums,
  fuel chips, balance = cost − income, chart freeze on float-noise ranges,
  duplicate axis labels) · narrow-phone UI fixes (hands-on QA'd at 360×640)
- **M6 cloud (live on Supabase, core sync verified — see Next 1):**
  - Optional login (`lib/features/account/`): email+password, emailed
    sign-in/confirmation/password-reset **links** (no deep link on
    Android yet — web only, via `Uri.base.origin`; see the
    `authRedirectUrl()` TODO), Google (web OAuth redirect; Android native
    `google_sign_in` v7 → ID token), My account (name, driver's license
    fields → `profiles`), sign out, delete account (`delete_my_account()`
    RPC).
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
1. **Cloud is live (2026-09-25).** Supabase project `motolog`, ref
   `ibizgqnhurgvhyclfqza` (region ap-northeast-2). Both SQL files applied and
   verified (RLS on all 10 tables; `delete_my_account` not callable by anon).
   Email provider: confirm email on, min password 8. Site URL
   `http://localhost:8085`, redirect URLs 8085 + 8086. `env/cloud.json` has
   URL + publishable key. Run: `.claude/launch.json` → `motolog-cloud`
   (port 8085, `--dart-define-from-file=env/cloud.json`).
   - **Verified against the real server:** sign-up (password) + email
     confirmation, sign-in, auto-sync on sign-in (push: 1 vehicle + 153
     catalog rows under the owner's id only), pull of a server-inserted
     vehicle, soft-delete propagation. Paging `.or()` query works.
   - **Owner decision: email LINKS, no 6-digit codes, no custom SMTP**
     (merged `fix/auth-email-links`). Still to test live: "Email me a sign-in
     link", password-reset link → "Set new password", delete account, a
     conflict between two browser profiles. The owner's first confirmation
     link confirmed the account but did NOT leave a session in the app (only
     the PKCE code-verifier was in localStorage) — probably a stale cached
     `main.dart.js` (a hard refresh was needed once); re-check with the new
     build before assuming a bug.
   - Tip: after a rebuild, the browser can keep running the previous
     `main.dart.js` — hard refresh (Ctrl+Shift+R).
   - Google sign-in not configured yet (owner: SETUP-CLOUD.md step 4).
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
- Google sign-in: `docs/SETUP-CLOUD.md` step 4 (web) and step 5 (Android).
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
