import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/readings/reading_queries.dart';

import 'helpers.dart';

/// Schema v5: indexes only (see the `@TableIndex`es in tables.dart).
void main() {
  const expected = {
    'idx_refuelings_vehicle_date',
    'idx_refueling_fuels_refueling',
    'idx_entries_vehicle_date',
    'idx_entries_parent',
    'idx_entry_items_entry',
    'idx_routes_vehicle_start',
    'idx_readings_vehicle_date',
    'idx_reminders_vehicle',
    'idx_sync_outbox_table_seq',
    'idx_checklist_form_items_form',
    'idx_checklists_vehicle_date',
    'idx_checklist_answers_checklist',
    'idx_attachments_parent',
  };

  Future<Set<String>> indexes(AppDatabase db) async => {
    for (final r
        in await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name LIKE 'idx_%'",
            )
            .get())
      r.read<String>('name'),
  };

  group('fresh database', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    test('has every index', () async {
      expect(await indexes(db), expected);
    });

    test('History-style queries use the (vehicle_id, date) index', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM refuelings '
            "WHERE vehicle_id = 'v' AND deleted_at IS NULL ORDER BY date",
          )
          .get();
      expect(
        plan.map((r) => r.read<String>('detail')).join('\n'),
        contains('idx_refuelings_vehicle_date'),
      );
    });

    test('createIndexes is idempotent', () async {
      await db.createIndexes();
      await db.createIndexes();
      expect(await indexes(db), expected);
    });
  });

  test('v4 -> v5 migration keeps data and adds the indexes', () async {
    // Current schema minus the v5 indexes = a v4 database.
    final fresh = testDatabase();
    final rows = await fresh
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
          "LIKE 'sqlite_%' AND NOT (type = 'index' AND name LIKE 'idx_%') "
          "ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 "
          'ELSE 2 END',
        )
        .get();
    final schema = [for (final r in rows) r.read<String>('sql')];
    await fresh.close();
    expect(schema.any((s) => s.contains('idx_')), isFalse);

    const t0 = '2026-01-01T10:00:00.000Z';
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final old = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (raw) {
            for (final sql in schema) {
              raw.execute(sql);
            }
            raw.execute(
              'INSERT INTO vehicles (id, created_at, updated_at, name, type) '
              "VALUES ('v1', '$t0', '$t0', 'Honda', 'motorcycle')",
            );
            raw.execute(
              'INSERT INTO readings (id, created_at, updated_at, vehicle_id, '
              "date, odometer) VALUES ('r1', '$t0', '$t0', 'v1', '$t0', 500)",
            );
            raw.execute(
              "INSERT INTO settings_entries VALUES ('catalog_seed_version', '1')",
            );
            raw.execute('DELETE FROM sync_outbox');
            raw.execute(
              'INSERT INTO sync_outbox (target_table, row_id) '
              "VALUES ('readings', 'r1')",
            );
            raw.execute('PRAGMA user_version = 4');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(old.close);

    // Old data intact, including the pending upload.
    expect((await old.getReading('r1'))!.odometer, 500);
    expect((await old.select(old.vehicles).get()).single.name, 'Honda');
    final queued = await old.select(old.syncOutbox).get();
    expect(queued.single.rowId, 'r1');

    expect(await indexes(old), expected);
    final version = await old.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), old.schemaVersion);

    // Triggers still fire on the upgraded database.
    await old.saveReading(
      ReadingsCompanion.insert(
        vehicleId: 'v1',
        date: DateTime(2026, 2, 1),
        odometer: 600,
      ),
    );
    expect(await old.select(old.syncOutbox).get(), hasLength(2));
  });
}
