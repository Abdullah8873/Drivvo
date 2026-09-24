# MotoLog — current status / session handoff

_Last updated: 2026-09-24 (afternoon). Read this first when starting a new
session, then CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, 269 tests passing in ~50 s)
- M1 app shell · M2 database (drift, seeded catalogs with deterministic ids +
  v2 dedupe migration) · vehicles · settings · catalogs
- M3 all record forms: refueling (multi-fuel, SECOND FUEL header, auto-calc),
  expense/service/income (Drivvo inline "Value" price in the type picker,
  installments), route (trip/freight, open routes), reading, reminders
- M4 History (timeline, month cards, expand-in-place, detail view, search,
  upcoming-reminders strip) using the shared consumption engine
- M5 Reports: period filter, General + Refueling + Expense/Service/Income/
  Route/Reading tabs
- Self-review round 1 fixes: logic (installments, reminders, DST), history
  engine, forms polish + "Discard changes?" guard, settings/vehicles fixes
- Reports audit (`fix/reports`): fuel chip never falls back to "All", no
  L + kg sums, discount spread across items, balance = cost − income,
  reading distance from last reading before period, chart label fixes; line
  chart no longer freezes on float-noise price ranges (293.03 vs
  293.03000000000003)
- Narrow-phone UI (`fix/narrow-ui`): one-line nav labels, scrollable speed
  dial on short screens, vehicle-type dialog, refuel row without "PKR",
  full-width month card, 2-line history subtitle

## In flight — finish these first
1. Hands-on QA of `develop` on the phone-sized preview (`.claude/launch.json`
   → `motolog-qa`, port 8086, separate data); fix findings; then ask the
   owner to review.

## Next milestones
- M6 Cloud: Supabase auth (optional login; email+password, Google, magic
  link/OTP), sync, attachments, sharing, security review. **Needs the owner.**
- M7 Extras: notifications (flutter_local_notifications), export CSV/Excel/PDF
  + local backup/restore, checklists, My places map, flex calculator,
  achievements (+ timeline events), dark theme polish, i18n, brand list for
  manufacturer, user-review improvements listed in docs/PLAN.md.
- M8 Ship: APK on phone, web deploy, CI/CD re-enable (parked in
  `.github/workflows-disabled/`).

## Needs the owner (batch these)
- Android Studio first-run wizard (installs Android SDK) + Windows Developer Mode
- Supabase project (Mumbai/Singapore) → URL + anon key (never the service key)
- Google Cloud OAuth clients (Web + Android) → enable Google provider in Supabase
- Test on phone and give feedback

## Working rules (see memory)
Complete agent instructions up front · `flutter test --timeout 45s` ·
cheapest capable model (Haiku small/mechanical, Sonnet UI, Opus hard
logic/calcs/migrations) · up to 7 agents at once for independent work ·
tests run in background with `-r expanded > file` (never `| tail`) ·
verify against real Drivvo (BlueStacks) before building · self-review before
asking the owner · push every merge.
