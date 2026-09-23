import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';

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
      expect(find.text('1400 km · 4.000 L · PKR293.030/L'), findsOneWidget);
      expect(find.text('50.00 km/L'), findsOneWidget); // Sep efficiency
      expect(find.text('Expenses 11% below August'), findsOneWidget);

      // Month card opens the cost donut.
      await tester.tap(find.byKey(const Key('month-2026-9')));
      await tester.pumpAndSettle();
      expect(find.text('Cost comparison'), findsOneWidget);
      expect(find.text('Refueling'), findsOneWidget);
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
      expect(find.text('40.00 km/L'), findsOneWidget);

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
}
