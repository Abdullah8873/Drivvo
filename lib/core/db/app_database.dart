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
    SyncOutbox,
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
  /// v3: cloud sync — `sync_outbox` table + change-tracking triggers, and
  ///     untouched seed rows get the fixed [seedTimestamp].
  @override
  int get schemaVersion => 3;

  /// `settings_entries` key written once the default catalogs are seeded.
  static const seedMarkerKey = 'catalog_seed_version';

  /// `createdAt`/`updatedAt` of every seeded catalog row. Seed ids are shared
  /// by every install, so with "install time" timestamps a phone installed
  /// later would overwrite (last-write-wins) a default the user renamed on
  /// another device. A fixed old timestamp makes any real edit win.
  static final seedTimestamp = DateTime.utc(2000);

  /// SQL names of the tables the cloud sync mirrors, parents before
  /// children (the order rows are uploaded and downloaded in).
  static const syncedTableNames = [
    'vehicles',
    'catalog_items',
    'refuelings',
    'entries',
    'routes',
    'readings',
    'reminders',
    'refueling_fuels',
    'entry_items',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await createSyncTriggers();
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
      if (from < 3) {
        await transaction(() async {
          await _resetSeedTimestamps();
          await m.createTable(syncOutbox);
          await createSyncTriggers();
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
    final stamp = Value(seedTimestamp.toLocal());
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
              createdAt: stamp,
              updatedAt: stamp,
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

  /// Installs the triggers that queue every insert/update of a synced table
  /// in `sync_outbox` (see [SyncOutbox]). Deletes aren't tracked: synced
  /// rows are only ever soft-deleted (an update), and the only hard delete —
  /// wiping local data when switching accounts — must not be uploaded.
  ///
  /// Delete-then-insert (rather than `INSERT OR REPLACE`) keeps working
  /// when the outer statement is an `INSERT OR IGNORE`, whose conflict mode
  /// SQLite would otherwise impose on the trigger's own statements.
  Future<void> createSyncTriggers() async {
    for (final table in syncedTableNames) {
      for (final event in const ['INSERT', 'UPDATE']) {
        await customStatement('''
          CREATE TRIGGER IF NOT EXISTS sync_outbox_${table}_${event.toLowerCase()}
          AFTER $event ON $table
          BEGIN
            DELETE FROM sync_outbox
              WHERE target_table = '$table' AND row_id = NEW.id;
            INSERT INTO sync_outbox (target_table, row_id)
              VALUES ('$table', NEW.id);
          END
        ''');
      }
    }
  }

  /// v2 -> v3: seed rows the user never edited (updated within a second of
  /// being created) get the fixed [seedTimestamp], so they can't win a
  /// last-write-wins merge against a real edit made on another device.
  Future<void> _resetSeedTimestamps() => customUpdate(
    'UPDATE catalog_items SET created_at = ?1, updated_at = ?1 '
    "WHERE id LIKE 'seed:%' AND deleted_at IS NULL "
    'AND abs(julianday(updated_at) - julianday(created_at)) * 86400 < 1',
    variables: [Variable.withDateTime(seedTimestamp.toLocal())],
    updates: {catalogItems},
    updateKind: UpdateKind.update,
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
