# MotoLog — current status / session handoff

_Last updated: 2026-09-26 — **v1.0.0 released** (see FINISH LINE). **Cloud session? Read docs/CLOUD-SESSION.md
first.** Read this first when starting a new
session, then CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, **586 tests** passing in ~2 min, web release build OK)
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

## FINISH LINE — owner wants the app COMPLETE in the next PC session
Scope (owner decisions): Android + web, English only, no web hosting yet,
no iOS (needs a Mac). Work through this list top to bottom; tick items here
as they land. Code items may use helper agents (worktrees, rules in memory)
if the cloud session "Extras, Import & Animations" hasn't done them.
1. [x] Sharing SQL **applied 2026-09-26** (PC session via Chrome). Review
   found a blocker: the `_insert` policies queried their own table, so
   Postgres raised `42P17 infinite recursion detected in policy` on
   **every** upload (owner included). Proven with a rolled-back dry run on
   the real project, fixed (`public.sync_row_exists()` security definer
   helper, `fix/sharing-sql-recursion`, merged), then a 13-step
   rolled-back harness passed (owner upserts; simulated Driver: assigned
   vehicle OK, other vehicle / soft delete / overwrite owner row / add
   profile / call helpers / read `transfers` all denied; visibility and
   `created_by` stamping correct). Applied; checks: 16 synced tables × 4
   policies, 0 `_own`, 4 Storage policies, `transfers` RLS on + 0
   policies, 4 internal helpers not executable, 14 RPCs authenticated
   only, no public table without RLS. Tip: to test SQL safely, wrap it in
   `begin; … ` and end with a `do` block that raises the results (forces
   rollback, shows them in the error).
2. [x] Cloud session merged `feature/extras-ui`, `feature/import-links`,
   `feature/animations` (2026-09-26, see "Extras, Import & Animations"
   below — hands-on QA list there).
3. [x] (done 2026-09-26 by the PC session via Chrome; list now has 3 URLs) Supabase → Auth → Redirect URLs: add
   `com.abdullah8873.motolog://login-callback`.
4. [x] **Cloud session #3 (Sonnet): done.** Part number / brand field on
   service items — nullable `part_number` column on `entry_items`, local
   schema **v7** (v6 was already sharing's — see the "Done" section above,
   so this bumped the version instead of reusing it), migration +
   `test/schema_v7_test.dart`. Sync needs no mapping changes: push/pull is
   generic over `TableInfo.$columns` (`lib/core/sync/sync_engine.dart`), so
   the new column flows through automatically — covered by the migration
   test's outbox-trigger check. Service type picker row (a "Part number /
   brand" field under a service line, service only), record detail
   (`record_detail_screen.dart`), CSV/Excel/PDF export (`Part Number`
   column in `entryExportHeaders`) and CSV import (backward compatible:
   optional header, like `Currency`) all updated, with tests. Branch
   `feature/part-number`, merged into `develop` after `feature/import-links`
   landed there.
   - **SQL to apply (PC session, Supabase SQL editor via Chrome):**
     `supabase/migrations/20260927000001_part_number.sql` — **applied 2026-09-26** (column verified: `text`).
     Adds `part_number text` to `public.entry_items` (idempotent, no RLS
     change — existing entry_items policies already cover every column).
     Run after `20260926000001_sharing.sql`. Not verified on a real
     Postgres.
5. [x] Release APK with sync — **1.0.0 build 3** (`versionCode` 2003 on
   arm64) sent to the owner; smoke-tested on `motolog_api36` (vehicle,
   service with part number, detail, Reports share image + PDF, About,
   Contact, sheets). Build 2 went out earlier the same day; build 3 adds
   the QA fixes below and installs over it.
