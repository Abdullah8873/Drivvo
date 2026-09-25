import 'dart:math';

import 'package:drift/drift.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/db/seed_data.dart';
import 'package:motolog/features/attachments/attachment_queries.dart';
import 'package:motolog/features/checklists/checklist_queries.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/features/entries/installments.dart';
import 'package:motolog/features/readings/reading_queries.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';
import 'package:motolog/features/reminders/reminder_queries.dart';
import 'package:motolog/features/routes/route_queries.dart';
import 'package:motolog/features/vehicles/vehicle_queries.dart';

/// How big the benchmark dataset is, per vehicle (defaults ≈ 5,000 records
/// per vehicle — a heavy user after ~12 years of daily logging).
class BigDatasetSpec {
  const BigDatasetSpec({
    this.vehicles = 3,
    this.refuelings = 1500,
    this.expenses = 900,
    this.services = 700,
    this.incomes = 300,
    this.routes = 600,
    this.readings = 900,
    this.checklists = 100,
    this.reminders = 100,
    this.attachments = 100,
    this.attachmentBytes = 2048,
  });

  final int vehicles;
  final int refuelings;
  final int expenses;
  final int services;
  final int incomes;
  final int routes;
  final int readings;
  final int checklists;
  final int reminders;
  final int attachments;
  final int attachmentBytes;

  /// Timeline records per vehicle (installments add a few more rows).
  int get recordsPerVehicle =>
      refuelings +
      expenses +
      services +
      incomes +
      routes +
      readings +
      checklists;
}

/// What [seedBigDataset] created.
class BigDataset {
  BigDataset(this.vehicleIds);

  /// Vehicle ids; the last one has two tanks (petrol + CNG).
  final List<String> vehicleIds;
}

enum _Kind { refuel, expense, service, income, route, reading, checklist }

