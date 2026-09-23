import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed_data.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The local SQLite database (offline-first). On web it runs sqlite3 compiled
/// to WebAssembly (`web/sqlite3.wasm` + `web/drift_worker.js`).
///
/// Feature code adds its queries as `extension XxxQueries on AppDatabase` in
/// its own feature folder, so this file stays small and features don't
/// collide.
@DriftDatabase(
  tables: [
    Vehicles,
    CatalogItems,
    Refuelings,
    RefuelingFuels,
    Entries,
    EntryItems,
    Routes,
    Readings,
    Reminders,
    SettingsEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Tests pass an in-memory executor: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'motolog',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCatalogs();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedCatalogs() async {
    FuelKind kindOf(String fuel) => switch (fuel) {
      'CNG' || 'LPG' => FuelKind.gas,
      'Electric' => FuelKind.electric,
      _ => FuelKind.liquid,
    };

    final seeds = <(CatalogKind, List<String>)>[
      (CatalogKind.fuel, SeedData.fuels),
      (CatalogKind.serviceType, SeedData.serviceTypes),
      (CatalogKind.expenseType, SeedData.expenseTypes),
      (CatalogKind.incomeType, SeedData.incomeTypes),
      (CatalogKind.reason, SeedData.reasons),
      (CatalogKind.paymentMethod, SeedData.paymentMethods),
    ];
    await batch((b) {
      for (final (kind, names) in seeds) {
        b.insertAll(catalogItems, [
          for (final name in names)
            CatalogItemsCompanion.insert(
              kind: kind,
              name: name,
              fuelKind: Value(kind == CatalogKind.fuel ? kindOf(name) : null),
            ),
        ]);
      }
    });
  }

  // ---- Shared queries used across many features ---------------------------

  /// Non-deleted vehicles, active first, then by name.
  Stream<List<Vehicle>> watchVehicles() {
    return (select(vehicles)
          ..where((v) => v.deletedAt.isNull())
          ..orderBy([
            (v) => OrderingTerm.desc(v.active),
            (v) => OrderingTerm.asc(v.name),
          ]))
        .watch();
  }

  Stream<Vehicle?> watchVehicle(String id) {
    return (select(vehicles)
          ..where((v) => v.id.equals(id) & v.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// Non-deleted catalog entries of one kind, alphabetically.
  Stream<List<CatalogItem>> watchCatalog(CatalogKind kind) {
    return (select(catalogItems)
          ..where((c) => c.kind.equalsValue(kind) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name.collate(Collate.noCase))]))
        .watch();
  }

  /// Highest odometer recorded anywhere for a vehicle ("Last odometer: N").
  Stream<double?> watchLastOdometer(String vehicleId) {
    const sql = '''
      SELECT MAX(o) AS odo FROM (
        SELECT MAX(odometer) AS o FROM refuelings WHERE vehicle_id = ?1 AND deleted_at IS NULL
        UNION ALL SELECT MAX(odometer) FROM entries WHERE vehicle_id = ?1 AND deleted_at IS NULL
        UNION ALL SELECT MAX(odometer) FROM readings WHERE vehicle_id = ?1 AND deleted_at IS NULL
        UNION ALL SELECT MAX(COALESCE(end_odometer, start_odometer)) FROM routes
          WHERE vehicle_id = ?1 AND deleted_at IS NULL
      )
    ''';
    return customSelect(
      sql,
      variables: [Variable.withString(vehicleId)],
      readsFrom: {refuelings, entries, readings, routes},
    ).watchSingle().map((row) => row.readNullable<double>('odo'));
  }
}