6. [x] Hands-on QA (2026-09-26) — found and fixed (branch
   `fix/qa-release`, merged):
   - **Transfer never worked:** `transfer_copy()` put its boolean into
     the SQL with `format('%s')` → `column "f" does not exist` on every
     redeem. Fixed + `20260926000002_transfer_copy_fix.sql` **applied**;
     rolled-back live harness with both real accounts passes (buyer gets
     vehicle/records/items/catalog; own/used/unknown/cancelled codes
     rejected).
   - Web DB recorded as v7 without `part_number`/`created_by` (History:
     "no such column") in the Claude browser pane after stale builds →
     `addMissingColumns()` now runs in `beforeOpen` (self-heal) + tests.
     The owner's Chrome DB was fine. Root cause not pinned down; the pane
     DB was wiped. Watch for it if web is ever deployed.
   - Bottom sheets (Reports share, Contact) opened under the bottom bar →
     root navigator. App label "motolog" → "MotoLog" (Android/iOS/
     Windows). "Open it in this browser" → "on this device" off the web.
     Unknown web URL → themed "Page not found" (was go_router's raw page).
   - Animations vs Drivvo (BlueStacks): Drivvo's speed dial and tab
     switches are instant, so `Motion.short` 200 → 150 ms and
     `Motion.medium` 280 → 250 ms.
   - Verified OK: sharing steps 1–5 (invite as Driver → banner → accept →
     owner's account with only own records, pick lists, no Reports, More
     hides admin rows, member refueling syncs with `created_by` = member
     and the owner sees it; Driver → Manager brings in all records;
     Account switcher + Leave shown); live sync with part number; Android
     deep link (`login-callback` error callback opens the app and shows
     the expired-link message; Supabase issues links with the Android
     redirect); web persistent-storage request (Chrome decides:
     `persisted()` false on localhost, as expected).
   - Not done hands-on (owner can, optional): sharing steps 6 (custom
     profile), 3 (denied write via another route); photo attachment by a
     member; Transfer through the UI (SQL path verified); real email link
     opened from the phone's mail app; dark theme on the sharing screens
     (covered by `test/dark_theme_test.dart`).
7. [x] **CI part (cloud session #3): done.** Re-enabled CI — moved
   `.github/workflows-disabled/*` to `.github/workflows/`, added
   `--timeout 45s` to the test step (perf tests already skip by default via
   `dart_test.yaml`'s `perf` tag). PR
   [#1](https://github.com/Abdullah8873/Drivvo/pull/1) merged into
   `develop` at `b76f98e`, all 3 jobs green (format/analyze/test, build
   web, build debug APK).
   [x] PC session: version 1.0.0+3, `develop` merged into `main`, tagged
   `v1.0.0`, pushed (2026-09-26).
8. [x] **MotoLog 1.0.0 is released** (Android + web, English). 598 tests.
   Owner-only leftovers:
   - Google sign-in: `docs/SETUP-CLOUD.md` steps 4 (web) and 5 (Android).
   - Play Store: create an upload/signing key (release APKs are signed
     with the debug key today — fine for sideloading, not for the Store).
   - Web hosting (COOP/COEP notes in `web/index.html`), then add the
     hosted URL to Supabase → Auth → Redirect URLs and Site URL.
   - iOS: needs a Mac (Xcode) — code already supports it.
   - Optional QA listed under item 6; password-reset and delete-account
     live tests (see Next 1).
   - Test data in Supabase: the owner's account has a "honda" vehicle with
     a QA Battery service + a refueling made by the test member
     (abdullahworks337, currently Manager) — delete or keep as you like.
   - **Drivvo data imported (2026-09-26):** all 17 Drivvo records of "Honda
     Moto 18" (10 refuelings = PKR 23,171 incl. the Petrol + High Octane
     fill; 7 services = PKR 23,510 with all 34 items, workshops as places,
     gas station Aramco Moon Market) were read from BlueStacks (view only),
     written as a MotoLog CSV zip and imported into the owner's "Honda
     125" via Export → IMPORT CSV; server totals verified. Times weren't
     copied except 2025-06-11 11:50 (others 12:00; the 2026-07-29 service
     11:00 so it sorts before that day's fill). Drivvo had no reminders.

## HANDOFF 2026-09-26 evening (PC session hit 88% of the 5-hour limit)
Owner wants the app complete today (Android + web features; English only;
no web deploy; iOS impossible without a Mac). Two unmerged branches are
**pushed to GitHub** — finish, check and merge them:
- `feature/extras-ui` (Sonnet agent, stopped): About / Contact (email left
  empty on purpose — `lib/core/app_info.dart`) / Translation ("English")
  / Share app screens + Reports "Share as image / PDF". Last commit is a
  **WIP test fix, unverified** — run its tests (`test/extras_ui_test.dart`),
  fix, full suite, merge.
- `feature/import-links` (Opus agent, stopped): CSV import on the Export
  screen with preview + tests, `navigator.storage.persist()` on web,
  Android/iOS deep link for emailed auth links. Was about to add a widget
  test for the import preview dialog. Check it compiles for web
  (`flutter build web --release`), full suite, merge. Then list in STATUS
  the Supabase redirect URL to add (`com.abdullah8873.motolog://login-callback`)
  — the PC session adds it via Chrome.
- **Animation polish pass (owner request):** the app has NO custom
  transitions (pure Flutter defaults, tab switches instant). Add: screen
  slide-in transitions (`pageTransitionsTheme` / go_router pages), + speed
  dial expand animation, soft fade between main tabs, cards/charts ease-in;
  ~200–300 ms, respect `MediaQuery.disableAnimations`. The PC session will
  compare with Drivvo in BlueStacks afterwards and tune.
- **Android:** first release APK built and installed on the owner's phone
  (Android 12+ target — owner doesn't need older phones tested); adding a
  refueling works. It's an **offline build** (no `env/cloud.json`). Next
  APK (PC session): `flutter build apk --release --split-per-abi
  --dart-define-from-file=env/cloud.json` after the deep link merges.
  Emulator `motolog_api36` exists (Android 16); an ANR seen there was the
  PC at 100% CPU / 250 MB free RAM, not the app. Release build tip: stop
  stray Gradle/Kotlin daemons if you see "file used by another process".
- Sharing batch: **merged** by the cloud session — see the next section.
## Extras, Import & Animations — merged 2026-09-26 by a cloud session
All three branches are merged into `develop` and pushed (`c5afe76`,
`a484ebb`, then `feature/animations`); each was merged with the latest
`develop` first (sharing included). Format clean, analyze 0 issues,
**586 tests pass**, `flutter build web --release` OK.
- **`feature/extras-ui`:** About / Contact / Translation / Share app +
  Reports "Share as image / PDF". The WIP test hung because `toImage()`
  never completes under the test binding: the capture is now behind
  `reportImageCaptureProvider` (real `toImage` in the app, stubbed in
  tests), and a failed capture/share shows "Couldn't share the report"
  instead of an unhandled error. Merge conflicts with sharing (More
  screen, router) resolved keeping both.
- **`feature/import-links`:** CSV import (Export screen → IMPORT CSV,
  preview dialog), `navigator.storage.persist()` on web start-up, Android
  + iOS deep link for emailed auth links. Added preview-dialog widget
  tests (cancel, duplicates-only → IMPORT disabled, not-an-export, damaged
  zip); the counts/problems/type-choice test was already there.
- **`feature/animations`** (`lib/core/widgets/motion.dart`):
  - **Root cause of "no transitions":** go_router 18 detects the app type
    through `package:material_ui`'s `MaterialApp`, which is not the
    `package:flutter` class this app uses, so every route was a
    `NoTransitionPage`. Routes now build Flutter `MaterialPage`s (router
    `_page` helper — **use `_page(...)`, not `GoRoute(...)`, for new
    routes**).
  - Screens slide in from the right + fade (280 ms), the screen below
    drifts left; iOS/macOS keep Cupertino (swipe back).
  - Speed dial grows out of the + with a fading backdrop; + spins into ×.
  - Soft fade (200 ms) when switching main tabs.
  - Reports: period card, stat cards and charts fade/slide in, staggered
    40 ms (max 5).
  - All off when the OS asks for reduced motion (`test/motion_test.dart`).
- **Supabase redirect URL to add (PC session, via Chrome):** Auth → URL
  Configuration → Redirect URLs → add
  `com.abdullah8873.motolog://login-callback` (FINISH LINE item 3). Until
  then Supabase ignores it and emailed links on Android go to the Site URL.
- **Needs hands-on QA on the owner's PC:**
  - Animations in Chrome and on the phone/emulator, compared with Drivvo in
    BlueStacks: screen push/pop, speed dial, tab switch, Reports cards;
    tune `Motion` durations/offsets if they feel off. Check Android's
    predictive back gesture still works, and that turning off animations
    (Android: Settings → Accessibility → Remove animations) removes them.
  - Reports → Share → image and PDF on web (download) and Android (share
    sheet); a long report is captured cropped to the visible part (known,
    documented in `reports_screen.dart`).
  - About (version shows), Contact → Send feedback, Share app on Android.
  - Export → IMPORT CSV with a real export (.csv and .zip) in Chrome and
    on Android (file picker); importing the same file twice skips all.
  - Web: DevTools → Application → Storage shows persistent storage granted
    (Chrome may grant it silently only for installed/engaged sites).
  - Android email link: after the redirect URL is added and a cloud APK is
    built, request a sign-in link on the phone and open it from the phone's
    mail app → app opens signed in.

## Sharing batch — merged 2026-09-26 by the cloud session (code only)
Users, access profiles, profile editor, invite banner, account switching,
Transfer. Design + what differs from the plan: `docs/SHARING.md` (top).
Local schema **v6** (`created_by` on record tables, `access_profiles`,
`account_members`). Format clean, analyze 0 issues, **551 tests pass**
(34 new: `sharing_sync_test`, `transfer_test`, `sharing_model_test`,
`sharing_screens_test`; the in-memory cloud mirrors the new RLS).
- **SQL to apply (PC session, Supabase SQL editor via Chrome):**
  `supabase/migrations/20260926000001_sharing.sql` — **applied 2026-09-26** (see FINISH LINE 1). Ran it
  once after the three existing files (idempotent). It replaces the
  owner-only table + Storage policies with owner-or-`can_access()` ones;
  the owner's own access is unchanged. Then check: 17 tables × 4 policies
  (`<table>_select/_insert/_update/_delete`, no `_own` left), 4
  `attachments_*` Storage policies, table `transfers` with RLS on and no
  policies, functions listed in section 8 of the file (the three helpers
  `profile_permissions`, `account_display_name`, `profile_label` must NOT
  be executable by `authenticated`). Reviewed line by line by an Opus
  agent; its findings are fixed (decline was a no-op, upsert vs insert
  policy, members raising their own profile, Storage read by id). **Not
  verified on a real Postgres** (none in the cloud session) — if the editor reports an
  error, fix it in a new file or in this one before anyone uses sharing
  (nobody depends on it yet).
- **Hands-on QA (PC, two accounts — needs the owner's 2nd test account):**
  1. Owner: More → Users → + → invite the 2nd account's email as Driver
     with one vehicle assigned → SHARE text; row shows "Invitation
     pending". Sync.
  2. 2nd account (another browser profile, email confirmed): banner "<Owner>
     invited you … as Driver" above the bottom bar → ACCEPT → OPEN. Vehicle
     chip shows "<Owner>'s account"; only the assigned vehicle; no owner
     records (own-records scope); pick lists present; Reports says no
     access; More hides Vehicles/Users/Profiles/Forms/Transfer; + menu
     works; add a refueling with a photo → syncs; owner sees it (+ photo).
  3. Driver tries a delete (not offered in UI — optional: edit via another
     route) → `/sync` shows "N changes were not allowed" and the record
     comes back.
  4. Owner changes the member to Manager / adds a vehicle → member's next
     sync re-downloads (all vehicles/records appear). Owner removes the
     member → member's app falls back to "My data".
  5. My account → Account row switches My data ⇄ shared; "Leave …" works.
  6. Profiles: built-ins read-only; + custom profile (toggles, expand rows,
     switches) → assign to member → effect after sync.
  7. Transfer: owner → Generate code for a synced vehicle (with an
     attachment) → COPY/SHARE; 2nd account (on "My data") → Redeem →
     vehicle + history + photo arrive; errors for own/used/expired/
     cancelled code; cancel a pending code.
  8. Dark theme + 360×640 pass over Users, Profiles, profile editor
     (segmented buttons at 320 px), Transfer, banner.
- Not done / follow-ups: invitation emails (by design: none); a shared account's emptied local DB file isn't deleted from
  disk (wiped instead); Storage download for a member relies on the new
  `can_read_attachment_object()` policy (QA step 2). Perf idea if a big
  shared account pulls slowly: for assigned-scope members, filter pulls by
  `vehicle_id in (assigned)` so RLS doesn't scan the whole account.

## PAUSED 2026-09-26 (owner switching to a new session) — resume here first
Optimization & compatibility pass (Next 2) is **merged into `develop` and
pushed** (`9920c9f`): `feature/perf-sync` then `feature/compat-layout`.
Format clean, analyze 0 issues, **513 tests pass**. No processes running.
- Perf results (big dataset, median): History month cards 2446 → 3 ms,
  loadTimeline 256 → ~150 ms, groupByMonth 78 → 8 ms, consumption input
  108 → 12 ms, reports all-time general 79 → 6 ms, full sync pull 11.8 →
  2.8 s, push at 100 ms/call latency 10.6 → 5.0 s; v5 indexes cost ~0.6 ms
  per write, v4→v5 migration 122 ms on the big DB. Benchmark:
  `flutter test --run-skipped -t perf test/perf -r expanded > perf.txt`.
- **No Supabase SQL needed:** every synced table already has the
  `(owner_id, server_updated_at, id)` pull index.
- Compat: minSdk 24, R8 shrink on release, `MaxWidthBody` on tablets, lazy
  lists, web title/theme color; `--wasm` build compiled OK (not yet run in a
  browser). No COOP/COEP on purpose (breaks OSM tiles + Google OAuth — see
  `web/index.html` comment).
- **Web data-loss bug found and FIXED (2026-09-26, `536682d`, 517 tests):**
  drift 2.35's WASM/IndexedDB backend only writes to IndexedDB after a
  plain statement outside a transaction; transaction COMMITs and
  `insertReturning` (vehicle saves) never triggered it, so a reload lost
  recent saves. `lib/core/db/persist_writes_interceptor.dart` (web only)
  fixes it; verified in real Chrome (refueling saved 1 s before a reload
  survives). Native (Android/iOS) was never affected.
- **Hands-on QA done (local session):** v5 DB opens clean; add vehicle +
  refuelings; History month card/rows; Reports at 320 px; tablet 1024 px
  (centred max-width body). km/L on the first row of a cycle is correct —
  it's the "Average position: at the start of the cycle" setting (Drivvo
  default), not a bug.
- **QA still to do (local session only — needs the browser):** dark theme
  pass, one live sync to Supabase (parallel tier pull), open a `--wasm`
  build. Text scale 2× is covered by `test/layout_matrix_test.dart`.
  Tip: the browser pane / Chrome tab only renders while its window is in
  front — screenshots time out and clicks do nothing otherwise.
- **Web durability (cloud session can do this, code only):** call
  `navigator.storage.persist()` once on web start-up (e.g. in `main.dart`
  via `package:web`) so the browser doesn't evict IndexedDB under disk
  pressure; currently `persisted() == false`.
- **Android (local session):** SDK installed via Android Studio, SDK
  license accepted. `cmdline-tools` still missing (owner: Android Studio →
  Settings → Android SDK → SDK Tools → "Android SDK Command-line Tools") —
  needed for creating an emulator. First release APK build started
  2026-09-26 (`flutter build apk --release --split-per-abi`).
- Old worktrees under `.claude/worktrees/` (27): every branch is merged
  into `develop` **and pushed to GitHub** (2026-09-26), so nothing is lost
  if a worktree folder disappears. Their only uncommitted changes are
  auto-regenerated `windows/flutter/generated_plugin*` files. **Keep them —
  owner wants them kept; don't remove worktrees or branches without asking.**
- **Sharing batch: built and merged** — see "Sharing batch" above (SQL to
  apply + QA list). Needs a 2nd test account from the owner for QA.
- **Android email deep link (cloud session can write it):** custom scheme
  + intent filter + `authRedirectUrl()` TODO; the redirect URL must also be
  added in Supabase (local session, via Chrome).
- **Split of work (owner has Claude cloud credits):** the cloud session does
  code + tests + merges (sharing batch, persist(), deep link). The local PC
  session does only what needs the PC: browser QA, BlueStacks/Drivvo
  checks, Supabase dashboard via Chrome, Android builds/emulator/phone.
  Both can run at once: cloud pushes a branch, local pulls it and QAs.

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
- A 2nd test account (email you can confirm) for the sharing/Transfer QA,
  and applying `20260926000001_sharing.sql` (see "Sharing batch").
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
