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
      expect(r.primaryVolume, 15);
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
      expect(r.stations[0].volumeByKind, {FuelKind.liquid: 5});
      expect(r.stations[0].cost, 250);
      expect(r.stations[0].pricePerUnit(FuelKind.liquid), 50);
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
      expect(r.primaryVolume, 0);
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

  group('two-tank vehicle: never adds L + kg', () {
    // Petrol in tank 1, CNG in tank 2; one refueling fills both.
    final entries = [
      entry(
        'p1',
        DateTime(2026, 8, 1),
        cost: 1000,
        volume: 5,
        gasStation: 'Shell',
      ),
      RefuelingEntry(
        id: 'both',
        date: DateTime(2026, 8, 10),
        fullTank: true,
        totalCost: 1300,
        gasStation: 'Shell',
        lines: const [
          ReportFuelLine(
            fuelName: 'Petrol',
            kind: FuelKind.liquid,
            tank: 1,
            volume: 5,
            total: 1000,
          ),
          ReportFuelLine(
            fuelName: 'CNG',
            kind: FuelKind.gas,
            tank: 2,
            volume: 10,
            total: 300,
          ),
        ],
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

    RefuelingReport build() => buildRefuelingReport(
      entries: entries,
      cycles: const [],
      primaryResults: const [],
      range: ReportRange.unbounded,
      days: 20,
      distance: 200,
    );

    test('Volume card and "Per refueling" use tank 1 only', () {
      final r = build();
      expect(r.entryCount, 3);
      expect(r.primaryVolume, 10); // 5 + 5 L, the 20 kg of CNG left out
      expect(r.primaryRefuelCount, 2); // the CNG-only refueling isn't one
      expect(r.averageVolumePerRefuel, 5);
      expect(r.volumePerDay, 0.5);
      expect(r.totalCost, 2620); // money still adds up across tanks
    });

    test('gas stations keep volume per fuel kind', () {
      final shell = build().stations.single;
      expect(shell.recordCount, 2);
      expect(shell.volumeByKind, {FuelKind.liquid: 10, FuelKind.gas: 10});
      expect(shell.cost, 2300);
      expect(shell.pricePerUnit(FuelKind.liquid), 200);
      expect(shell.pricePerUnit(FuelKind.gas), 30);
      expect(shell.pricePerUnit(FuelKind.electric), isNull);
    });

    test('the "All" chip uses the vehicle tank-1 kind and tank-1 volume', () {
      final all = fuelCardFigures(build(), primaryKind: FuelKind.liquid);
      expect(all.kind, FuelKind.liquid);
      expect(all.volume, 10);
      expect(all.recordCount, 3);
      final cng = fuelCardFigures(
        build(),
        fuelName: 'CNG',
        primaryKind: FuelKind.liquid,
      );
      expect(cng.kind, FuelKind.gas);
      expect(cng.volume, 20);
      expect(cng.recordCount, 2);
    });
  });

  group('fuelCardFigures', () {
    // Petrol has two measured cycles; Premium was bought once, no cycle.
    final entries = [
      entry('e1', DateTime(2026, 8, 10), cost: 1000, volume: 5),
      entry('e2', DateTime(2026, 8, 20), cost: 1100, volume: 5),
      entry('e3', DateTime(2026, 9, 5), cost: 1200, volume: 4),
      entry(
        'x',
        DateTime(2026, 9, 6),
        cost: 500,
        volume: 2,
        fuel: 'Premium',
        fullTank: false,
      ),
    ];
    final stats = ConsumptionStats.compute([
      sample('e1', DateTime(2026, 8, 10), 1000, 5, 1000),
      sample('e2', DateTime(2026, 8, 20), 1100, 5, 1100),
      sample('e3', DateTime(2026, 9, 5), 1200, 4, 1200),
    ]);
    final fuelByRefueling = {for (final e in entries) e.id: e.lines};
    final report = buildRefuelingReport(
      entries: entries,
      cycles: [for (final c in stats.cycles) ?tagCycle(c, 1, fuelByRefueling)],
      primaryResults: stats.results,
      range: ReportRange.unbounded,
      days: 30,
      distance: 200,
    );

    test('"All" shows the primary tank figures', () {
      final f = fuelCardFigures(report, primaryKind: FuelKind.liquid);
      expect(f.recordCount, 4);
      expect(f.lastEfficiency, 25); // 100 km / 4 L
      expect(f.lowestEfficiency, 20);
      expect(f.highestEfficiency, 25);
      expect(f.averageEfficiency, closeTo(200 / 9, 1e-9));
      expect(f.lastCostPerDistance, 12);
      expect(f.averageCostPerDistance, closeTo(2300 / 200, 1e-9));
      expect(f.lowestCostPerDistance, 11);
      expect(f.highestCostPerDistance, 12);
    });

    test("a fuel chip shows only that fuel's values — never the All ones", () {
      final f = fuelCardFigures(
        report,
        fuelName: 'Premium',
        primaryKind: FuelKind.liquid,
      );
      expect(f.recordCount, 1);
      expect(f.volume, 2);
      expect(f.cost, 500);
      expect(f.lastEfficiency, isNull);
      expect(f.averageEfficiency, isNull);
      expect(f.lowestEfficiency, isNull);
      expect(f.highestEfficiency, isNull);
      expect(f.lastCostPerDistance, isNull);
      expect(f.averageCostPerDistance, isNull);
      expect(f.lowestCostPerDistance, isNull);
      expect(f.highestCostPerDistance, isNull);

      final petrol = fuelCardFigures(
        report,
        fuelName: 'Petrol',
        primaryKind: FuelKind.liquid,
      );
      expect(petrol.recordCount, 3);
      expect(petrol.lastEfficiency, 25);
    });

    test('record count label is singular / plural', () {
      expect(recordCountLabel(1), '1 record');
      expect(recordCountLabel(0), '0 records');
      expect(recordCountLabel(3), '3 records');
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
      expect(find.text('Cost / km — Last'), findsOneWidget);

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

    testWidgets('a fuel chip shows only that fuel (dashes, its own count)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final vid = await addTestVehicle(db);
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 8, 5),
          odometer: 1000,
          volume: 5,
        );
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 8, 20),
          odometer: 1100,
          volume: 5,
        );
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 5),
          odometer: 1200,
          volume: 5,
        );
        // One partial fill of another fuel: no measured cycle of its own.
        await addRefuel(
          db,
          vid,
          date: DateTime(2026, 9, 6),
          odometer: 1210,
          volume: 2,
          fuel: 'Gas Premium',
          fullTank: false,
        );
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REFUELING'));
      await tester.pumpAndSettle();

      String fuelCard(String key) =>
          tester.widget<Text>(find.byKey(Key(key))).data!;

      expect(find.text('4 records'), findsOneWidget);
      expect(fuelCard('fuel-card-efficiency'), '20.000 km/L');

      final premium = find.widgetWithText(ChoiceChip, 'Gas Premium');
      await tester.ensureVisible(premium);
      await tester.pumpAndSettle();
      await tester.tap(premium);
      await tester.pumpAndSettle();

      expect(find.text('1 record'), findsOneWidget);
      expect(fuelCard('fuel-card-efficiency'), '—');
      expect(fuelCard('fuel-card-cost-per-distance'), '—');
      expect(find.text('Period average —'), findsNWidgets(2));
      expect(find.text('Lower —'), findsNWidgets(2));

      await unmountApp(tester);
    });
  });
}
