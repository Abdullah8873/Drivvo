# MotoLog

Personal vehicle expense & maintenance tracker (fuel, expenses, services, income,
routes, reminders, reports) — a free, self-built take on the Drivvo app, with
all of Drivvo's paid features included. Flutter app for Android, iOS, Web
(and Windows). App name: "MotoLog" (confirmed by the owner). Never use Drivvo's name, logo or
artwork inside the app.

The owner is a web developer learning mobile: when explaining work, map
Flutter concepts to web equivalents (widget ≈ component, go_router ≈ React
Router, Riverpod ≈ React Query/Context, drift ≈ Prisma/Drizzle).

## Commands

Flutter lives at `C:\dev\flutter\bin` (on PATH).

```bash
flutter pub get                                    # install deps (npm install)
dart run build_runner build --delete-conflicting-outputs   # drift codegen
dart format lib test                               # format (must be clean)
flutter analyze                                    # lint (must be clean)
flutter test                                       # all tests
flutter run -d chrome                              # run on web
flutter run -d web-server --release --web-port 8085  # preview server (see .claude/launch.json)
```

Before merging anything into `develop`: format, analyze and test must all pass
locally (CI/CD is parked in `.github/workflows-disabled/` for now).

## Git workflow

- `main` = stable releases only; `develop` = integration; `feature/<name>` per
  module/task (one per parallel agent, ideally in a worktree); `hotfix/<name>`
  from main.
- Conventional commits (`feat:`, `fix:`, `chore:`, `test:`, `refactor:`).
- Repo-local git email is the GitHub noreply address (the account blocks
  pushes that expose the private email) — don't change it.

## Architecture

```
lib/
  main.dart, app.dart           entry + MaterialApp.router (router created per app instance)
  core/theme/                   AppTheme (teal primary, underlined inputs), RecordModule enum
  core/router/app_router.dart   createRouter(): StatefulShellRoute tabs + /add/:module forms
  core/widgets/                 shared UI building blocks (see below)
  core/calc/                    pure business math (no Flutter imports) — always unit-tested
  core/db/                      drift database, tables, DAOs, seed data
  features/<feature>/           screens + feature widgets (history, reports, reminders, more, forms, ...)
test/                           unit + widget tests
```

Planned stack: Riverpod (state), drift (offline-first SQLite, also on web),
Supabase (auth, Postgres + RLS, storage, sync), fl_chart (charts),
flutter_local_notifications (reminders).

## UI conventions (match Drivvo's look)

- Every record type is a `RecordModule` with its own color + icon: refueling
  orange, expense red-orange, income green, service brown, route blue-grey,
  reading magenta, checklist blue, reminder purple. General screens use
  `AppTheme.primary` (teal).
- Main tabs: History · Reports · (+ speed dial) · Reminders · More, with the
  `VehicleSwitcher` chip in `MainTabAppBar`.
- Forms: use `ModuleFormScaffold` (module-colored app bar + rounded SAVE),
  `FieldRow` (grey leading icon + field, optional right-aligned helper),
  `PickerField` for read-only fields that open a picker, and
  `SelectListScreen` for full-screen searchable pick lists with a "+" button.
  Only the Refueling (and Vehicle) forms hide optional fields behind
  "+ More options" — Expense/Service/Income/Route forms are flat, exactly
  like Drivvo (verified). Service/Expense prices are typed inline in the type
  picker ("Value" field per ticked row). See docs/SPEC.md "Details verified
  hands-on". `features/forms/refueling_form_screen.dart` is the reference form.
- Put calculations in `core/calc/` as pure functions with tests
  (e.g. `FuelMath`), never inline in widgets.

## Code style

- Follow `flutter_lints`; keep `flutter analyze` at zero issues.
- Doc comments on public classes explaining *what* and, for non-obvious
  choices, *why*. Wrap code/JSX-like text in doc comments in backticks.
- Use `withValues(alpha: ...)` not the deprecated `withOpacity`.
- Tests: pure logic in `test/*_test.dart`; widget tests pump
  `ProviderScope(child: MotoLogApp())`.

## Spec

The full feature/UI spec — every Drivvo screen, form field, report card and
setting, gathered from a live walkthrough — is in `docs/SPEC.md`. Read the
relevant section before building a screen. **Start every session by reading
`docs/STATUS.md`** (what is done, what is in flight, what needs the owner).
When unsure how something should look or behave,
mirror Drivvo (installed in BlueStacks on this PC — view only, never change
data there).
