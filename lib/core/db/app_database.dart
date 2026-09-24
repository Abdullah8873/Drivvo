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

  /// v1: initial schema (catalogs seeded with random ids).
  /// v2: deterministic seed ids + de-duplication of double-seeded catalogs.
  @override
  int get schemaVersion => 2;

  /// `settings_entries` key written once the default catalogs are seeded.
  static const seedMarkerKey = 'catalog_seed_version';

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedCatalogs();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await transaction(() async {
          await _dedupeCatalogs();
          // v1 databases were seeded in onCreate; don't seed them again
          // (a renamed default would otherwise come back).
          await _markSeeded();
        });
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Self-heal a first launch that was interrupted mid-seed.
      final marker = await (select(
        settingsEntries,
      )..where((s) => s.key.equals(seedMarkerKey))).getSingleOrNull();
      if (marker == null) await seedCatalogs();
    },
  );

  /// Inserts the default catalogs. Idempotent: every seed row has a
  /// deterministic id (`SeedData.idFor`) and is inserted with
  /// `insertOrIgnore`, and a default is skipped when an item of the same kind
  /// and name already exists (even a deleted one), so running it again never
  /// adds duplicates or resurrects what the user removed.
  Future<void> seedCatalogs() => transaction(() async {
    final rows = await customSelect(
      'SELECT kind, lower(trim(name)) AS n FROM catalog_items',
      readsFrom: {catalogItems},
    ).get();
    final existing = {
      for (final r in rows) '${r.read<String>('kind')}|${r.read<String>('n')}',
    };
    await batch((b) {
      for (final (kind, names) in SeedData.catalogs) {
        for (final name in names) {
          if (existing.contains('${kind.name}|${name.trim().toLowerCase()}')) {
            continue;
          }
          b.insert(
            catalogItems,
            CatalogItemsCompanion.insert(
              id: Value(SeedData.idFor(kind, name)),
              kind: kind,
              name: name,
              fuelKind: Value(
                kind == CatalogKind.fuel ? SeedData.fuelKindOf(name) : null,
              ),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
    await _markSeeded();
  });

  Future<void> _markSeeded() => into(settingsEntries).insert(
    SettingsEntriesCompanion.insert(key: seedMarkerKey, value: '1'),
    mode: InsertMode.insertOrReplace,
  );

  /// Every column that points at a catalog item, as `(table, column)`.
  static const _catalogRefs = [
    ('refuelings', 'gas_station_id'),
    ('refuelings', 'payment_method_id'),
    ('refuelings', 'reason_id'),
    ('refueling_fuels', 'fuel_id'),
    ('entries', 'place_id'),
    ('entries', 'payment_method_id'),
    ('entries', 'reason_id'),
    ('entry_items', 'type_id'),
    ('routes', 'reason_id'),
    ('reminders', 'type_id'),
  ];

  /// v1 -> v2: collapses catalog items that were seeded twice.
  ///
  /// For every `(kind, lower(trim(name)))` group of live items one row is
  /// kept (a `seed:` id first, then the oldest), every record pointing at the
  /// others is repointed to it, and the others are soft-deleted. Items whose
  /// name is unique are left alone. Run inside a transaction.
  Future<void> _dedupeCatalogs() async {
    final now = Variable.withDateTime(DateTime.now());
    await customStatement('DROP TABLE IF EXISTS temp.catalog_dedupe');
    await customStatement('''
      CREATE TEMP TABLE catalog_dedupe AS
      SELECT c.id AS dup_id, (
        SELECT k.id FROM catalog_items k
        WHERE k.deleted_at IS NULL AND k.kind = c.kind
          AND lower(trim(k.name)) = lower(trim(c.name))
        ORDER BY (k.id LIKE 'seed:%') DESC, julianday(k.created_at) ASC,
          k.rowid ASC
        LIMIT 1
      ) AS keep_id
      FROM catalog_items c
      WHERE c.deleted_at IS NULL
    ''');
    await customStatement('DELETE FROM catalog_dedupe WHERE dup_id = keep_id');
    for (final (table, column) in _catalogRefs) {
      await customUpdate(
        'UPDATE $table SET '
        '$column = (SELECT keep_id FROM catalog_dedupe WHERE dup_id = $column), '
        'updated_at = ?1 '
        'WHERE $column IN (SELECT dup_id FROM catalog_dedupe)',
        variables: [now],
        updateKind: UpdateKind.update,
      );
    }
    await customUpdate(
      'UPDATE catalog_items SET deleted_at = ?1, updated_at = ?1 '
      'WHERE id IN (SELECT dup_id FROM catalog_dedupe)',
      variables: [now],
      updateKind: UpdateKind.update,
    );
    await customStatement('DROP TABLE temp.catalog_dedupe');
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
