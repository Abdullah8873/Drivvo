import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/entries/entry_queries.dart';
import 'package:motolog/features/history/history_queries.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// Unmounts the app so drift can cancel its stream queries (they finish
  /// with zero-length timers the test binding would otherwise flag).
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // Tall screen so the whole timeline (under the reminders strip) is built.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
  }

  testWidgets('no vehicle: offers to add one', (tester) async {
    await pumpApp(tester);
    expect(find.text('Add your first vehicle'), findsOneWidget);
    await tester.tap(find.text('Add your first vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Add your first vehicle'), findsNothing);
    await unmount(tester);
  });

  testWidgets('vehicle without records: shows the + hint', (tester) async {
    await addTestVehicle(db);
    await pumpApp(tester);
    expect(find.text('Tap + to add your first record'), findsOneWidget);
    await unmount(tester);
  });

  group('with records', () {
    late String vid;
    late String sep17;

    setUp(() async {
      vid = await addTestVehicle(db);
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 8, 10, 9),
        odometer: 1000,
        volume: 5,
      );
      await addEntry(
        db,
        vid,
        kind: EntryKind.service,
        date: DateTime(2026, 8, 20, 12),
        odometer: 1100,
        items: {'Oil Change': 1200, 'Oil Filter': 300},
      );
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 9, 5, 8, 15),
        odometer: 1200,
        volume: 5,
      );
      sep17 = await addRefuel(
        db,
        vid,
        date: DateTime(2026, 9, 17, 16, 43),
        odometer: 1400,
        volume: 4,
        notes: 'Highway trip',
      );
    });

    testWidgets('groups records under month summary cards', (tester) async {
      await pumpApp(tester);
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('Oil Change +1'), findsOneWidget);
      expect(find.text('Petrol'), findsNWidgets(3));
      // "odometer · efficiency · volume" — efficiency from the engine, shown
      // on the refuel that starts each cycle; none on the newest one.
      expect(find.text('1400 km · 4.000 L'), findsOneWidget);
      expect(find.text('1200 km · 50.000 km/L · 5.000 L'), findsOneWidget);
      expect(find.text('1000 km · 40.000 km/L · 5.000 L'), findsOneWidget);
      // September: both cycles close there (one started in August):
      // 400 km / 9 L.
      expect(find.text('44.444 km/L'), findsOneWidget);
      // Distance: 1400 − August's 1100; August falls back to its own range.
      expect(find.text('300 km'), findsOneWidget);
      expect(find.text('100 km'), findsOneWidget);
      expect(find.text('Expenses 11% below August'), findsOneWidget);

      // Month card opens the cost donut.
      await tester.tap(find.byKey(const Key('month-2026-9')));
      await tester.pumpAndSettle();
      expect(find.text('Cost comparison'), findsOneWidget);
      expect(find.text('Refueling'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('month cost screen follows live data', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('month-2026-9')));
      await tester.pumpAndSettle();
      expect(find.text('PKR2,637.27'), findsWidgets); // 9 L × 293.03

      await tester.runAsync(
        () => db.softDeleteRecord(RecordModule.refueling, sep17),
      );
      await tester.pumpAndSettle();
      expect(find.text('PKR2,637.27'), findsNothing);
      expect(find.text('PKR1,465.15'), findsWidgets); // 5 L left
      await unmount(tester);
    });

    testWidgets('row expands in place and can be deleted', (tester) async {
      await pumpApp(tester);
      expect(find.text('Highway trip'), findsNothing);

      await tester.tap(find.byKey(Key('row-$sep17')));
      await tester.pumpAndSettle();
      expect(find.text('Highway trip'), findsOneWidget);
      expect(find.text('Full tank'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('row-$sep17')), findsNothing);
      expect(find.text('Petrol'), findsNWidgets(2));
      final row = await (db.select(
        db.refuelings,
      )..where((r) => r.id.equals(sep17))).getSingle();
      expect(row.deletedAt, isNotNull);
      await unmount(tester);
    });

    testWidgets('view opens the detail screen and steps through refuels', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(Key('row-$sep17')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View'));
      await tester.pumpAndSettle();

      expect(find.text('2026-09-17 - 16:43'), findsOneWidget);
      expect(find.text('Distance since last'), findsOneWidget);
      expect(find.text('200 km'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Highway trip'), 200);
      expect(find.text('Highway trip'), findsOneWidget);
      // Newest refuel: nothing newer.
      final newer = tester.widget<IconButton>(
        find.byKey(const Key('detail-newer')),
      );
      expect(newer.onPressed, isNull);

      await tester.tap(find.byKey(const Key('detail-older')));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-05 - 08:15'), findsOneWidget);
      expect(find.text('50.000 km/L'), findsOneWidget); // engine: 200 / 4
      expect(
        find.text('Set tank capacity in the vehicle to see % of tank'),
        findsOneWidget,
      );

      // Skips the service in between: next older is the August refuel.
      await tester.tap(find.byKey(const Key('detail-older')));
      await tester.pumpAndSettle();
      expect(find.text('2026-08-10 - 09:00'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('search filters the timeline', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('history-search-field')),
        'filter',
      );
      await tester.pumpAndSettle();
      expect(find.text('Oil Change +1'), findsOneWidget);
      expect(find.text('Petrol'), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('deleting an installment removes the whole group', (
    tester,
  ) async {
    final vid = await addTestVehicle(db);
    final type = await catalogId(db, CatalogKind.expenseType, 'Insurance');
    final parentId = await db.saveEntry(
      EntryDraft(
        vehicleId: vid,
        kind: EntryKind.expense,
        date: DateTime(2026, 7, 1),
        items: [EntryItemDraft(typeId: type, amount: 3000)],
        installments: 3,
      ),
    );
    await pumpApp(tester);
    expect(find.text('Insurance'), findsNWidgets(3));

    await tester.tap(find.byKey(Key('row-$parentId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This deletes all 3 installments'), findsOne);
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(find.text('Insurance'), findsNothing);
    final rows = await tester.runAsync(
      () => (db.select(db.entries)..where((e) => e.deletedAt.isNull())).get(),
    );
    expect(rows, isEmpty);
    await unmount(tester);
  });

  testWidgets('two-tank vehicle: per-tank efficiency units and % of tank', (
    tester,
  ) async {
    final v = await db
        .into(db.vehicles)
        .insertReturning(
          VehiclesCompanion.insert(
            name: 'Bi-fuel',
            type: VehicleType.car,
            tankCount: const Value(2),
            tank1Capacity: const Value(40),
            tank2Kind: const Value(FuelKind.gas),
            tank2Capacity: const Value(10),
          ),
        );
    final first = await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 1),
      odometer: 1000,
      lines: [
        (fuel: 'Petrol', volume: 10, tank: 1),
        (fuel: 'CNG', volume: 5, tank: 2),
      ],
    );
    final cngOnly = await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 10),
      odometer: 1200,
      fuel: 'CNG',
      tank: 2,
      volume: 4,
    );
    await addRefuel(
      db,
      v.id,
      date: DateTime(2026, 9, 20),
      odometer: 1500,
      lines: [
        (fuel: 'Petrol', volume: 20, tank: 1),
        (fuel: 'CNG', volume: 5, tank: 2),
      ],
    );
    await pumpApp(tester);

    // CNG is measured in km/kg, not in the liquid format.
    expect(find.text('1200 km · 60.000 km/kg · 4.000 kg'), findsOneWidget);
    expect(
      find.text('1000 km · 25.000 km/L · 10.000 L + 5.000 kg'),
      findsOneWidget,
    );
    // Month card: one efficiency per tank.
    expect(find.text('25.000 km/L'), findsOneWidget); // 500 km / 20 L
    expect(find.text('55.556 km/kg'), findsOneWidget); // 500 km / 9 kg
    expect(find.byKey(Key('row-$cngOnly')), findsOneWidget);

    await tester.tap(find.byKey(Key('row-$first')));
    await tester.pumpAndSettle();
    expect(find.text('Efficiency (Petrol)'), findsOneWidget);
    expect(find.text('Efficiency (CNG)'), findsOneWidget);
    expect(find.text('50.000 km/kg'), findsOneWidget);

    await tester.tap(find.byTooltip('View'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('of CNG tank'), 200);
    expect(find.text('25%'), findsOneWidget); // 10 L of 40 L
    expect(find.text('50%'), findsOneWidget); // 5 kg of 10 kg
    expect(find.text('of Petrol tank'), findsOneWidget);
    expect(find.textContaining('Set tank capacity'), findsNothing);
    await unmount(tester);
  });
}
