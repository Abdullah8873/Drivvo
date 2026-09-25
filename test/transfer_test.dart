import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/transfer_code.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/core/sharing/in_memory_sharing_api.dart';
import 'package:motolog/core/sharing/sharing_api.dart';
import 'package:motolog/core/sync/in_memory_remote_store.dart';
import 'package:motolog/core/sync/remote_file_store.dart';
import 'package:motolog/core/sync/sync_engine.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';

import 'helpers.dart';

/// More → Transfer: the seller's code copies a vehicle's history into the
/// buyer's account (the in-memory `redeem_transfer`), and the buyer's next
/// sync downloads it and re-homes the attachment files.
void main() {
  const seller = 'seller';
  const buyer = 'buyer';
  final petrol = SeedData.idFor(CatalogKind.fuel, 'Petrol');

  late InMemoryRemoteStore cloud;
  late InMemoryRemoteFileStore files;
  late InMemorySharingServer server;
  late DateTime now;
  late AppDatabase sellerDb;
  late AppDatabase buyerDb;
  late SyncEngine sellerSync;
  late SyncEngine buyerSync;
  late String car;
  late String other;
  late String refueling;
  late String station;

  setUp(() async {
    now = DateTime.utc(2026, 9, 26, 12);
    cloud = InMemoryRemoteStore();
    files = InMemoryRemoteFileStore();
    server = InMemorySharingServer(cloud, clock: () => now)
      ..users[seller] = const InMemoryUser(email: 's@example.com')
      ..users[buyer] = const InMemoryUser(email: 'b@example.com');
    sellerDb = testDatabase();
    buyerDb = testDatabase();
    sellerSync = SyncEngine(sellerDb, cloud, files: files);
    buyerSync = SyncEngine(buyerDb, cloud.asUser(buyer), files: files);

    car = await addTestVehicle(sellerDb, name: 'Sold car');
    other = await addTestVehicle(sellerDb, name: 'Kept car');
    station =
        (await sellerDb
                .into(sellerDb.catalogItems)
                .insertReturning(
                  CatalogItemsCompanion.insert(
                    kind: CatalogKind.gasStation,
                    name: 'Corner station',
                  ),
                ))
            .id;
    refueling = await sellerDb.saveRefueling(
      RefuelingDraft(
        vehicleId: car,
        date: DateTime(2026, 9, 1),
        odometer: 1000,
        gasStationId: station,
        lines: [
          FuelLineDraft(fuelId: petrol, pricePerUnit: 3, total: 30, volume: 10),
        ],
      ),
    );
    await sellerDb.applyAttachmentChanges(
      parentTable: 'refuelings',
      parentId: refueling,
      vehicleId: car,
      added: [
        PendingAttachment(
          fileName: 'receipt.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    await sellerDb.saveRefueling(
      RefuelingDraft(
        vehicleId: other,
        date: DateTime(2026, 9, 1),
        odometer: 5000,
        lines: [
          FuelLineDraft(fuelId: petrol, pricePerUnit: 3, total: 30, volume: 10),
        ],
      ),
    );
    await sellerSync.sync(seller);
  });
  tearDown(() async {
    await sellerDb.close();
    await buyerDb.close();
  });

  test('codes look like K7QM-3XPD and are normalized', () {
    expect(TransferCode.format('K7QM3XPD'), 'K7QM-3XPD');
    expect(TransferCode.normalize(' k7qm-3xpd '), 'K7QM3XPD');
    expect(TransferCode.isValid('K7QM3XPD'), isTrue);
    expect(TransferCode.isValid('K7QM3XP0'), isFalse); // 0 is not used
    expect(TransferCode.isValid('K7QM3XP'), isFalse);
    for (var i = 0; i < 50; i++) {
      expect(TransferCode.isValid(TransferCode.generate()), isTrue);
    }
    expect(TransferCode.alphabet, hasLength(31));
    expect(TransferCode.alphabet, isNot(contains(RegExp('[01ILO]'))));
  });

  test(
    'redeeming copies the vehicle, its records, catalogs and files',
    () async {
      final info = await server.api(seller).createTransfer(car);
      expect(info.vehicleName, 'Sold car');
      expect(info.expiresAt, now.add(const Duration(days: 7)));
      expect(info.statusAt(now), TransferStatus.pending);

      final got = await server.api(buyer).redeemTransfer(info.displayCode);
      expect(got.vehicleId, car);

      final report = await buyerSync.sync(buyer);
      expect(report.filesRehomed, 1);
      final vehicles = await buyerDb.select(buyerDb.vehicles).get();
      expect(vehicles.map((v) => v.name), ['Sold car']);
      expect((await buyerDb.getRefueling(refueling))!.volume, 10);
      final stations = await (buyerDb.select(
        buyerDb.catalogItems,
      )..where((c) => c.id.equals(station))).get();
      expect(stations.single.name, 'Corner station');

      // The file was copied into the buyer's own folder.
      final attachment =
          (await buyerDb.select(buyerDb.attachments).get()).single;
      expect(attachment.storagePath, startsWith('$buyer/'));
      expect(files.objects[attachment.storagePath], [1, 2, 3]);

      // The seller keeps everything.
      expect(await sellerDb.select(sellerDb.vehicles).get(), hasLength(2));
      final mine = await server.api(seller).myTransfers();
      expect(mine.single.statusAt(now), TransferStatus.redeemed);
    },
  );

  test('clear errors for bad codes', () async {
    Future<String> error(Future<Object?> call) async {
      try {
        await call;
      } on SharingException catch (e) {
        return e.message;
      }
      fail('no error');
    }

    final sellerApi = server.api(seller);
    final buyerApi = server.api(buyer);
    expect(
      await error(buyerApi.redeemTransfer('ABCD-EFGH')),
      contains('No transfer'),
    );

    final own = await sellerApi.createTransfer(car);
    expect(
      await error(sellerApi.redeemTransfer(own.code)),
      contains('own code'),
    );

    await buyerApi.redeemTransfer(own.code);
    expect(
      await error(buyerApi.redeemTransfer(own.code)),
      contains('already used'),
    );

    final again = await sellerApi.createTransfer(car);
    server.users['third'] = const InMemoryUser(email: 't@example.com');
    await sellerApi.cancelTransfer(again.displayCode);
    expect(
      await error(server.api('third').redeemTransfer(again.code)),
      contains('cancelled'),
    );

    final late = await sellerApi.createTransfer(other);
    now = now.add(const Duration(days: 8));
    expect(
      await error(buyerApi.redeemTransfer(late.code)),
      contains('expired'),
    );

    final dup = await sellerApi.createTransfer(car);
    expect(
      await error(buyerApi.redeemTransfer(dup.code)),
      contains('already have'),
    );

    expect(
      await error(sellerApi.createTransfer('missing')),
      contains('cloud yet'),
    );
  });
}
