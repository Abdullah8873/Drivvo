import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/record_module.dart';
import 'export_models.dart';

/// Raw rows loaded from the database for one export, already filtered by
/// vehicle(s)/period/soft-delete — everything [export_rows.dart]'s pure
/// builders need, with no further database access.
class ExportData {
  const ExportData({
    required this.refuelings,
    required this.refuelingFuels,
    required this.entries,
    required this.entryItems,
    required this.routes,
    required this.readings,
    required this.reminders,
    required this.vehicleNames,
    required this.catalogNames,
  });

  final List<Refueling> refuelings;
  final List<RefuelingFuel> refuelingFuels;
  final List<Entry> entries;
  final List<EntryItem> entryItems;
  final List<Route> routes;
  final List<Reading> readings;
  final List<Reminder> reminders;

  /// vehicleId -> name.
  final Map<String, String> vehicleNames;

  /// catalog item id -> name (fuels, types, stations, places, reasons,
  /// payment methods — one table in the db, see `CatalogItems`).
  final Map<String, String> catalogNames;
}

/// Loads everything [ExportOptions] asks for from the database. Thin: all
/// the actual row-shaping happens in the pure builders in export_rows.dart,
/// which this deliberately doesn't touch, so they stay unit-testable
/// without a database.
Future<ExportData> loadExportData(AppDatabase db, ExportOptions options) async {
  final vehicleIds = options.vehicleIds;
  final period = options.period;
  // Half-open range: the picked "to" day is inclusive, so its upper bound
  // is the start of the next day.
  final from = period?.from;
  final toExclusive = period == null
      ? null
      : DateTime(period.to.year, period.to.month, period.to.day + 1);

  Expression<bool> inRange(DateTimeColumn date) {
    Expression<bool> e = const Constant(true);
    if (from != null) e = e & date.isBiggerOrEqualValue(from);
    if (toExclusive != null) e = e & date.isSmallerThanValue(toExclusive);
    return e;
  }

  final vehicles = await (db.select(
    db.vehicles,
  )..where((v) => v.id.isIn(vehicleIds))).get();
  final catalog = await db.select(db.catalogItems).get();

  final refuelings = options.modules.contains(RecordModule.refueling)
      ? await (db.select(db.refuelings)..where(
              (r) =>
                  r.vehicleId.isIn(vehicleIds) &
                  r.deletedAt.isNull() &
                  inRange(r.date),
            ))
            .get()
      : <Refueling>[];
  final refuelingFuels = refuelings.isEmpty
      ? <RefuelingFuel>[]
      : await (db.select(db.refuelingFuels)..where(
              (f) =>
                  f.refuelingId.isIn(refuelings.map((r) => r.id)) &
                  f.deletedAt.isNull(),
            ))
            .get();

  final entryKinds = [
    if (options.modules.contains(RecordModule.expense)) EntryKind.expense,
    if (options.modules.contains(RecordModule.service)) EntryKind.service,
    if (options.modules.contains(RecordModule.income)) EntryKind.income,
  ];
  final entries = entryKinds.isEmpty
      ? <Entry>[]
      : await (db.select(db.entries)..where(
              (e) =>
                  e.vehicleId.isIn(vehicleIds) &
                  e.kind.isInValues(entryKinds) &
                  e.deletedAt.isNull() &
                  inRange(e.date),
            ))
            .get();
  final entryItems = entries.isEmpty
      ? <EntryItem>[]
      : await (db.select(db.entryItems)..where(
              (i) =>
                  i.entryId.isIn(entries.map((e) => e.id)) &
                  i.deletedAt.isNull(),
            ))
            .get();

  final routes = options.modules.contains(RecordModule.route)
      ? await (db.select(db.routes)..where(
              (r) =>
                  r.vehicleId.isIn(vehicleIds) &
                  r.deletedAt.isNull() &
                  inRange(r.startDate),
            ))
            .get()
      : <Route>[];

  final readings = options.modules.contains(RecordModule.reading)
      ? await (db.select(db.readings)..where(
              (r) =>
                  r.vehicleId.isIn(vehicleIds) &
                  r.deletedAt.isNull() &
                  inRange(r.date),
            ))
            .get()
      : <Reading>[];

  // Reminders describe an upcoming/repeating trigger, not a dated past
  // event, so the period filter doesn't apply to them — exporting always
  // includes every live reminder for the chosen vehicle(s).
  final reminders = options.modules.contains(RecordModule.reminder)
      ? await (db.select(db.reminders)..where(
              (r) => r.vehicleId.isIn(vehicleIds) & r.deletedAt.isNull(),
            ))
            .get()
      : <Reminder>[];

  return ExportData(
    refuelings: refuelings,
    refuelingFuels: refuelingFuels,
    entries: entries,
    entryItems: entryItems,
    routes: routes,
    readings: readings,
    reminders: reminders,
    vehicleNames: {for (final v in vehicles) v.id: v.name},
    catalogNames: {for (final c in catalog) c.id: c.name},
  );
}
