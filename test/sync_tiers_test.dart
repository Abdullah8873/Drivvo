import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';
import 'package:motolog/features/checklists/checklist_queries.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';

import 'helpers.dart';
import 'sync_test_utils.dart';

/// The sync runs the tables of one dependency tier in parallel, tier after
/// tier (see `AppDatabase.syncedTableTiers`). These tests check the tiers
/// against the real schema and that parents still always go first.
void main() {
  const u1 = 'user-1';
  late AppDatabase phone;
  late AppDatabase laptop;
  late InMemoryRemoteStore cloud;

  setUp(() {
    phone = testDatabase();
    laptop = testDatabase();
    cloud = InMemoryRemoteStore();
  });
  tearDown(() async {
    await phone.close();
    await laptop.close();
  });

  /// Tier index of every synced table.
  final tierOf = {
    for (final (i, tier) in AppDatabase.syncedTableTiers.indexed)
      for (final t in tier) t: i,
  };

  /// Every synced table's parents: SQL foreign keys, plus the loose
  /// `attachments.parent_table` relation.
  Future<Map<String, Set<String>>> parents(AppDatabase db) async => {
    for (final t in AppDatabase.syncedTableNames)
      t: {
        for (final r
            in await db.customSelect('PRAGMA foreign_key_list($t)').get())
          r.read<String>('table'),
        if (t == 'attachments') ...AppDatabase.attachmentParentTables,
      },
  };

  test('each table only depends on earlier tiers', () async {
    expect(
      AppDatabase.syncedTableNames.toSet(),
      hasLength(AppDatabase.syncedTableNames.length),
    );
    final deps = await parents(phone);
    for (final MapEntry(key: table, value: ps) in deps.entries) {
      for (final p in ps) {
        expect(tierOf[p], isNotNull, reason: '$table -> $p is not synced');
        expect(
          tierOf[p]! < tierOf[table]!,
          isTrue,
          reason: '$table (tier ${tierOf[table]}) needs $p (tier ${tierOf[p]})',
        );
      }
    }
    // Every table with sync columns is synced.
    for (final t in phone.allTables) {
      final synced = t.$columns.any((c) => c.$name == 'deleted_at');
      expect(
        AppDatabase.syncedTableNames.contains(t.actualTableName),
        synced,
        reason: t.actualTableName,
      );
    }
  });

  Future<void> fillEveryTable(AppDatabase db) async {
    final vid = await addTestVehicle(db);
    final rid = await db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 1),
        odometer: 1000,
        lines: [
          FuelLineDraft(
            fuelId: SeedData.idFor(CatalogKind.fuel, 'Petrol'),
            pricePerUnit: 300,
            total: 3000,
            volume: 10,
          ),
        ],
      ),
    );
    await db.saveEntry(
      EntryDraft(
        vehicleId: vid,
        kind: EntryKind.service,
        date: DateTime(2026, 9, 2),
        items: [
          EntryItemDraft(
            typeId: SeedData.idFor(CatalogKind.serviceType, 'Oil Change'),
            amount: 1200,
          ),
        ],
      ),
    );
    await db.saveChecklist(
      ChecklistDraft(
        vehicleId: vid,
        date: DateTime(2026, 9, 3),
        title: 'Walkaround',
        answers: const [ChecklistAnswerDraft(label: 'Tires')],
      ),
    );
    await db.applyAttachmentChanges(
      parentTable: 'refuelings',
      parentId: rid,
      vehicleId: vid,
      added: [
        PendingAttachment(
          fileName: 'r.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1]),
        ),
      ],
    );
  }

  /// Every call of [op] on a child table starts after the last call of the
  /// same [op] on each of its parents ended.
  void expectParentsFirst(
    RecordingRemoteStore remote,
    String op,
    Map<String, Set<String>> deps,
  ) {
    var checked = 0;
    for (final MapEntry(key: child, value: ps) in deps.entries) {
      final start = remote.firstStart(op, child);
      if (start < 0) continue;
      for (final p in ps) {
        final end = remote.lastEnd(op, p);
        if (end < 0) continue;
        expect(start > end, isTrue, reason: '$op $child started before $p');
        checked++;
      }
    }
    expect(checked, greaterThan(5));
  }

  test('parents go first in both directions; tiers run in parallel', () async {
    await fillEveryTable(phone);
    final deps = await parents(phone);

    final up = RecordingRemoteStore(
      cloud,
      latency: const Duration(milliseconds: 5),
    );
    await SyncEngine(phone, up).sync(u1);
    expectParentsFirst(up, 'push', deps);
    // Pull before push.
    expect(
      up.events.lastIndexWhere((e) => e.op == 'pull' && !e.start),
      lessThan(up.events.indexWhere((e) => e.op == 'push' && e.start)),
    );
    expect(up.maxInFlight, greaterThan(1));

    final down = RecordingRemoteStore(
      cloud,
      latency: const Duration(milliseconds: 5),
    );
    await SyncEngine(laptop, down).sync(u1);
    expectParentsFirst(down, 'pull', deps);
    expect(down.maxInFlight, greaterThan(1));
    Future<int> count(AppDatabase db, String t) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle())
            .read<int>('n');
    for (final t in AppDatabase.syncedTableNames) {
      expect(await count(laptop, t), await count(phone, t), reason: t);
    }
  });

  test('a failed push lets its tier finish but stops the next tier', () async {
    await fillEveryTable(phone);
    cloud.beforePush = (table, rows) {
      if (table == 'vehicles') throw Exception('offline');
    };
    await expectLater(SyncEngine(phone, cloud).sync(u1), throwsException);
    // A sibling of the failed table (same tier) still went up…
    expect(cloud.rows('catalog_items', u1), isNotEmpty);
    // …but nothing that depends on the tier did.
    for (final t in [
      ...AppDatabase.syncedTableTiers[1],
      ...AppDatabase.syncedTableTiers[2],
    ]) {
      expect(cloud.rows(t, u1), isEmpty, reason: t);
    }

    cloud.beforePush = null;
    await SyncEngine(phone, cloud).sync(u1);
    expect(cloud.rows('attachments', u1), hasLength(1));
    expect(await SyncEngine(phone, cloud).pendingCount(), 0);
  });

  test('a failed pull page never saves its cursor via another table', () async {
    await fillEveryTable(phone);
    await SyncEngine(phone, cloud).sync(u1);
    final vid = (await phone.select(phone.vehicles).get()).single.id;
    Map<String, Object?> bad({double? totalCost, required String at}) => {
      'id': 'bad',
      'created_at': at,
      'updated_at': at,
      'vehicle_id': vid,
      'date': at,
      'odometer': 5.0,
      'total_cost': ?totalCost,
    };
    // A row the local schema rejects (NOT NULL total_cost): the refuelings
    // page fails inside its transaction, after the cursor was advanced in
    // memory, while `entries` (same tier) keeps saving the shared state.
    await cloud.push('refuelings', u1, [bad(at: '2026-09-01T00:00:00.000Z')]);

    await expectLater(SyncEngine(laptop, cloud).sync(u1), throwsA(anything));
    final saved = await (laptop.select(
      laptop.settingsEntries,
    )..where((s) => s.key.equals(SyncEngine.stateKey))).getSingle();
    expect(saved.value, contains('"entries"'));
    expect(saved.value, isNot(contains('"refuelings"')));
    expect(await laptop.select(laptop.refuelings).get(), isEmpty);

    // Fixed on the server: the next run applies the whole table.
    await cloud.push('refuelings', u1, [
      bad(totalCost: 10, at: '2026-09-02T00:00:00.000Z'),
    ]);
    await SyncEngine(laptop, cloud).sync(u1);
    expect(await laptop.select(laptop.refuelings).get(), hasLength(2));
  });
}
