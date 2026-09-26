import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';
import 'package:motolog/features/vehicles/vehicle_queries.dart';

import 'helpers.dart';

/// Pins the rules the cloud sync relies on: every write bumps `updatedAt`
/// and lands in the outbox, and deletes are always soft (child rows too).
void main() {
  final petrol = SeedData.idFor(CatalogKind.fuel, 'Petrol');
  final oil = SeedData.idFor(CatalogKind.serviceType, 'Oil Change');

  late AppDatabase db;
  late String vid;
  setUp(() async {
    db = testDatabase();
    vid = await addTestVehicle(db);
  });
  tearDown(() => db.close());

  Future<Set<String>> queued(String table) async {
    final rows = await db
        .customSelect(
          'SELECT row_id FROM sync_outbox WHERE target_table = ?',
          variables: [Variable.withString(table)],
        )
        .get();
    return {for (final r in rows) r.read<String>('row_id')};
  }

  Future<void> clearOutbox() => db.customStatement('DELETE FROM sync_outbox');

  RefuelingDraft refuel(double volume) => RefuelingDraft(
    vehicleId: vid,
    date: DateTime(2026, 9, 1),
    odometer: 100,
    lines: [
      FuelLineDraft(
        fuelId: petrol,
        pricePerUnit: 300,
        total: 300 * volume,
        volume: volume,
      ),
    ],
  );

  test('editing a refueling soft-deletes its old fuel line', () async {
    final rid = await db.saveRefueling(refuel(10));
    final before = await db.select(db.refuelingFuels).get();
    await clearOutbox();

    await db.saveRefueling(refuel(12), id: rid);
    final after = await db.select(db.refuelingFuels).get();
    expect(after, hasLength(2));
    final old = after.firstWhere((l) => l.id == before.single.id);
    expect(old.deletedAt, isNotNull);
    expect(old.updatedAt.isAfter(before.single.updatedAt), isTrue);
    // Both lines and the parent are queued for upload.
    expect(await queued('refueling_fuels'), {for (final l in after) l.id});
    expect(await queued('refuelings'), {rid});
    // Reads ignore the dead line.
    expect((await db.getRefueling(rid))!.lines.single.line.volume, 12);
  });

  test('deleting a refueling from history keeps old lines untouched', () async {
    final rid = await db.saveRefueling(refuel(10));
    await db.saveRefueling(refuel(12), id: rid);
    final deadBefore = (await db.select(db.refuelingFuels).get()).firstWhere(
      (l) => l.deletedAt != null,
    );
    await db.softDeleteRecord(RecordModule.refueling, rid);
    final all = await db.select(db.refuelingFuels).get();
    expect(all, hasLength(2));
    expect(all.every((l) => l.deletedAt != null), isTrue);
    final dead = all.firstWhere((l) => l.id == deadBefore.id);
    expect(dead.deletedAt, deadBefore.deletedAt);
    expect(dead.updatedAt, deadBefore.updatedAt);
  });

  test('editing an entry soft-deletes its old items', () async {
    final draft = EntryDraft(
      vehicleId: vid,
      kind: EntryKind.service,
      date: DateTime(2026, 9, 1),
      items: [EntryItemDraft(typeId: oil, amount: 1000)],
    );
    final id = await db.saveEntry(draft);
    final first = await db.select(db.entryItems).get();
    await db.saveEntry(
      EntryDraft(
        vehicleId: vid,
        kind: EntryKind.service,
        date: DateTime(2026, 9, 1),
        items: [EntryItemDraft(typeId: oil, amount: 1500)],
      ),
      id: id,
    );
    final all = await db.select(db.entryItems).get();
    expect(all, hasLength(2));
    expect(all.firstWhere((i) => i.id == first.single.id).deletedAt, isNotNull);
    expect((await db.getEntry(id))!.items.single.amount, 1500);
  });

  test('deleting a vehicle soft-deletes it and its records', () async {
    final rid = await db.saveRefueling(refuel(10));
    await db.softDeleteVehicleAndRecords(vid);
    final v = await (db.select(
      db.vehicles,
    )..where((v) => v.id.equals(vid))).getSingle();
    expect(v.deletedAt, isNotNull);
    final r = await (db.select(
      db.refuelings,
    )..where((r) => r.id.equals(rid))).getSingle();
    expect(r.deletedAt, isNotNull);
    expect(await db.getVehicle(vid), isNull);
    expect(await db.getRefueling(rid), isNull);
  });

  test('updates bump updatedAt and are queued', () async {
    final before = (await db.getVehicle(vid))!.updatedAt;
    await clearOutbox();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await db.updateVehicle(vid, const VehiclesCompanion(name: Value('New')));
    expect((await db.getVehicle(vid))!.updatedAt.isAfter(before), isTrue);
    expect(await queued('vehicles'), {vid});
  });

  test('every synced table has outbox triggers', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sync_outbox_%'",
        )
        .get();
    final names = {for (final r in rows) r.read<String>('name')};
    for (final t in AppDatabase.syncedTableNames) {
      expect(
        names,
        containsAll(['sync_outbox_${t}_insert', 'sync_outbox_${t}_update']),
      );
    }
  });

  test('seed rows get the fixed seed timestamp', () async {
    final item = await (db.select(
      db.catalogItems,
    )..where((c) => c.id.equals(petrol))).getSingle();
    expect(item.updatedAt.isAtSameMomentAs(AppDatabase.seedTimestamp), isTrue);
  });

  test(
    'v2 -> v3 migration adds the outbox and resets untouched seeds',
    () async {
      // Current schema minus everything v3 added = a v2 database.
      final rows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT "
            "LIKE 'sqlite_%' AND name NOT LIKE '%sync_outbox%' AND type != "
            "'trigger' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END",
          )
          .get();
      const t0 = '2026-01-01T10:00:00.000Z';
      const t1 = '2026-01-01T10:00:00.400Z';
      const t2 = '2026-01-03T10:00:00.000Z';
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final old = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(
            setup: (raw) {
              for (final r in rows) {
                raw.execute(r.read<String>('sql'));
              }
              raw.execute(
                'INSERT INTO catalog_items (id, created_at, updated_at, kind, '
                "name) VALUES ('$petrol', '$t0', '$t1', 'fuel', 'Petrol'), "
                "('$oil', '$t0', '$t2', 'serviceType', 'Oil (renamed)')",
              );
              raw.execute(
                "INSERT INTO settings_entries VALUES ('catalog_seed_version', '1')",
              );
              raw.execute('PRAGMA user_version = 2');
            },
          ),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(old.close);

      Future<CatalogItem> item(String id) => (old.select(
        old.catalogItems,
      )..where((c) => c.id.equals(id))).getSingle();
      expect(
        (await item(petrol)).updatedAt
            .isAtSameMomentAs(AppDatabase.seedTimestamp),
        isTrue,
      );
      // Edited seed rows keep their real timestamp.
      expect(
        (await item(oil)).updatedAt.isAtSameMomentAs(DateTime.parse(t2)),
        isTrue,
      );
      // Triggers work after the upgrade.
      await old.customStatement('DELETE FROM sync_outbox');
      final v = await addTestVehicle(old);
      final queuedRows = await old
          .customSelect('SELECT row_id FROM sync_outbox')
          .get();
      expect(queuedRows.map((r) => r.read<String>('row_id')), [v]);
    },
  );
}
