import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/calc/consumption.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/reports/refueling_report.dart';
import 'package:motolog/features/reports/report_period.dart';
import 'package:motolog/features/reports/report_providers.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

/// A refueling with a single fuel line — the common case in these tests.
RefuelingEntry entry(
  String id,
  DateTime date, {
  required double cost,
  required double volume,
  String fuel = 'Petrol',
  FuelKind kind = FuelKind.liquid,
  int tank = 1,
  bool fullTank = true,
  String? gasStation,
}) => RefuelingEntry(
  id: id,
  date: date,
  fullTank: fullTank,
  totalCost: cost,
  gasStation: gasStation,
  lines: [
    ReportFuelLine(
      fuelName: fuel,
      kind: kind,
      tank: tank,
      volume: volume,
      total: cost,
    ),
  ],
);

RefuelSample sample(
  String id,
  DateTime date,
  double odometer,
  double volume,
  double cost, {
  bool fullTank = true,
  bool missedPrevious = false,
}) => RefuelSample(
  id: id,
  date: date,
  odometer: odometer,
  volume: volume,
  cost: cost,
  fullTank: fullTank,
  missedPrevious: missedPrevious,
);

void main() {
  group('buildRefuelingReport: totals and routine', () {
    // Three tank-1 Petrol refuelings, 100 km / 5 L apart, all full tanks.
    final entries = [
      entry('e1', DateTime(2026, 8, 10), cost: 1000, volume: 5),
      entry('e2', DateTime(2026, 8, 20), cost: 1100, volume: 5),
      entry('e3', DateTime(2026, 9, 5), cost: 1200, volume: 5),
    ];
    final samples = [
      sample('e1', DateTime(2026, 8, 10), 1000, 5, 1000),
      sample('e2', DateTime(2026, 8, 20), 1100, 5, 1100),
      sample('e3', DateTime(2026, 9, 5), 1200, 5, 1200),
    ];
    final stats = ConsumptionStats.compute(samples);
    final fuelByRefueling = {for (final e in entries) e.id: e.lines};
    final cycles = [
      for (final c in stats.cycles) ?tagCycle(c, 1, fuelByRefueling),
    ];

    test('totals, price and efficiency figures', () {
      final r = buildRefuelingReport(
        entries: entries,
        cycles: cycles,
        primaryResults: stats.results,
        range: ReportRange.unbounded,
        days: 61,
        distance: 400,
        primaryTankCapacity: 50,
      );

      expect(r.entryCount, 3);
      expect(r.totalCost, 3300);
      expect(r.totalVolume, 15);
      expect(r.fullTankCount, 3);
      expect(r.fullTankRatio, 1.0);
      expect(r.costPerDay, closeTo(3300 / 61, 1e-9));
      expect(r.costPerDistance, closeTo(3300 / 400, 1e-9));
      expect(r.monthlyProjection, closeTo(3300 / 61 * 30, 1e-9));
      expect(r.averageVolumePerRefuel, 5);
      expect(r.volumePerDay, closeTo(15 / 61, 1e-9));

      // Prices paid: 200, 220, 240 per unit; weighted average 220.
      expect(r.primaryPricePerUnit, 220);
      expect(r.lowestPricePerUnit, 200);
      expect(r.highestPricePerUnit, 240);

      // Two 100 km / 5 L cycles: efficiency 20 km/L each.
      expect(r.primaryEfficiency, 20);
      expect(r.lowestEfficiency, 20);
      expect(r.highestEfficiency, 20);
      expect(r.primaryLastEfficiency, 20);
      expect(r.estimatedRange, 1000); // 20 * 50

      // Gaps: 100 km / 10 days, then 100 km / 16 days.
      expect(r.averageDistanceBetween, 100);
      expect(r.averageDaysBetween, closeTo((10 + 16) / 2, 1e-9));
    });

    test('months and monthly cost include the whole span', () {
      final r = buildRefuelingReport(
        entries: entries,
        cycles: cycles,
        primaryResults: stats.results,
        range: ReportRange.unbounded,
        days: 61,
        distance: 400,
      );
      expect(r.months, [DateTime(2026, 8), DateTime(2026, 9)]);
      expect(r.monthlyCost, {
        DateTime(2026, 8): 1000 + 1100,
        DateTime(2026, 9): 1200,
      });
    });

    test('a period only counts refuelings and cycles ending in it', () {
      final r = buildRefuelingReport(
        entries: entries,
        cycles: cycles,
        primaryResults: stats.results,
        range: ReportRange(from: DateTime(2026, 9), to: DateTime(2026, 10)),
        days: 5,
        distance: 100,
      );
      expect(r.entryCount, 1);
      expect(r.totalCost, 1200);
      // Only the cycle ending 2026-09-05 (e2 → e3) counts, even though it
      // started in August.
      expect(r.primaryEfficiency, 20);
      expect(r.months, [DateTime(2026, 9)]);
    });
  });

  group('buildRefuelingReport: gas stations', () {
    test('grouped by name, largest cost first', () {
      final entries = [
        entry(
          'a',
          DateTime(2026, 8, 1),
          cost: 100,
          volume: 2,
          gasStation: 'Shell',
        ),
        entry(
          'b',
          DateTime(2026, 8, 5),
          cost: 150,
          volume: 3,
          gasStation: 'Shell',
        ),
        entry(
          'c',
          DateTime(2026, 8, 10),
          cost: 80,
          volume: 1,
          gasStation: 'Total',
        ),
        // No gas station on record: excluded from the stations list.
        entry('d', DateTime(2026, 8, 12), cost: 50, volume: 1),
      ];
      final r = buildRefuelingReport(
        entries: entries,
        cycles: const [],
        primaryResults: const [],
        range: ReportRange.unbounded,
        days: 30,
        distance: 100,
      );

      expect(r.stations, hasLength(2));
      expect(r.stations[0].name, 'Shell');
      expect(r.stations[0].recordCount, 2);
      expect(r.stations[0].volume, 5);
      expect(r.stations[0].cost, 250);
      expect(r.stations[0].averagePricePerUnit, 50);
      expect(r.stations[1].name, 'Total');
      expect(r.stations[1].cost, 80);

      // Every refueling still counts toward the vehicle-wide totals.
      expect(r.entryCount, 4);
      expect(r.totalCost, 380);
    });

    test('no gas stations on record', () {
      final r = buildRefuelingReport(
        entries: [entry('a', DateTime(2026, 8, 1), cost: 100, volume: 2)],
        cycles: const [],
        primaryResults: const [],
        range: ReportRange.unbounded,
        days: 30,
        distance: 100,
      );
      expect(r.stations, isEmpty);
    });
  });

  group('buildRefuelingReport: per-fuel filter (two-tank vehicle)', () {
    test("each fuel's cycles never mix with another fuel's", () {
      final entries = [
        entry(
          'p1',
          DateTime(2026, 8, 1),
          cost: 1000,
          volume: 5,
          fuel: 'Petrol',
        ),
        entry(
          'p2',
          DateTime(2026, 8, 15),
          cost: 1100,
          volume: 5,
          fuel: 'Petrol',
        ),
        entry(
          'c1',
          DateTime(2026, 8, 3),
          cost: 300,
          volume: 10,
          fuel: 'CNG',
          kind: FuelKind.gas,
          tank: 2,
        ),
        entry(
          'c2',
          DateTime(2026, 8, 20),
          cost: 320,
          volume: 10,
          fuel: 'CNG',
          kind: FuelKind.gas,
          tank: 2,
        ),
      ];
      final fuelByRefueling = {for (final e in entries) e.id: e.lines};

      final petrolSamples = [
        sample('p1', DateTime(2026, 8, 1), 1000, 5, 1000),
        sample('p2', DateTime(2026, 8, 15), 1100, 5, 1100),
      ];
      final cngSamples = [
        sample('c1', DateTime(2026, 8, 3), 500, 10, 300),
        sample('c2', DateTime(2026, 8, 20), 600, 10, 320),
      ];
      final petrolStats = ConsumptionStats.compute(petrolSamples);
      final cngStats = ConsumptionStats.compute(cngSamples);
      final cycles = [
        for (final c in petrolStats.cycles) ?tagCycle(c, 1, fuelByRefueling),
        for (final c in cngStats.cycles) ?tagCycle(c, 2, fuelByRefueling),
      ];

      final r = buildRefuelingReport(
        entries: entries,
        cycles: cycles,
        primaryResults: petrolStats.results,
        range: ReportRange.unbounded,
        days: 30,
        distance: 200,
      );

      expect(r.fuels, hasLength(2));
      final petrol = r.fuels.firstWhere((f) => f.fuelName == 'Petrol');
      final cng = r.fuels.firstWhere((f) => f.fuelName == 'CNG');

      expect(petrol.kind, FuelKind.liquid);
      expect(petrol.volume, 10);
      expect(petrol.cost, 2100);
      expect(petrol.cycles, hasLength(1));
      expect(petrol.lastEfficiency, 100 / 5); // 100 km / 5 L

      expect(cng.kind, FuelKind.gas);
      expect(cng.volume, 20);
      expect(cng.cost, 620);
      expect(cng.cycles, hasLength(1));
      expect(cng.lastEfficiency, 100 / 10); // 100 km / 10 kg

      // Neither fuel's cycle list contains the other's efficiency.
      expect(petrol.cycles.every((c) => c.fuelName == 'Petrol'), isTrue);
      expect(cng.cycles.every((c) => c.fuelName == 'CNG'), isTrue);

      // Largest volume first: CNG (20) before Petrol (10).
      expect(r.fuels.first.fuelName, 'CNG');
    });

    test('tagCycle returns null when the tank has no matching fuel line', () {
      final samples = [
        sample('x1', DateTime(2026, 8, 1), 1000, 5, 1000),
        sample('x2', DateTime(2026, 8, 15), 1100, 5, 1100),
      ];
      final stats = ConsumptionStats.compute(samples);
      // fuelByRefueling only knows about tank 1; asking for tank 2 misses.
      final fuelByRefueling = {
        'x2': [
          const ReportFuelLine(
            fuelName: 'Petrol',
            kind: FuelKind.liquid,
            tank: 1,
            volume: 5,
            total: 1100,
          ),
        ],
      };
      expect(tagCycle(stats.cycles.single, 2, fuelByRefueling), isNull);
      expect(tagCycle(stats.cycles.single, 1, fuelByRefueling), isNotNull);
    });
  });

  group('buildRefuelingReport: monthly projection', () {
    test('cost per day × 30', () {
      final r = buildRefuelingReport(
        entries: [entry('a', DateTime(2026, 8, 1), cost: 600, volume: 3)],
        cycles: const [],
        primaryResults: const [],
        range: ReportRange.unbounded,
        days: 20,
        distance: 100,
      );
      expect(r.costPerDay, 30);
      expect(r.monthlyProjection, 900);
    });

    test('no days tracked → no projection', () {
      final r = buildRefuelingReport(
        entries: [entry('a', DateTime(2026, 8, 1), cost: 600, volume: 3)],
        cycles: const [],
        primaryResults: const [],
        range: ReportRange.unbounded,
        days: 0,
        distance: 0,
      );
      expect(r.costPerDay, isNull);
      expect(r.monthlyProjection, isNull);
      expect(r.costPerDistance, isNull);
    });
  });

  group('buildRefuelingReport: empty data', () {
    test('every figure is null/zero/empty, nothing throws', () {
      final r = buildRefuelingReport(
        entries: const [],
        cycles: const [],
        primaryResults: const [],
        range: ReportRange.unbounded,
        days: 0,
        distance: 0,
        primaryTankCapacity: 50,
      );

      expect(r.entryCount, 0);
      expect(r.totalCost, 0);
      expect(r.totalVolume, 0);
      expect(r.fullTankCount, 0);
      expect(r.fullTankRatio, isNull);
      expect(r.averageVolumePerRefuel, isNull);
      expect(r.primaryPricePerUnit, isNull);
      expect(r.lowestPricePerUnit, isNull);
      expect(r.highestPricePerUnit, isNull);
      expect(r.primaryEfficiency, isNull);
      expect(r.lowestEfficiency, isNull);
      expect(r.highestEfficiency, isNull);
      expect(r.estimatedRange, isNull); // no cycles → no efficiency
      expect(r.averageDistanceBetween, isNull);
      expect(r.averageDaysBetween, isNull);
      expect(r.months, isEmpty);
      expect(r.monthlyCost, isEmpty);
      expect(r.fuels, isEmpty);
      expect(r.stations, isEmpty);
    });

    test('a single refueling has no gap and no cycle yet', () {
      final samples = [sample('a', DateTime(2026, 8, 1), 1000, 5, 1000)];
      final stats = ConsumptionStats.compute(samples);
      final r = buildRefuelingReport(
        entries: [entry('a', DateTime(2026, 8, 1), cost: 1000, volume: 5)],
        cycles: const [],
        primaryResults: stats.results,
        range: ReportRange.unbounded,
        days: 1,
        distance: 0,
      );
      expect(r.entryCount, 1);
      expect(r.averageDistanceBetween, isNull);
      expect(r.averageDaysBetween, isNull);
      expect(r.primaryEfficiency, isNull);
    });
  });

  group('RefuelingReportTab widget', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        reportNowProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12)),
      ],
      child: const MotoLogApp(),
    );

    testWidgets('renders every section with seeded refuelings', (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final vid = await addTestVehicle(db);
        final station = await db
            .into(db.catalogItems)
            .insertReturning(
              CatalogItemsCompanion.insert(
                kind: CatalogKind.gasStation,
                name: 'Shell',
              ),
            );
        final fuelId = await catalogId(db, CatalogKind.fuel, 'Petrol');

        Future<void> refuel(
          DateTime date,
          double odometer, {
          double volume = 5,
          double price = 200,
        }) async {
          final total = volume * price;
          final r = await db
              .into(db.refuelings)
              .insertReturning(
                RefuelingsCompanion.insert(
                  vehicleId: vid,
                  date: date,
                  odometer: odometer,
                  totalCost: total,
                  gasStationId: Value(station.id),
                ),
              );
          await db
              .into(db.refuelingFuels)
              .insert(
                RefuelingFuelsCompanion.insert(
                  refuelingId: r.id,
                  fuelId: fuelId,
                  pricePerUnit: price,
                  total: total,
                  volume: volume,
                ),
              );
        }

        await refuel(DateTime(2026, 8, 5), 1000, price: 200);
        await refuel(DateTime(2026, 8, 20), 1100, price: 210);
        await refuel(DateTime(2026, 9, 5), 1200, price: 220);
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REFUELING'));
      await tester.pumpAndSettle();

      // Top stat grid.
      expect(find.text('Cost'), findsOneWidget);
      // "Volume" is also the Fuel card's footer label.
      expect(find.text('Volume'), findsWidgets);
      expect(find.text('Average price'), findsOneWidget);
      expect(find.text('Fuel efficiency'), findsOneWidget);

      // Refueling routine card.
      expect(find.text('Refueling routine'), findsOneWidget);
      expect(find.text('Between refuelings'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Estimated range'), findsOneWidget);
      expect(find.text('Monthly projection'), findsOneWidget);
      expect(
        find.textContaining('refuelings with a full tank'),
        findsOneWidget,
      );

      // Monthly chart.
      expect(find.text('Monthly expenses chart'), findsOneWidget);

      // Fuel card: "All" plus a chip for the seeded fuel.
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Petrol'), findsWidgets);
      expect(find.text('Fuel efficiency — Last'), findsOneWidget);
      expect(find.text('Cost / Km — Last'), findsOneWidget);

      // Gas stations.
      expect(find.text('Gas stations'), findsOneWidget);
      expect(find.text('Shell'), findsWidgets);

      // Charts.
      expect(find.text('Fuels chart'), findsOneWidget);
      expect(find.text('Gas stations chart'), findsOneWidget);
      expect(find.text('Average by fuel chart'), findsOneWidget);
      expect(find.text('Fuels price chart'), findsOneWidget);

      await unmountApp(tester);
    });
  });
}
