import 'package:flutter/material.dart' hide Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';
import 'route_reading_test_utils.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// Readings sorted by odometer (the seeded one is the lowest).
  Future<List<Reading>> allReadings(WidgetTester tester) async {
    final list = (await tester.runAsync(() => db.select(db.readings).get()))!;
    return list..sort((a, b) => a.odometer.compareTo(b.odometer));
  }

  testWidgets('without a vehicle it asks to add one', (tester) async {
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Reading');
    expect(find.text('Add vehicle'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'shows the distance unit suffix even without a last-odometer hint',
    (tester) async {
      useTallScreen(tester);
      // No prior reading, so there's no "Last odometer" hint to lean on.
      await seedVehicle(tester, db);
      await tester.pumpWidget(testApp(db));
      await tester.pumpAndSettle();
      await openForm(tester, 'Reading');

      expect(find.textContaining('Last odometer'), findsNothing);
      final odometer = tester.widget<TextField>(field('Odometer'));
      expect(odometer.decoration!.suffixText, 'km');
      await finish(tester);
    },
  );

  testWidgets('saves, edits and deletes a reading', (tester) async {
    useTallScreen(tester);
    final vid = await seedVehicle(tester, db, lastOdometer: 1000);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Reading');

    expect(find.text('Last odometer: 1000 km'), findsOneWidget);
    await tester.enterText(field('Odometer'), '900');
    await tester.pump();
    expect(find.text('Lower than the last odometer'), findsOneWidget);

    await tester.enterText(field('Odometer'), '1234.5');
    await tester.pump();
    expect(find.text('Lower than the last odometer'), findsNothing);
    await tester.enterText(field('Driver'), 'Ali');
    await tester.enterText(field('Notes'), 'Weekly check');
    await save(tester);
    expect(find.text('Reading saved'), findsOneWidget);

    var r = (await allReadings(tester)).last;
    expect(r.vehicleId, vid);
    expect(r.odometer, 1234.5);
    expect(r.driver, 'Ali');
    expect(r.notes, 'Weekly check');

    // Edit loads the saved values and updates in place.
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/reading/${r.id}');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('Odometer')).controller!.text,
      '1234.5',
    );
    await tester.enterText(field('Odometer'), '1240');
    await save(tester);
    var all = await allReadings(tester);
    expect(all, hasLength(2));
    r = all.last;
    expect(r.odometer, 1240);
    expect(r.driver, 'Ali');

    // Soft delete.
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/reading/${r.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    all = await allReadings(tester);
    expect(all.last.deletedAt, isNotNull);
    await finish(tester);
  });
}
