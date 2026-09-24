# MotoLog feature & UI spec

Gathered from a live walkthrough of Drivvo (2026-09-23). This is the source of truth for how screens look and behave.

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
- **Service**: same as Expense, with **multiple service types**, each with its own price and ×, and a total cost row —
  but with **no Reason field** (Drivvo's Service form omits it; Expense keeps it).
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


### Details verified hands-on in Drivvo (2026-09-24)
- **Service / Expense type picker:** multi-select list; ticking a type reveals an inline
  underlined **"Value"** field on the right of that same row — the price is typed right
  there, then ✓. The form then shows rows "Belts ....... PKR750 ✕" and "Total cost PKR750";
  types without a value show PKR0. (Fuel picker has no value field — just ticks.)
- **Expense / Service / Income forms show every field flat** — no "+ More options" expander.
- **Refueling:** "+ Fuel" appears only after "+ More options" (below the full-tank toggle).
  Adding one shows a **"SECOND FUEL"** section header (orange caps) with ✕, then its own
  Fuel field and Price / Total cost / Liters row, then "+ Fuel" again.
- **Back on a half-filled form discards silently in Drivvo.** MotoLog improves on this with a
  "Discard changes?" confirmation (users complain about lost entries in reviews).
- History contains ad cards between records (Drivvo free tier) — MotoLog has no ads.
