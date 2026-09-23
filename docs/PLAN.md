# Personal Vehicle Tracker (Drivvo-style): Plan

## Context
The user pays for Drivvo (vehicle fuel/expense/maintenance tracker) and wants a free app they build themselves,
with the same familiar UI and flow, **all** features, and everything Drivvo locks behind the PRO, Individual and Fleet plans unlocked.
The user is a web developer who is new to mobile and wants to **learn while building**. Every step gets a short explanation
that maps it to web concepts. The project folder `C:\Users\abdul\Desktop\Projects\APP` is empty, so this is a new project.
We use our own app name, logo and icons, not Drivvo's branding or artwork. The layout, flow and features follow Drivvo.

Decisions so far: Android + iOS + Web from one codebase; offline-first on the device with free cloud sync;
units and currency configurable; unlimited vehicles; vehicle sharing, checklists, income, routes/freight and EV all included;
no Drivvo import (Drivvo's export is paywalled), with a generic CSV import added later. The user allows **as many parallel agents as useful**
during implementation.

## What I found in Drivvo (live walkthrough of the user's app in BlueStacks)
### Global UI language
- Material Design (Android). **Each module has its own color**, used in its app bar, icons, save button and chart accents:
  Refueling = orange, Expense = red-orange, Income = green, Service = brown, Route = slate blue-grey,
  Reading = magenta, Checklist = blue, Reminder = purple. General screens use a teal primary color.
- Top bar: a **vehicle switcher chip** (logo, name, "model · odometer km", ▾), plus action icons (Export ⬇, Search 🔍).
  The Reports bar has Share instead of Export.
- **Bottom nav**: History · Reports · (**center round FAB +**) · Reminders · More.
- The FAB opens a **speed-dial menu** of colored round icons: Reminder, Checklist, Reading, Route, Service, Income, Expense, Refueling.
- Forms: full-screen, colored app bar with back arrow; **underlined text fields with a grey leading icon**;
  segmented toggles (e.g. TRIP | FREIGHT); a "+ More options" expander; a full-width rounded **SAVE** button in the module color.
- **Pickers** are full-screen "Select" lists with a search field in the app bar, checkboxes for multi-select, a ✓ confirm,
  and a FAB + to add a new item. Settings choices open **radio-list dialogs**.

### History (home)
- **Predicted reminders** strip at the top: e.g. a "Next refueling" card showing "57132 km · 02 oct" and "in 197 km · in 9 days"
  (predicted from average km/day and refuel frequency).
- A **vertical timeline track** on the left, with a colored circular icon per record.
- A **monthly summary card** for each month: total spent, km driven, average efficiency, and "Expenses X% below/above {prev month}".
  Drivvo blurs the X% for free users; we show it. Tapping the card opens that month's cost-comparison donut chart.
- Record row: title (fuel name, or first service type **+N more**), subtitle "odometer · efficiency · volume" or "odometer · place",
  amount on the right, date below.
- **Tapping a row expands it in place**: line items (fuel detail, or each service type with its price), efficiency,
  full-tank yes/no, station, and 🗑 delete · ✏ edit · 👁 view.
- **Detail view**: colored header with ‹ date › arrows to step through records of the same type. Cards show Odometer, Distance
  since last, Total cost, fuel line (price/L, total, volume), Complete tank, Efficiency, Cost/km, a **"% of tank" gauge**,
  then Details (station, payment method, driver) and Notes.
- **Achievement events** appear in the timeline (e.g. "Completed 1 year of tracking this vehicle").

### Reports (scrollable tabs, all with a period filter: current month, previous month, last month, last 3 or 6 months, last year, all time, custom)
- **General**: Balance (total, by day, by km), Distance (total, daily avg), Cost (total, by day, by km), Income (total, by day, by km);
  stacked monthly bar chart "Expenses and income" (refueling/expense/service/income); cost comparison donut; **Odometer line chart**
  with colored points by record type.
- **Refueling**: Cost, Volume (per refuel, per day), Average price (lowest/highest), Fuel efficiency (average, lowest, highest);
  "Refueling routine" card (km between refuels, frequency in days, estimated range, monthly projection, % of refuels with full tank);
  monthly cost bars; a **Fuel card with fuel-type chips** and range sliders showing the last value against the lowest/highest/average for efficiency and cost/km;
  gas stations list (avg price, records, liters); Fuels donut; Gas stations donut; efficiency line by odometer; fuel price line.
- **Expense / Income / Service**: totals (by day, by km), monthly bars, breakdown-by-type donut.
- **Route**: value, distance, time. **Reading**: distance, daily average, days between readings.

### Forms (the fields in each form)
- **Refueling**: vehicle, date, time, odometer ("Last odometer: N km" hint), fuel, price/L · total cost · liters (enter any 2 and the third is calculated),
  "Are you filling up the tank?" toggle, **+ Fuel** (a second fuel in the same entry), gas station, driver, payment method,
  discount, reason, "Missed previous refueling?" toggle, attach file, notes.
- **Expense**: vehicle, date/time, odometer, title, type of expense, discount, installments, place, driver, payment method, reason, attach, notes.
- **Service**: same as Expense, with **multiple service types**, each with its own price and ×, and a total cost row.
- **Income**: vehicle, date/time, odometer, value, installments, type of income, driver, attach, notes.
- **Route**: origin, start date/time, initial odometer, destination, end date/time, final odometer. TRIP mode: value per km (optional) and a total.
  **FREIGHT** mode: cargo type, contractor, unit, amount, weight, volume (m³), freight value, installments. Plus driver, reason, attach, notes.
- **Reading**: vehicle, date/time, odometer, driver, attach, notes.
- **Reminder**: vehicle, EXPENSE | SERVICE, type, JUST ONE TIME | REPEAT EVERY, then either a ☑ km trigger (odometer, or every N km)
  and/or a ☑ date trigger (a date, or every N days/months/years), notes.
- **Checklist**: templates ("Forms") plus a filled-in record per run. Drivvo locks this behind the Fleet plan, so we design it ourselves.
- **Vehicle**: type (car, motorcycle, …), name, manufacturer (brand logo), model, plate, year, ONE TANK | TWO TANKS, fuel type
  (liquids/CNG/electric…) with capacity, distance unit (km/mi/hours), VIN, registration ID, purchase price, sale price, active, notes.

### More menu
Plans (removed) · My account (first/last name, email, driver's license number, category, expiry) · Synchronize data ·
**Storage** (attachment usage by module) · **Transfer** (send a vehicle's history to its buyer, or receive it from the seller) ·
Vehicles · Users (invite drivers or managers) · Profiles (Administrator, Manager, Driver, and custom permission profiles) ·
Fuel · Gas stations (name, address) · Places (name, address) · Types of service · Types of expense (Financing, Fine, Parking,
Payment, Registration, Reimbursement, Tax, Tolls) · Types of income (Freight, Refund, Ride, Transport app, Vehicle sale) ·
Reasons (Trip, Work) · Payment methods (Credit card, Debit card, Money, Online) · Forms (checklist templates) ·
**My places** (list + map tab) · **Flex calculator** (ethanol vs gas cost comparison) · **Achievements** (badge grid: first record,
anniversaries, 1/25/50/75/100/250/500/1000 refuels, distance milestones) · Settings · Translation · Contact · About · Share app.

### Settings
- Formats: theme (light/dark/system), language, date format, **currency format** (full ISO list), display decimals, 3-decimal volumes.
- Units: distance unit (set per vehicle), liquid unit (L/gal), gas unit (kg/m³), **fuel efficiency format** (km/L, km/gal US,
  km/gal Imp, L/100km, gal US/100km, gal Imp/100km, mi/L, mpg US, mpg Imp, L/100mi, gal US/100mi, gal Imp/100mi),
  where fuel economy is shown (start or end of the refuel cycle).
- Reminders: warn N km ahead (500), warn N days ahead (30), best time for notifications (10:30), toggles for refueling / tire pressure /
  gas station notifications, vibrate.

### Paywalled in Drivvo, free in ours
No ads, cloud backup and sync, CSV/Excel export (+ PDF), attachments, dark theme, search, unlimited income, unlimited vehicles (Drivvo's free limit is 2),
users/drivers and sharing, profiles and permissions, checklists/forms, the month-over-month % insight.

### Not observable (locked or empty): designed from Drivvo docs plus our own judgment
Checklist and Form builder, custom profile permissions screen, user invite flow, search screen, attachment viewer, Transfer flow.

## Tech stack: **Flutter** (confirmed by user). App name: placeholder "MotoLog" (rename later)
Why Flutter fits this app better than React Native:
- Drivvo is a native **Material Design** app. Flutter ships Material widgets that map almost 1:1: underlined `TextField` with
  `prefixIcon`, per-screen colored `AppBar`, a notched bottom bar with a center FAB, `ExpansionTile`-style expanding rows, radio dialogs,
  `SegmentedButton`. That makes "look exactly like Drivvo" the easy path.
- One codebase covers Android, iOS, **Web and Windows desktop**, with the same pixels everywhere.
- **drift** gives typed, reactive SQLite on mobile and on web (via wasm), which is essential for offline-first. Expo's web SQLite is less mature.
- **fl_chart** covers every chart seen here: stacked bars, donuts, lines with dotted average lines, colored points.
- Dart feels familiar to a TS developer (classes, async/await, null safety). The new part is widgets instead of JSX, and I'll teach it alongside the web equivalents.

| Concern | Package | Web analogy |
|---|---|---|
| UI | Flutter Material 3 with a custom theme and per-module color tokens | MUI + theme |
| Routing | go_router (StatefulShellRoute for the tabs) | React Router |
| State | Riverpod | React Query + Context |
| Local DB | drift (SQLite, reactive streams, migrations) | Prisma/Drizzle |
| Cloud | supabase_flutter: Auth, Postgres + RLS, Storage | same |
| Sync | custom: `updated_at` / `deleted_at` columns, push/pull, last-write-wins | REST sync job |
| Charts | fl_chart | Recharts |
| Notifications | flutter_local_notifications + timezone | Web Push |
| Maps (My places) | flutter_map (OpenStreetMap, free) + geolocator | Leaflet |
| Files | image_picker, file_picker, share_plus | `<input type=file>` |
| Export | csv, excel, pdf + printing | papaparse / SheetJS |
| i18n / formats | flutter gen-l10n + intl (currency, dates) | i18next + Intl |
| Tests | flutter_test, drift in-memory DB | Jest |

Build notes: Android APK and web are free from Windows. **iOS builds need macOS**, so we'd use Codemagic's free cloud tier or a Mac later.

## Architecture
```
APP/
  lib/
    main.dart, app.dart (router, theme)
    core/theme/        module colors, text styles, input decoration (underlined + leading icon)
    core/db/           drift tables, DAOs, migrations
    core/sync/         supabase client, sync engine
    core/calc/         consumption.dart, costs.dart, predictions.dart, units.dart (pure, unit-tested)
    core/widgets/      VehicleSwitcher, SpeedDialFab, TimelineTile, SelectListScreen, ModuleForm, StatCard, PeriodFilter
    features/{history,reports,reminders,more,refueling,expense,service,income,route,reading,checklist,vehicles,settings,types,users,achievements,places,flex}/
  supabase/migrations/*.sql   (mirror of the local schema, RLS via vehicle_members)
  test/
```
Every synced table has `id uuid`, `owner_id`, `vehicle_id`, `created_at`, `updated_at`, `deleted_at`. Line items live in child tables
(`refuel_fuels`, `service_items`, `expense_items`). Installments are child rows with `parent_id` and `installment_no`. Attachments are
a polymorphic table stored in Supabase Storage. Sharing uses `vehicle_members(vehicle_id, user_id, profile_id)` plus `profiles(permissions json)`.

## Milestones (each ends runnable, with a short "what you learned" recap)
0. **Setup**: install the Flutter SDK, Android Studio (SDK + emulator) and VS Code with the Flutter extension; run `flutter doctor`; `git init` inside `APP`
   (the home folder is currently one big repo); create a Supabase project.
1. **Shell** (done by me alone, sets the patterns): theme and module colors, go_router tabs, center FAB speed dial, vehicle switcher, SelectListScreen, form scaffold.
2. **DB and vehicles**: drift schema, seed default types (fuels, services, expenses, incomes, reasons, payment methods), vehicle CRUD, settings.
3. **Parallel agents, one per module in its own git worktree**: (a) Refueling + consumption calc + tests, (b) Expense/Service/Income + installments,
   (c) Route/Freight + Reading, (d) Reminders + predictions + notifications, (e) type/places/stations management screens.
4. **History**: timeline, monthly summary cards, expand-in-place, detail view with ‹ › navigation, search, achievement events.
5. **Reports**: parallel agents per tab (General, Refueling, Expense/Income/Service, Route/Reading), plus the period filter and the month chart screen.
6. **Cloud**: Supabase auth, sync engine, attachments and Storage screen, users/profiles/sharing, vehicle Transfer.
   **Auth decisions (user, 2026-09-23):** login is OPTIONAL — the app works fully offline without an
   account; signing in (More → My account) enables backup/sync/sharing, and existing local data is
   attached to the account on first sign-in. Providers: **email + password** (sign up, login,
   forgot/reset password), **Google** (native one-tap on Android via google_sign_in + Supabase ID-token
   sign-in; OAuth redirect on web), **email magic link / 6-digit OTP code**. Apple sign-in deferred
   (only needed for an App Store release). Screens: Sign in (Google button, email field → password or
   "email me a code"), Sign up, Reset password, My account (name, email, driver's license fields from
   Drivvo, sign out, delete account). Config (Supabase URL + anon key, Google client IDs) via
   `--dart-define`/env file, never committed; the service-role key never ships in the app.
   User must: create the Supabase project, create Google OAuth clients (Android + Web) in Google Cloud
   Console, and enable the Google provider in Supabase.
   **Carried over from the 2026-09-24 self-review (must be done in M7):** reminder notifications
   (flutter_local_notifications) honouring the Settings notification time/toggles/vibrate — the
   settings exist but nothing fires yet; language setting wired to `MaterialApp.locale` with gen-l10n;
   achievement events in the History timeline ("Completed 1 year of tracking this vehicle").
   **From Drivvo user-review research (2026-09-24)** — keep what users love, fix what they hate:
   - Already covered: no ads, no paywall, no forced account (login optional), fast single-screen forms,
     unlimited custom catalogs (service/expense types, fuels, places), free-text origin/destination,
     reminders + upcoming strip, multi-vehicle, "Discard changes?" guard (users lost data on back).
   - To do: never silently round/alter typed numbers (store exactly what was typed; format only on
     display); receipt **photo attachments free** on every record (M6 storage + local-only fallback);
     **free CSV/Excel/PDF export and a one-tap local backup/restore file** (M7) so data can never be
     lost; optional odometer on refuels (consumption only uses refuels that have one); optional
     part number / brand field on service items; fuel-economy trend chart vs your own history (M5);
     later/optional: GPS automatic trip tracking for mileage reports (L effort).
7. **Extras (parallel)**: checklists and form builder, export (CSV/Excel/PDF) + CSV import, My places map, Flex calculator, Achievements, dark theme, i18n.
8. **Ship**: Android APK on the phone, web deploy (Firebase Hosting/Vercel), optional iOS via Codemagic.

## Git, branches & CI/CD
- Remote: `https://github.com/Abdullah8873/Drivvo.git` (recommend private).
- Branches: `main` (stable, release-only, PR from develop), `develop` (integration), `feature/<module>` (one per module/agent,
  worktrees), `hotfix/<name>` (from main). Conventional commit messages.
- `.github/workflows/ci.yml` — on PR + push to develop/main: `dart format --set-exit-if-changed`, `flutter analyze`,
  `flutter test --coverage`, `flutter build web`, `flutter build apk --debug`; upload artifacts.
- `.github/workflows/release.yml` — on push to main / tag `v*`: signed release APK (keystore + passwords in GitHub Secrets)
  → GitHub Release; web build → GitHub Pages; `supabase db push` with `SUPABASE_ACCESS_TOKEN`/project ref secrets.
- iOS later via Codemagic. Branch protection (required CI checks, PR reviews) set by user in GitHub settings.
- Written in Milestone 1, then **parked by user request (2026-09-23)** in `.github/workflows-disabled/` to keep dev fast.
  Re-enable later with `git mv .github/workflows-disabled/*.yml .github/workflows/`. Until then: run
  `dart format`, `flutter analyze`, `flutter test` locally before each merge into develop.

## Verification
- `flutter test`: consumption between full tanks, missed-refuel handling, cost/km, predictions, unit conversions (checked against the user's real
  numbers from Drivvo, e.g. average 39.344 km/L and cost/km PKR10).
- `flutter run` on the emulator/phone and `flutter run -d chrome` after each milestone; compare each screen side by side with Drivvo in BlueStacks.
- Sync: create data offline, reconnect, and confirm it shows on the web build. Sharing: a second account sees the shared vehicle.
- Notifications: set a reminder due in 1 minute and confirm it fires.

## After approval
Save memories: the user is a web developer learning mobile (explain with web analogies); the user allows unlimited parallel agents.
