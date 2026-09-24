import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/remote_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/readings/reading_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';
import 'package:motolog/features/vehicles/vehicle_queries.dart';

import 'helpers.dart';

/// Two devices ("phone" and "laptop") syncing through one fake cloud.
void main() {
  const u1 = 'user-1';
  const u2 = 'user-2';
  final petrol = SeedData.idFor(CatalogKind.fuel, 'Petrol');

  late AppDatabase phone;
  late AppDatabase laptop;
  late InMemoryRemoteStore cloud;
  late SyncEngine phoneSync;
  late SyncEngine laptopSync;

  SyncEngine engine(AppDatabase db, {int page = 1000, int batch = 500}) =>
      SyncEngine(db, cloud, pullPageSize: page, pushBatchSize: batch);

  setUp(() {
    phone = testDatabase();
    laptop = testDatabase();
    cloud = InMemoryRemoteStore();
    phoneSync = engine(phone);
    laptopSync = engine(laptop);
  });
  tearDown(() async {
    await phone.close();
    await laptop.close();
  });

  Future<Vehicle?> vehicle(AppDatabase db, String id) =>
      (db.select(db.vehicles)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<List<RefuelingFuel>> lines(AppDatabase db, String refuelingId) =>
      (db.select(db.refuelingFuels)
            ..where((l) => l.refuelingId.equals(refuelingId))
            ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
          .get();

  RefuelingDraft draft(String vid, double volume) => RefuelingDraft(
    vehicleId: vid,
    date: DateTime(2026, 9, 1, 10),
    odometer: 1000,
    lines: [
      FuelLineDraft(
        fuelId: petrol,
        pricePerUnit: 300,
        total: 300 * volume,
        volume: volume,
      ),
    ],
  );

  /// Sets a row's `updatedAt` exactly (to stage conflicts deterministically).
  Future<void> stamp(AppDatabase db, String id, DateTime at, String name) =>
      (db.update(db.vehicles)..where((v) => v.id.equals(id))).write(
        VehiclesCompanion(name: Value(name), updatedAt: Value(at)),
      );

  group('propagation', () {
    test('create, edit and soft-delete travel both ways', () async {
      final vid = await addTestVehicle(phone, name: 'Honda');
      final rid = await phone.saveRefueling(draft(vid, 10));
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);

      expect((await vehicle(laptop, vid))!.name, 'Honda');
      expect((await laptop.getRefueling(rid))!.volume, 10);

      // Edit on the laptop, sync back to the phone.
      await laptop.updateVehicle(
        vid,
        const VehiclesCompanion(name: Value('CD 70')),
      );
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);
      expect((await vehicle(phone, vid))!.name, 'CD 70');

      // Soft-delete on the phone reaches the laptop as a soft delete.
      await phone.deleteRefueling(rid);
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
      expect(await laptop.getRefueling(rid), isNull);
      final raw = await (laptop.select(
        laptop.refuelings,
      )..where((r) => r.id.equals(rid))).getSingle();
      expect(raw.deletedAt, isNotNull);
      expect((await lines(laptop, rid)).single.deletedAt, isNotNull);
    });

    test('edited child rows: old line soft-deleted, new line added', () async {
      final vid = await addTestVehicle(phone);
      final rid = await phone.saveRefueling(draft(vid, 10));
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);

      await laptop.saveRefueling(draft(vid, 12), id: rid);
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);

      final all = await lines(phone, rid);
      expect(all, hasLength(2));
      expect(all.where((l) => l.deletedAt == null).single.volume, 12);
      expect(all.where((l) => l.deletedAt != null).single.volume, 10);
      expect((await phone.getRefueling(rid))!.volume, 12);
    });

    test('pulled rows keep the server updatedAt (not re-stamped)', () async {
      final vid = await addTestVehicle(phone);
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
      final a = await vehicle(phone, vid);
      final b = await vehicle(laptop, vid);
      expect(b!.updatedAt.isAtSameMomentAs(a!.updatedAt), isTrue);
      expect(b.createdAt.isAtSameMomentAs(a.createdAt), isTrue);
      expect(await laptopSync.pendingCount(), 0);
    });
  });

  group('conflicts (last write wins)', () {
    late String vid;
    setUp(() async {
      vid = await addTestVehicle(phone, name: 'Original');
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
    });

    test('newer edit wins when the older one syncs first', () async {
      final t = DateTime.now().add(const Duration(minutes: 1));
      await stamp(laptop, vid, t, 'Laptop (older)');
      await stamp(phone, vid, t.add(const Duration(seconds: 1)), 'Phone');
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
      expect((await vehicle(phone, vid))!.name, 'Phone');
      expect((await vehicle(laptop, vid))!.name, 'Phone');
      expect(cloud.row('vehicles', u1, vid)!['name'], 'Phone');
    });

    test('older edit loses when the newer one syncs first', () async {
      final t = DateTime.now().add(const Duration(minutes: 1));
      await stamp(phone, vid, t.add(const Duration(seconds: 1)), 'Phone');
      await stamp(laptop, vid, t, 'Laptop (older)');
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);
      expect((await vehicle(laptop, vid))!.name, 'Phone');
      expect((await vehicle(phone, vid))!.name, 'Phone');
      expect(await laptopSync.pendingCount(), 0);
    });

    test(
      'an edit with the same timestamp as the last push is not lost',
      () async {
        final pushed = (await vehicle(phone, vid))!.updatedAt;
        // Same instant as what the server already has, different data.
        await stamp(phone, vid, pushed, 'Same-second edit');
        await phoneSync.sync(u1);
        await laptopSync.sync(u1);
        expect((await vehicle(laptop, vid))!.name, 'Same-second edit');
      },
    );

    test('equal timestamps with different data converge', () async {
      final t = DateTime.now().add(const Duration(minutes: 1));
      await stamp(phone, vid, t, 'Phone');
      await stamp(laptop, vid, t, 'Laptop');
      await phoneSync.sync(u1);
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);
      final a = (await vehicle(phone, vid))!.name;
      final b = (await vehicle(laptop, vid))!.name;
      expect(a, b);
      expect(cloud.row('vehicles', u1, vid)!['name'], a);
    });
  });

  test('re-sync is a no-op (no server churn, nothing applied)', () async {
    final vid = await addTestVehicle(phone);
    await phone.saveRefueling(draft(vid, 10));
    await phoneSync.sync(u1);
    await laptopSync.sync(u1);
    await phoneSync.sync(u1);

    final writes = cloud.writes;
    final before = cloud.rows('vehicles', u1).single['server_updated_at'];
    for (final e in [phoneSync, laptopSync, phoneSync]) {
      final report = await e.sync(u1);
      expect(report.applied, 0, reason: '$report');
      expect(report.pushed, 0, reason: '$report');
    }
    expect(cloud.writes, writes);
    expect(cloud.rows('vehicles', u1).single['server_updated_at'], before);
  });

  test(
    'first sign-in attaches pre-login data and merges the account',
    () async {
      // The account already has the phone's data.
      final phoneVid = await addTestVehicle(phone, name: 'Phone bike');
      await phoneSync.sync(u1);

      // The laptop was used offline before signing in.
      final laptopVid = await addTestVehicle(laptop, name: 'Laptop car');
      expect(await laptopSync.checkAccount(u1), AccountMatch.firstSignIn);
      await laptopSync.sync(u1);
      await phoneSync.sync(u1);

      for (final db in [phone, laptop]) {
        expect(await vehicle(db, phoneVid), isNotNull);
        expect(await vehicle(db, laptopVid), isNotNull);
        // Seed catalogs merged by their shared ids: no duplicates.
        final fuels = await db.watchCatalog(CatalogKind.fuel).first;
        expect(fuels.map((f) => f.name).toSet(), hasLength(fuels.length));
      }
      expect(await laptopSync.lastSyncedUserId(), u1);
      expect(await laptopSync.checkAccount(u1), AccountMatch.sameUser);
    },
  );

  test(
    'a renamed default survives a later install (seed timestamps)',
    () async {
      await phoneSync.sync(u1);
      await (phone.update(
        phone.catalogItems,
      )..where((c) => c.id.equals(petrol))).write(
        CatalogItemsCompanion(
          name: const Value('Gasoline'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await phoneSync.sync(u1);
      // The laptop's own seed row is "newer" by install time, but seed rows
      // carry a fixed old timestamp, so the rename wins.
      await laptopSync.sync(u1);
      final item = await (laptop.select(
        laptop.catalogItems,
      )..where((c) => c.id.equals(petrol))).getSingle();
      expect(item.name, 'Gasoline');
    },
  );

  test('two users are isolated', () async {
    final vid = await addTestVehicle(phone, name: 'Mine');
    await phoneSync.sync(u1);
    await laptopSync.sync(u2);
    expect(await vehicle(laptop, vid), isNull);
    expect(cloud.rows('vehicles', u2), isEmpty);
    expect(cloud.rows('vehicles', u1), hasLength(1));
  });

  test('pages over more than 1000 rows', () async {
    final vid = await addTestVehicle(phone);
    await phone.batch((b) {
      b.insertAll(phone.readings, [
        for (var i = 0; i < 1100; i++)
          ReadingsCompanion.insert(
            vehicleId: vid,
            date: DateTime(2026, 1, 1).add(Duration(hours: i)),
            odometer: i.toDouble(),
          ),
      ]);
    });
    final phoneSmall = engine(phone, batch: 300);
    final laptopSmall = engine(laptop, page: 150);
    await phoneSmall.sync(u1);
    expect(cloud.rows('readings', u1), hasLength(1100));

    cloud.pulls = 0;
    await laptopSmall.sync(u1);
    final got = await laptop.watchReadings(vid).first;
    expect(got, hasLength(1100));
    // 1100 / 150 = 8 pages of readings, plus the other tables.
    expect(cloud.pulls, greaterThanOrEqualTo(8));
  });

  group('partial failure', () {
    test('a failed push batch keeps its rows queued', () async {
      final vid = await addTestVehicle(phone);
      await phone.saveRefueling(draft(vid, 10));
      var fail = true;
      cloud.beforePush = (table, rows) {
        if (table == 'refuelings' && fail) throw Exception('offline');
      };
      await expectLater(phoneSync.sync(u1), throwsException);
      expect(cloud.rows('refuelings', u1), isEmpty);
      // Children are never uploaded before their parent.
      expect(cloud.rows('refueling_fuels', u1), isEmpty);
      expect(await phoneSync.pendingCount(), greaterThan(0));

      fail = false;
      await phoneSync.sync(u1);
      expect(cloud.rows('refuelings', u1), hasLength(1));
      expect(cloud.rows('refueling_fuels', u1), hasLength(1));
      expect(await phoneSync.pendingCount(), 0);
    });

    test('a failed pull page does not advance the cursor', () async {
      final vid = await addTestVehicle(phone);
      await phone.batch((b) {
        b.insertAll(phone.readings, [
          for (var i = 0; i < 30; i++)
            ReadingsCompanion.insert(
              vehicleId: vid,
              date: DateTime(2026, 1, 1).add(Duration(days: i)),
              odometer: i.toDouble(),
            ),
        ]);
      });
      await phoneSync.sync(u1);

      // No overlap window, so the second run shows exactly where the
      // cursor was left.
      final small = SyncEngine(
        laptop,
        cloud,
        pullPageSize: 10,
        pullOverlap: Duration.zero,
      );
      var readingPulls = 0;
      cloud.beforePull = (table, after) {
        if (table == 'readings' && ++readingPulls == 3) {
          throw Exception('timeout');
        }
      };
      await expectLater(small.sync(u1), throwsException);
      expect(await laptop.watchReadings(vid).first, hasLength(20));

      cloud.beforePull = null;
      final report = await small.sync(u1);
      expect(await laptop.watchReadings(vid).first, hasLength(30));
      // Resumed after the two pages that were applied: only the last 10
      // readings came down again, plus the tables after `readings` that the
      // failed run never reached (the seeded checklist template).
      final seededChecklistRows = SeedData.checklistForms.fold<int>(
        0,
        (n, f) => n + 1 + f.$2.length,
      );
      expect(report.pulled, 10 + seededChecklistRows);
    });
  });

  group('different user on the same device', () {
    late String phoneVid;
    setUp(() async {
      phoneVid = await addTestVehicle(phone, name: 'U1 bike');
      await phoneSync.sync(u1);
      // u2's account already holds the laptop's data.
      await addTestVehicle(laptop, name: 'U2 car');
      await laptopSync.sync(u2);
    });

    test('sync refuses until the user decides', () async {
      expect(await phoneSync.checkAccount(u2), AccountMatch.differentUser);
      expect(await phoneSync.lastSyncedUserId(), u1);
      await expectLater(
        phoneSync.sync(u2),
        throwsA(isA<SyncAccountMismatch>()),
      );
    });

    test('keep: this device\'s data is added to the new account', () async {
      await phoneSync.adoptAccount(u2, keepLocalData: true);
      await phoneSync.sync(u2);
      final names = (await phone.watchVehicles().first).map((v) => v.name);
      expect(names, containsAll(['U1 bike', 'U2 car']));
      expect(cloud.row('vehicles', u2, phoneVid), isNotNull);
      expect(await phoneSync.lastSyncedUserId(), u2);
    });

    test('replace: local data is swapped for the account\'s', () async {
      await phoneSync.adoptAccount(u2, keepLocalData: false);
      await phoneSync.sync(u2);
      final names = (await phone.watchVehicles().first).map((v) => v.name);
      expect(names, ['U2 car']);
      expect(cloud.row('vehicles', u2, phoneVid), isNull);
      // u1's copy in the cloud is untouched.
      expect(cloud.row('vehicles', u1, phoneVid), isNotNull);
      // Default pick lists are still there.
      expect(await phone.watchCatalog(CatalogKind.fuel).first, isNotEmpty);
    });
  });

  test('outbox: local writes are queued, pulled rows are not', () async {
    expect(await laptopSync.pendingCount(), greaterThan(0)); // seeds
    await laptopSync.sync(u1);
    expect(await laptopSync.pendingCount(), 0);

    final vid = await addTestVehicle(phone);
    await phoneSync.sync(u1);
    await laptopSync.sync(u1);
    expect(await vehicle(laptop, vid), isNotNull);
    expect(await laptopSync.pendingCount(), 0);

    await laptop.deleteReading('missing'); // matches nothing: not queued
    expect(await laptopSync.pendingCount(), 0);
    await laptop.softDeleteVehicle(vid);
    expect(await laptopSync.pendingCount(), 1);
  });

  test('cursor JSON round-trips', () {
    const c = RemoteCursor('2026-09-24T05:00:00.123456Z', 'seed:fuel:petrol');
    final back = RemoteCursor.fromJson(c.toJson())!;
    expect(back.compareTo(c), 0);
    expect(RemoteCursor.fromJson('garbage'), isNull);
  });
}
