# MotoLog — current status / session handoff

_Last updated: 2026-09-24. Read this first when starting a new session, then
CLAUDE.md, docs/PLAN.md and docs/SPEC.md._

## Done (merged into `develop`, pushed, 246 tests passing)
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

## In flight — finish these first
1. **`fix/reports`** (worktree `.claude/worktrees/agent-a878dbbb02b71627f`,
   pushed as WIP, UNTESTED). Remaining from the Reports audit:
   - fuel-chip selection must never fall back to "All" figures; record count follows chip
   - two-tank: never add L + kg (Volume card, fuels donut, "All" chip unit,
     chart units, station rows)
   - Expense/Service/Income donut: spread discount across items
   - General income = income entries only (exclude route values)
   - Reading tab: distance from last reading before period; daily avg / period days
   - Balance = cost − income (Drivvo shows positive spend)
   - route by-km only finished routes; chart x-labels overlap; y-labels repeat;
     legend ellipsis; one efficiency line per fuel; StatGrid 2 columns ≥320px
   - LOW: 1-decimal daily averages, "Cost / <unit>" label, cost/km period average,
     "today" refresh, delete placeholder tab, Lower/Larger row overflow
   → Check `git diff develop` on the branch, finish, test (`--timeout 45s`), merge.
2. **`fix/narrow-ui`** (worktree `.claude/worktrees/agent-a7ae25d61142f4840`,
   pushed as WIP, UNTESTED): bottom-nav label wrap, speed-dial menu off-screen
   on short phones (HIGH), vehicle-type dialog wrap, remove "PKR" prefix from
   refuel Price/Total/Liters, full-width month card, 2-line history subtitle.
   → Finish tests (`test/narrow_ui_test.dart`), merge.
3. After both merge: repeat hands-on QA on the phone-sized preview
   (`.claude/launch.json` → `motolog-qa`, port 8086, separate data), then ask
   the owner to review.

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
Opus for hard logic/calcs/migrations, Sonnet for UI · ≤2–3 agents at once ·
verify against real Drivvo (BlueStacks) before building · self-review before
asking the owner · push every merge.