/// Fills [db] with [spec] through the app's real DAOs (`saveRefueling`,
/// `saveEntry`, `saveRoute`, …), so the sync-outbox and attachment
/// triggers fire exactly as they do in the app. Deterministic for a given
/// [seed]. Each vehicle is written in one outer transaction (the DAOs'
/// own transactions become savepoints) so a file database isn't dominated
/// by one fsync per record.
Future<BigDataset> seedBigDataset(
  AppDatabase db, {
  BigDatasetSpec spec = const BigDatasetSpec(),
  int seed = 42,
}) async {
  final rnd = Random(seed);
  final petrol = SeedData.idFor(CatalogKind.fuel, 'Petrol');
  final cng = SeedData.idFor(CatalogKind.fuel, 'CNG');
  final preTrip = SeedData.formIdFor('Pre-trip inspection');

  Future<List<String>> ids(CatalogKind kind) async => [
    for (final c in await db.getCatalog(kind)) c.id,
  ];

  // User-added pick lists: gas stations and places.
  final stations = <String>[];
  final places = <String>[];
  await db.transaction(() async {
    Future<String> add(CatalogKind kind, String name) async =>
        (await db
                .into(db.catalogItems)
                .insertReturning(
                  CatalogItemsCompanion.insert(kind: kind, name: name),
                ))
            .id;
    for (var i = 0; i < 12; i++) {
      stations.add(await add(CatalogKind.gasStation, 'Station $i'));
    }
    for (var i = 0; i < 8; i++) {
      places.add(await add(CatalogKind.place, 'Place $i'));
    }
  });
  final serviceTypes = await ids(CatalogKind.serviceType);
  final expenseTypes = await ids(CatalogKind.expenseType);
  final incomeTypes = await ids(CatalogKind.incomeType);
  final payments = await ids(CatalogKind.paymentMethod);
  final reasons = await ids(CatalogKind.reason);
  final formItems = (await db.getChecklistForm(preTrip))!.items;

  T pick<T>(List<T> list) => list[rnd.nextInt(list.length)];

  final vehicleIds = <String>[];
  for (var v = 0; v < spec.vehicles; v++) {
    final twoTanks = v == spec.vehicles - 1 && spec.vehicles > 1;
    await db.transaction(() async {
      final vid = await db.insertVehicle(
        VehiclesCompanion.insert(
          name: 'Vehicle $v',
          type: VehicleType.car,
          tank1Capacity: const Value(45),
          tankCount: Value(twoTanks ? 2 : 1),
          tank2Kind: Value(twoTanks ? FuelKind.gas : null),
          tank2Capacity: Value(twoTanks ? 12 : null),
        ),
      );
      vehicleIds.add(vid);

      final kinds = [
        for (var i = 0; i < spec.refuelings; i++) _Kind.refuel,
        for (var i = 0; i < spec.expenses; i++) _Kind.expense,
        for (var i = 0; i < spec.services; i++) _Kind.service,
        for (var i = 0; i < spec.incomes; i++) _Kind.income,
        for (var i = 0; i < spec.routes; i++) _Kind.route,
        for (var i = 0; i < spec.readings; i++) _Kind.reading,
        for (var i = 0; i < spec.checklists; i++) _Kind.checklist,
      ]..shuffle(rnd);

      // ~12.5 years of history ending shortly before "today" (2026-09).
      final start = DateTime(2014, 1, 1, 8);
      final end = DateTime(2026, 9, 1, 8);
      final stepMinutes = end.difference(start).inMinutes ~/ kinds.length;
      var odo = 10000.0 + v * 1000;
      var sinceRefuel = 0.0;
      final attachTo = <(String, String)>[];

      for (final (i, kind) in kinds.indexed) {
        final date = start.add(
          Duration(minutes: i * stepMinutes + rnd.nextInt(stepMinutes ~/ 2)),
        );
        final step = 5 + rnd.nextDouble() * 55;
        odo += step;
        sinceRefuel += step;
        switch (kind) {
          case _Kind.refuel:
            final toTank2 = twoTanks && rnd.nextInt(5) == 0;
            final volume = max(3.0, sinceRefuel / (12 + rnd.nextDouble() * 4));
            sinceRefuel = 0;
            final price = 250 + rnd.nextDouble() * 60;
            final id = await db.saveRefueling(
              RefuelingDraft(
                vehicleId: vid,
                date: date,
                odometer: odo,
                fullTank: rnd.nextInt(100) < 85,
                missedPrevious: rnd.nextInt(100) < 2,
                gasStationId: pick(stations),
                paymentMethodId: pick(payments),
                lines: [
                  FuelLineDraft(
                    fuelId: toTank2 ? cng : petrol,
                    pricePerUnit: price,
                    total: price * volume,
                    volume: volume,
                    tank: toTank2 ? 2 : 1,
                  ),
                ],
              ),
            );
            if (i % 40 == 0) attachTo.add(('refuelings', id));
          case _Kind.expense || _Kind.service || _Kind.income:
            final entryKind = switch (kind) {
              _Kind.expense => EntryKind.expense,
              _Kind.service => EntryKind.service,
              _ => EntryKind.income,
            };
            final types = switch (entryKind) {
              EntryKind.expense => expenseTypes,
              EntryKind.service => serviceTypes,
              EntryKind.income => incomeTypes,
            };
            final id = await db.saveEntry(
              EntryDraft(
                vehicleId: vid,
                kind: entryKind,
                date: date,
                odometer: rnd.nextBool() ? odo : null,
                placeId: pick(places),
                paymentMethodId: pick(payments),
                reasonId: rnd.nextInt(4) == 0 ? pick(reasons) : null,
                items: [
                  for (var k = 0; k < 1 + rnd.nextInt(3); k++)
                    EntryItemDraft(
                      typeId: pick(types),
                      amount: 500 + rnd.nextInt(20000).toDouble(),
                    ),
                ],
                installments: rnd.nextInt(100) < 3 ? 3 : 1,
                interval: InstallmentInterval.monthly,
              ),
            );
            if (i % 40 == 1) attachTo.add(('entries', id));
          case _Kind.route:
            final open = rnd.nextInt(100) < 5;
            final startOdo = odo - step;
            final freight = rnd.nextInt(4) == 0;
            await db.saveRoute(
              RoutesCompanion.insert(
                vehicleId: vid,
                startDate: date.subtract(const Duration(hours: 2)),
                startOdometer: startOdo,
                origin: const Value('A'),
                destination: const Value('B'),
                endDate: Value(open ? null : date),
                endOdometer: Value(open ? null : odo),
                mode: Value(freight ? RouteMode.freight : RouteMode.trip),
                valuePerDistance: Value(freight ? null : 20),
                total: Value(freight ? null : step * 20),
                freightValue: Value(freight ? 5000 : null),
              ),
            );
          case _Kind.reading:
            final id = await db.saveReading(
              ReadingsCompanion.insert(
                vehicleId: vid,
                date: date,
                odometer: odo,
              ),
            );
            if (i % 40 == 2) attachTo.add(('readings', id));
          case _Kind.checklist:
            await db.saveChecklist(
              ChecklistDraft(
                vehicleId: vid,
                date: date,
                odometer: odo,
                formId: preTrip,
                title: 'Pre-trip inspection',
                answers: [
                  for (final item in formItems)
                    ChecklistAnswerDraft(
                      label: item.label,
                      status: ChecklistStatus
                          .values[rnd.nextInt(ChecklistStatus.values.length)],
                    ),
                ],
              ),
            );
        }
      }

      for (var r = 0; r < spec.reminders; r++) {
        final byDate = r.isEven;
        await db.insertReminder(
          RemindersCompanion.insert(
            vehicleId: vid,
            target: r % 3 == 0
                ? ReminderTarget.expense
                : ReminderTarget.service,
            typeId: r % 3 == 0 ? pick(expenseTypes) : pick(serviceTypes),
            repeat: const Value(true),
            byDistance: Value(!byDate),
            everyDistance: Value(byDate ? null : 5000),
            byDate: Value(byDate),
            everyAmount: Value(byDate ? 6 : null),
            everyUnit: Value(byDate ? PeriodUnit.month : null),
          ),
        );
      }

      for (final (table, parentId) in attachTo.take(spec.attachments)) {
        await db.applyAttachmentChanges(
          parentTable: table,
          parentId: parentId,
          vehicleId: vid,
          added: [
            PendingAttachment(
              fileName: 'receipt.jpg',
              mimeType: 'image/jpeg',
              bytes: Uint8List.fromList(
                List.generate(spec.attachmentBytes, (k) => k & 0xff),
              ),
            ),
          ],
        );
      }
    });
  }
  return BigDataset(vehicleIds);
}
