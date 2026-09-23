import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/widgets/module_form_scaffold.dart';
import 'package:motolog/features/refueling/refueling_queries.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late Map<String, CatalogItem> fuels;
  final lastWeek = DateTime.now().subtract(const Duration(days: 7));

  setUp(() async {
    db = testDatabase();
    final list = await db.watchCatalog(CatalogKind.fuel).first;
    fuels = {for (final f in list) f.name: f};
  });

  // Widget tests run on a fake clock, but drift needs real async time. So:
  // - `real` runs a database call from the test body on real time;
  // - `settle` lets real time pass between pumps until the form's own
  //   database loads/saves have landed.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() call) async =>
      (await tester.runAsync(call)) as T;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  /// Pumps the app on [location] with a tall screen so SAVE is visible.
  Future<void> open(WidgetTester tester, String location) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testApp(db));
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first)).push(location);
    await settle(tester);
  }

  /// Unmounts the app (flushing drift's stream-close timers) and closes the
  /// database — call at the end of each test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await real(tester, db.close);
  }

  Finder field(String label) =>
      find.widgetWithText(TextField, label).hitTestable();

  Future<String> addRefuel(WidgetTester tester, String vid) => real(
    tester,
    () => db.saveRefueling(
      RefuelingDraft(
        vehicleId: vid,
        date: lastWeek,
        odometer: 900,
        lines: [
          FuelLineDraft(
            fuelId: fuels['Gas Premium']!.id,
            pricePerUnit: 300,
            total: 1500,
            volume: 5,
          ),
        ],
      ),
    ),
  );

  testWidgets('creates a refueling for the current vehicle', (tester) async {
    await real(tester, () => addTestVehicle(db, name: 'Honda CG125'));
    await open(tester, '/add/refueling');

    expect(find.text('Honda CG125'), findsOneWidget);
    await tester.tap(find.widgetWithText(PickerField, 'Fuel'));
    await settle(tester);
    expect(find.text('CNG'), findsNothing); // liquid tank → liquid fuels
    await tester.tap(find.text('Petrol'));
    await settle(tester);

    await tester.enterText(field('Odometer'), '1000');
    await tester.enterText(field('Price / L'), '300');
    await tester.enterText(field('Liters'), '5');
    await tester.tap(find.text('SAVE'));
    await settle(tester);

    expect(find.text('Refueling saved'), findsOneWidget);
    final saved = await real(tester, db.select(db.refuelings).getSingle);
    expect(saved.odometer, 1000);
    expect(saved.totalCost, 1500);
    expect(saved.fullTank, isTrue);
    final line = await real(tester, db.select(db.refuelingFuels).getSingle);
    expect(line.fuelId, fuels['Petrol']!.id);
    expect(line.volume, 5);
    await finish(tester);
  });

  testWidgets('defaults to the last fuel and warns on a lower odometer', (
    tester,
  ) async {
    final vid = await real(tester, () => addTestVehicle(db));
    await addRefuel(tester, vid);
    await open(tester, '/add/refueling');

    expect(find.text('Gas Premium'), findsOneWidget);
    expect(find.text('Last odometer: 900 km'), findsOneWidget);

    await tester.enterText(field('Odometer'), '800');
    await tester.enterText(field('Total cost'), '1000');
    await tester.enterText(field('Liters'), '4');
    await tester.tap(find.text('SAVE'));
    await settle(tester);

    expect(find.text('Check the odometer'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'SAVE'));
    await settle(tester);

    final list = await real(tester, () => db.watchRefuelings(vid).first);
    // Newest first: today's 800 km entry, then last week's 900 km one.
    expect(list.map((r) => r.refueling.odometer), [800, 900]);
    expect(list.first.lines.single.line.pricePerUnit, 250);
    await finish(tester);
  });

  testWidgets('edit mode loads, updates and deletes', (tester) async {
    final vid = await real(tester, () => addTestVehicle(db));
    final id = await addRefuel(tester, vid);
    await open(tester, '/edit/refueling/$id');

    final odometer = tester.widget<TextField>(field('Odometer'));
    expect(odometer.controller!.text, '900');
    expect(find.text('Gas Premium'), findsOneWidget);

    await tester.enterText(field('Odometer'), '950');
    await tester.tap(find.text('SAVE'));
    await settle(tester);
    final updated = await real(tester, () => db.getRefueling(id));
    expect(updated!.refueling.odometer, 950);

    GoRouter.of(tester.element(find.byType(Navigator).first))
        .push('/edit/refueling/$id');
    await settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await settle(tester);
    await tester.tap(find.text('DELETE'));
    await settle(tester);

    expect(await real(tester, () => db.getRefueling(id)), isNull);
    expect(find.text('Refueling deleted'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('adds a gas station from the picker', (tester) async {
    await real(tester, () => addTestVehicle(db));
    await open(tester, '/add/refueling');

    await tester.tap(find.widgetWithText(PickerField, 'Gas station'));
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Shell');
    await tester.tap(find.text('ADD'));
    await settle(tester);
    await tester.tap(find.text('Shell'));
    await settle(tester);

    expect(find.widgetWithText(PickerField, 'Shell'), findsOneWidget);
    final stations = await real(
      tester,
      () => db.watchCatalog(CatalogKind.gasStation).first,
    );
    expect(stations.single.name, 'Shell');
    await finish(tester);
  });

  testWidgets('without vehicles it asks to add one and blocks saving', (
    tester,
  ) async {
    await open(tester, '/add/refueling');
    expect(find.text('Add a vehicle to save refuelings'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(find.text('Add a vehicle first'), findsOneWidget);
    expect(await real(tester, db.select(db.refuelings).get), isEmpty);
    await finish(tester);
  });

  testWidgets('the + Fuel button is visible without opening more options', (
    tester,
  ) async {
    await real(tester, () => addTestVehicle(db));
    await open(tester, '/add/refueling');

    // "+ Fuel" sits right after the full-tank toggle, not behind
    // "+ More options".
    expect(find.widgetWithText(TextButton, 'Fuel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'More options'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('rejects a discount larger than the total', (tester) async {
    await real(tester, () => addTestVehicle(db));
    await open(tester, '/add/refueling');

    await tester.tap(find.widgetWithText(PickerField, 'Fuel'));
    await settle(tester);
    await tester.tap(find.text('Petrol'));
    await settle(tester);
    await tester.enterText(field('Odometer'), '1000');
    await tester.enterText(field('Price / L'), '300');
    await tester.enterText(field('Liters'), '5');
    await tester.pump();

    // Reveal the discount field, then enter more than the 1500 total.
    await tester.tap(find.widgetWithText(TextButton, 'More options'));
    await settle(tester);
    await tester.enterText(field('Discount'), '2000');
    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(
      find.text("The discount can't be more than the total"),
      findsOneWidget,
    );
    expect(await real(tester, db.select(db.refuelings).get), isEmpty);

    // A discount within range saves fine.
    await tester.enterText(field('Discount'), '100');
    await tester.tap(find.text('SAVE'));
    await settle(tester);
    final saved = await real(tester, db.select(db.refuelings).getSingle);
    expect(saved.discount, 100);
    await finish(tester);
  });

  testWidgets('accepts a comma decimal and rejects a negative odometer', (
    tester,
  ) async {
    await real(tester, () => addTestVehicle(db));
    await open(tester, '/add/refueling');

    await tester.tap(find.widgetWithText(PickerField, 'Fuel'));
    await settle(tester);
    await tester.tap(find.text('Petrol'));
    await settle(tester);
    await tester.enterText(field('Price / L'), '300');
    await tester.enterText(field('Liters'), '5');

    // A negative odometer is rejected, same as leaving it blank.
    await tester.enterText(field('Odometer'), '-5');
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(find.text('Enter the odometer'), findsOneWidget);
    expect(await real(tester, db.select(db.refuelings).get), isEmpty);

    // "," is accepted as the decimal separator.
    await tester.enterText(field('Odometer'), '1000,5');
    await tester.tap(find.text('SAVE'));
    await settle(tester);

    expect(find.text('Refueling saved'), findsOneWidget);
    final saved = await real(tester, db.select(db.refuelings).getSingle);
    expect(saved.odometer, 1000.5);
    await finish(tester);
  });

  testWidgets('the back arrow confirms discarding unsaved changes', (
    tester,
  ) async {
    await real(tester, () => addTestVehicle(db));
    await open(tester, '/add/refueling');

    // Nothing changed yet: the back arrow leaves straight away.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('History'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(Navigator).first))
        .push('/add/refueling');
    await settle(tester);
    await tester.enterText(field('Odometer'), '500');
    await tester.pump();

    // KEEP EDITING stays on the form with the edit intact.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('KEEP EDITING'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(tester.widget<TextField>(field('Odometer')).controller!.text, '500');

    // DISCARD leaves without saving.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(await real(tester, db.select(db.refuelings).get), isEmpty);
    await finish(tester);
  });
}
