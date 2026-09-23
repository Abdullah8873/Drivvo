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

  Future<List<Route>> allRoutes(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.routes).get()))!;

  testWidgets('without a vehicle it asks to add one', (tester) async {
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Route');
    expect(find.text('Add vehicle'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('saves a trip with a computed total', (tester) async {
    useTallScreen(tester);
    final vid = await seedVehicle(tester, db, lastOdometer: 1000);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Route');

    // Initial odometer defaults to the last odometer.
    expect(find.text('Last odometer: 1000 km'), findsOneWidget);
    final initial = tester.widget<TextField>(field('Initial odometer'));
    expect(initial.controller!.text, '1000');

    await tester.enterText(field('Origin'), 'Lahore');
    await tester.enterText(field('Destination'), 'Islamabad');
    await tester.enterText(field('Final odometer'), '1150');
    await tester.enterText(field('Value km'), '12.5');
    await tester.pump();
    expect(find.text('PKR1,875.00'), findsOneWidget);

    await save(tester);
    final r = (await allRoutes(tester)).single;
    expect(r.vehicleId, vid);
    expect(r.mode, RouteMode.trip);
    expect(r.origin, 'Lahore');
    expect(r.destination, 'Islamabad');
    expect(r.startOdometer, 1000);
    expect(r.endOdometer, 1150);
    expect(r.valuePerDistance, 12.5);
    expect(r.total, 1875);
    expect(r.endDate!.difference(r.startDate), const Duration(hours: 1));
    expect(r.freightValue, isNull);
    await finish(tester);
  });

  testWidgets('saves a freight route', (tester) async {
    useTallScreen(tester);
    await seedVehicle(tester, db);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Route');

    await tester.enterText(field('Initial odometer'), '500');
    await tester.enterText(field('Final odometer'), '800');
    await tester.tap(find.text('FREIGHT'));
    await tester.pumpAndSettle();
    expect(field('Value km'), findsNothing);

    await tester.enterText(field('Cargo type'), 'Wheat');
    await tester.enterText(field('Contractor'), 'Acme');
    await tester.enterText(field('Unit'), 'bags');
    await tester.enterText(field('Amount'), '40');
    await tester.enterText(field('Weight'), '2000');
    await tester.enterText(field('Volume (m³)'), '3.5');
    await tester.enterText(field('Freight value'), '25000');
    await tester.enterText(field('Installments'), '2');
    await save(tester);

    final r = (await allRoutes(tester)).single;
    expect(r.mode, RouteMode.freight);
    expect(r.cargoType, 'Wheat');
    expect(r.contractor, 'Acme');
    expect(r.cargoUnit, 'bags');
    expect(r.cargoAmount, 40);
    expect(r.cargoWeight, 2000);
    expect(r.cargoVolume, 3.5);
    expect(r.freightValue, 25000);
    expect(r.installments, 2);
    expect(r.total, isNull);
    await finish(tester);
  });

  testWidgets('saves an open route, finishes it later, then deletes it', (
    tester,
  ) async {
    useTallScreen(tester);
    await seedVehicle(tester, db, lastOdometer: 2000);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await openForm(tester, 'Route');

    await tester.enterText(field('Origin'), 'Home');
    await save(tester);
    expect(find.text('Route saved — finish it later'), findsOneWidget);

    var r = (await allRoutes(tester)).single;
    expect(r.startOdometer, 2000);
    expect(r.endOdometer, isNull);
    expect(r.endDate, isNull);

    // Edit: a final odometer lower than the initial one is rejected.
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/route/${r.id}');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Origin')).controller!.text, 'Home');
    await tester.enterText(field('Final odometer'), '1990');
    await save(tester);
    expect(
      find.text('Final odometer must not be lower than the initial one'),
      findsOneWidget,
    );

    await tester.enterText(field('Final odometer'), '2040');
    await save(tester);
    r = (await allRoutes(tester)).single;
    expect(r.endOdometer, 2040);
    expect(r.endDate, isNotNull);
    expect(r.origin, 'Home');

    // Soft delete from the app bar.
    GoRouter.of(tester.element(find.text('History')))
        .push('/edit/route/${r.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    r = (await allRoutes(tester)).single;
    expect(r.deletedAt, isNotNull);
    await finish(tester);
  });
}
