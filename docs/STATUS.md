# MotoLog — current status / session handoff

_Last updated: 2026-09-25 (evening). Read this first when starting a new
session, then CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, 443 tests passing in ~2 min, web release build OK)
- M1 app shell · M2 database (drift; schema **v4**: seeded catalogs with
  deterministic ids, v2 dedupe, v3 `sync_outbox` + triggers, v4 attachments +
  checklists) · vehicles (manufacturer = searchable brand picker,
  `vehicle_brands.dart`, initial avatars, no logos) · settings · catalogs
- M3 all record forms · M4 History · M5 Reports (+ audit fixes: no L + kg sums,
  fuel chips, balance = cost − income, chart freeze on float-noise ranges,
  duplicate axis labels) · narrow-phone UI fixes (hands-on QA'd at 360×640)
- **M6 cloud (live on Supabase, core sync verified — see Next 1):**
  - Optional login (`lib/features/account/`): email+password, emailed
    sign-in/confirmation/password-reset **links** (no deep link on
    Android yet — web only, via `Uri.base.origin`; see the
    `authRedirectUrl()` TODO), Google (web OAuth redirect; Android native
    `google_sign_in` v7 → ID token), My account (name, driver's license
    fields → `profiles`), sign out, delete account (removes the user's
    Storage files first, then `delete_my_account()` RPC).
  - Failed email links (expired / reused / opened in another browser) show a
    SnackBar and no longer kill the auth listeners (`auth_state.dart`:
    Supabase replays the error on `onAuthStateChange`). **Links only sign in
    in the same browser that requested them (PKCE)** — sign-up confirmation
    still confirms, the user then signs in.
  - Sync (`lib/core/sync/`): SQLite triggers fill `sync_outbox` on every
    change → push in batches; pull by `(server_updated_at, id)` cursor with a
    30 s overlap; last-write-wins by `updatedAt` (server trigger skips older
    and identical writes); pull before push, parents before children;
    file step after push (upload attachments to Storage bucket
    `attachments/<uid>/<id>/<name>`, remove deleted ones; download on view);
    `/sync` screen; different-user dialog; auto-sync on sign-in/resume/edits.
  - SQL: `supabase/migrations/20260924000001_sync_tables.sql`,
    `…000002_account.sql`, `20260925000001_attachments_checklists.sql`
    (RLS owner-only everywhere; reviewed; idempotent).
  - Config: `lib/core/cloud/` — `env/cloud.json` (git-ignored) via
    `--dart-define-from-file`; no config ⇒ offline-only build.
- **M7 extras done:** reminder notifications (planner in
  `core/calc/notification_plan.dart`, flutter_local_notifications; Settings →
  "Send test notification"; gas-station notifications out of scope), export
  CSV/Excel/PDF (`/export`, History ⬇; incl. Checklists), backup/restore JSON
  (Settings → Backup & restore; incl. attachment bytes as base64; excludes
  this device's `sync_state`), Flex calculator (`/flex`), Achievements
  (`/achievements`) + achievement rows in History (never in totals),
  **attachments** (every form, viewer, paperclip in History, More → Storage
  `/storage`), **checklists** (More → Forms `/forms` template editor, seeded
  "Pre-trip inspection"; `/add/checklist` OK/Problem/N/A + note; blue History
  rows, never in totals/reports), **My places** (`/places`, list + map with
  flutter_map/OSM + location picker on place/gas-station forms, geolocator),
  **dark theme** sweep (`test/dark_theme_test.dart`). Hands-on QA'd at
  360×640 in light + dark (brand picker, checklist save/expand, Storage,
  Reports, map tiles + attribution).

## Next — pick up here
1. **Cloud is live and v4 is applied (2026-09-25).** Supabase project
   `motolog`, ref `ibizgqnhurgvhyclfqza` (ap-northeast-2). All three SQL
   files applied (v4 run by Claude via the owner's Chrome; verified: RLS on
   all 15 tables, private `attachments` bucket 10 MB, 4 storage + 20 table
   policies). Site URL `http://localhost:8085`, redirect URLs 8085 + 8086.
   Run: `.claude/launch.json` → `motolog-cloud` (port 8085). `motolog-qa`
   and `motolog-cloud` share `build/web` — restart the one you test.
   - **Verified live 2026-09-25:** v4 sync (seed template + items pushed),
     pull of a server-inserted row, **conflicts** (older remote write ignored
     by the server trigger, newer remote write wins and is pulled),
     **attachment upload** to Storage under `<uid>/…` + download, anon
     cannot read/list files, **delete cascade** (vehicle → reading →
     attachment soft-deleted with one timestamp, Storage object removed),
     **"Email me a sign-in link"** end to end in Chrome (same browser).
   - Owner's app account: abdullahsadiq427@gmail.com (Gmail `u/1` in their
     Chrome; `u/0` is a different address).
   - **Still to test (needs the owner):** password reset → "Set new
     password" (owner types the password); delete account on a throwaway
     `+test` account (creating accounts/typing passwords is owner-only).
   - Google sign-in not configured yet (owner: SETUP-CLOUD.md step 4).
   - Claude-in-Chrome tips: Flutter web ignores the extension's wheel
     scroll — use Tab to move focus; the first click after switching tabs
     can be swallowed; upload files by patching
     `HTMLInputElement.prototype.click` then `file_upload` on the input.
2. **Optimization & compatibility pass (owner request 2026-09-25: "works
   great across new and old devices and different OSes").** One Opus agent
   (perf/sync) + one Sonnet agent (layout/compat), then hands-on QA:
   - Measure first: seed a big dataset (e.g. 3 vehicles × 5k records +
     attachments), profile startup, History scroll, Reports, sync
     (`flutter run --profile`, DevTools). Fix what the numbers show.
   - Sync: pulls run table by table sequentially (~12 × 250 ms seen live) —
     run independent tables in parallel within a parent/child tier; batch
     pushes already exist. Reports/consumption math on big data → `compute`
     isolate if it janks. DB indexes on `(vehicle_id, date)` for the record
     tables if missing (schema v5, same migration rules).
   - Lists: History/catalog/select lists must be lazy (`ListView.builder` /
     slivers), no `Column` of all rows.
   - Old/low-end Android: check the effective `minSdk` (plugins may need
     ≥ 23/24) and state it; test on API 23/28 + a recent emulator; release
     APK with `--split-per-abi` (smaller), R8 shrink; Impeller fallback
     issues on old GPUs. iOS target is 15.0 (fine).
   - Web: works in Chrome/Edge/Firefox/Safari; drift currently falls back to
     `sharedIndexedDb` (no SharedArrayBuffer) — serve COOP/COEP headers on
     the deployed site for OPFS; consider `--wasm` with automatic JS
     fallback; self-host CanvasKit (`--no-web-resources-cdn`) so it loads
     offline; PWA install.
   - Layout: 320 dp phones, tablets/landscape, large system font
     (textScaler 1.3–2.0), RTL later with i18n; dark theme already done.
3. **Then:** sharing/users/profiles/Transfer (Opus, alone — new SQL + RLS
   for `vehicle_members`); small items (About/Contact/Share app, Reports
   share-as-image/PDF, part number on service items, CSV import); i18n last.
4. M8 Ship: APK on phone (+ Android deep link for email links), web deploy,
   CI/CD re-enable (parked in `.github/workflows-disabled/`).

## Needs the owner (batch these)
- Password-reset and delete-account live tests (see Next 1).
- Google sign-in: `docs/SETUP-CLOUD.md` step 4 (web) and step 5 (Android).
- Android Studio first-run wizard (Android SDK) + Windows Developer Mode
  (plugin symlinks for the Windows build) — also needed for the old/new
  Android emulator testing in Next 2.
- On a phone later: notification permission prompt, "Send test
  notification", notifications after reboot, share sheet for export/backup,
  camera attachment.

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
