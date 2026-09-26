import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';

/// Schema v7: `part_number` on `entry_items` (see the `@TableIndex`-less
/// column added in tables.dart).
void main() {
  test('fresh database has part_number on entry_items', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final cols = await db.customSelect('PRAGMA table_info(entry_items)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('part_number'));
  });

  test('v6 -> v7 migration adds the column and keeps data', () async {
    // Today's schema minus the v7 column = a v6 database.
    final fresh = testDatabase();
    final rows = await fresh
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
          "LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 "
          "WHEN 'index' THEN 1 ELSE 2 END",
        )
        .get();
    await fresh.close();
    final schema = [
      for (final r in rows)
        r
            .read<String>('sql')
            .replaceAll(RegExp(r',\s*"part_number" TEXT NULL'), ''),
    ];
    expect(schema.any((s) => s.contains('part_number')), isFalse);

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
              'INSERT INTO entries (id, created_at, updated_at, vehicle_id, '
              "kind, date, total_cost) VALUES ('e1', '$t0', '$t0', 'v1', "
              "'service', '$t0', 1200)",
            );
            raw.execute(
              'INSERT INTO entry_items (id, created_at, updated_at, '
              "entry_id, type_id, amount) VALUES ('ei1', '$t0', '$t0', "
              "'e1', 'seed:serviceType:oil-change', 1200)",
            );
            raw.execute(
              'INSERT INTO settings_entries VALUES '
              "('catalog_seed_version', '1')",
            );
            raw.execute('PRAGMA user_version = 6');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(old.close);

    // Old data intact.
    expect((await old.select(old.vehicles).get()).single.name, 'Honda');
    final item = (await old.select(old.entryItems).get()).single;
    expect(item.amount, 1200);
    expect(item.partNumber, isNull);

    final cols = await old.customSelect('PRAGMA table_info(entry_items)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('part_number'));
    final version = await old.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), old.schemaVersion);

    // The column is writable after the upgrade, and still tracked by sync.
    await (old.update(old.entryItems)..where((i) => i.id.equals('ei1'))).write(
      const EntryItemsCompanion(partNumber: Value('Bosch WS10130')),
    );
    expect(
      (await old.select(old.entryItems).getSingle()).partNumber,
      'Bosch WS10130',
    );
    final queued = await old.select(old.syncOutbox).get();
    expect(queued.map((q) => q.rowId), contains('ei1'));
  });

  test('the migration is idempotent (interrupted upgrade)', () async {
    final db = testDatabase();
    addTearDown(db.close);
    // Re-running the v7 block against an already-migrated database (e.g. a
    // migration interrupted after the ALTER but before the version write)
    // must not throw.
    await db.transaction(() async {
      final columns = await db
          .customSelect('PRAGMA table_info(entry_items)')
          .get();
      if (!columns.any((c) => c.read<String>('name') == 'part_number')) {
        await db.customStatement(
          'ALTER TABLE entry_items ADD COLUMN part_number TEXT NULL',
        );
      }
    });
    final cols = await db.customSelect('PRAGMA table_info(entry_items)').get();
    expect(
      cols.where((c) => c.read<String>('name') == 'part_number'),
      hasLength(1),
    );
  });
}
