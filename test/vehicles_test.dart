import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // Unmount before the db closes (runs before `tearDown`), so a failing
    // test can't leave live stream queries that hang `db.close()`.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// SAVE sits at the bottom of a lazily built ListView: scroll to it first.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('SAVE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
  }

  Future<List<Vehicle>> allRows() => db.select(db.vehicles).get();

  /// More tab → Vehicles list.
  Future<void> openVehicleList(WidgetTester tester) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
  }

  testWidgets('creating the first vehicle selects it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Add a vehicle'));
    await tester.pumpAndSettle();

    // Name is required.
    await tapSave(tester);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(await allRows(), isEmpty);

    await tester.scrollUntilVisible(
      find.text('Type of vehicle'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motorcycle'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Name'), 'Honda CG');
    await tester.enterText(field('Model'), 'CG125');
    await tester.enterText(field('License plate'), 'LEA-123');
    await tester.tap(find.text('TWO TANKS'));
    await tester.pumpAndSettle();
    expect(find.text('TANK 2'), findsOneWidget);
    await tapSave(tester);

    final rows = await allRows();
    expect(rows, hasLength(1));
    final v = rows.single;
    expect(v.name, 'Honda CG');
    expect(v.type, VehicleType.motorcycle);
    expect(v.model, 'CG125');
    expect(v.plate, 'LEA-123');
    expect(v.tankCount, 2);
    expect(v.tank2Kind, FuelKind.gas);
    expect(v.manufacturer, isNull);
    expect((await loadSettings(db)).selectedVehicleId, v.id);

    // Back on History, the chip shows the new vehicle.
    expect(find.text('Honda CG'), findsOneWidget);
    expect(find.text('CG125'), findsOneWidget);
    expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
  });

  testWidgets('app bar shows model and last odometer', (tester) async {
    final id = await addTestVehicle(db);
    await (db.update(db.vehicles)..where((v) => v.id.equals(id))).write(
      const VehiclesCompanion(model: Value('CG125')),
    );
    await db
        .into(db.readings)
        .insert(
          ReadingsCompanion.insert(
            vehicleId: id,
            date: DateTime(2026, 9, 1),
            odometer: 56935,
          ),
        );
    await pumpApp(tester);

    expect(find.text('Honda'), findsOneWidget);
    expect(find.text('CG125 · 56935 km'), findsOneWidget);
  });

  testWidgets('edits a vehicle from the Vehicles list', (tester) async {
    final id = await addTestVehicle(db);
    await pumpApp(tester);
    await openVehicleList(tester);

    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();
    expect(find.text('Motorcycle'), findsOneWidget);

    await tester.enterText(field('Name'), 'Honda CD70');
    await tester.enterText(field('Year'), '2021');
    await tester.ensureVisible(find.text('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    // Back on the list, which updated by itself.
    expect(find.text('Honda CD70'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    final v = (await allRows()).single;
    expect(v.id, id);
    expect(v.name, 'Honda CD70');
    expect(v.year, 2021);
    expect(v.active, isFalse);
  });

  testWidgets('vehicle picker switches the current vehicle', (tester) async {
    await addTestVehicle(db);
    final yamahaId = await addTestVehicle(db, name: 'Yamaha');
    await pumpApp(tester);

    // No selection yet: the first vehicle (by name) is shown.
    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();
    expect(find.text('Select vehicle'), findsOneWidget);
    expect(find.text('Yamaha'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yam');
    await tester.pump();
    expect(find.text('Honda'), findsNothing);

    await tester.tap(find.text('Yamaha'));
    await tester.pumpAndSettle();
    expect(find.text('Select vehicle'), findsNothing);
    expect(find.text('Yamaha'), findsOneWidget);
    expect((await loadSettings(db)).selectedVehicleId, yamahaId);

    // The picker's + opens the new-vehicle form.
    await tester.tap(find.text('Yamaha'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Type of vehicle'), findsOneWidget);
  });

  testWidgets('delete asks first, then soft-deletes', (tester) async {
    await addTestVehicle(db);
    await pumpApp(tester);
    await openVehicleList(tester);
    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text('"Honda" and its 0 records will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect((await allRows()).single.deletedAt, isNull);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(find.text('No vehicles yet. Tap + to add one.'), findsOneWidget);
    // The row is kept (for sync) but marked deleted.
    expect((await allRows()).single.deletedAt, isNotNull);
  });

  testWidgets('delete counts and cascades to the vehicle\'s records', (
    tester,
  ) async {
    final id = await addTestVehicle(db);
    final refuelingId = (await tester.runAsync(() async {
      final fuel = (await (db.select(
        db.catalogItems,
      )..where((c) => c.kind.equalsValue(CatalogKind.fuel))).get()).first;
      final refueling = await db
          .into(db.refuelings)
          .insertReturning(
            RefuelingsCompanion.insert(
              vehicleId: id,
              date: DateTime(2026, 1, 1),
              odometer: 1000,
              totalCost: 5000,
            ),
          );
      await db
          .into(db.refuelingFuels)
          .insert(
            RefuelingFuelsCompanion.insert(
              refuelingId: refueling.id,
              fuelId: fuel.id,
              pricePerUnit: 250,
              total: 5000,
              volume: 20,
            ),
          );
      await db
          .into(db.readings)
          .insert(
            ReadingsCompanion.insert(
              vehicleId: id,
              date: DateTime(2026, 1, 2),
              odometer: 1050,
            ),
          );
      return refueling.id;
    }))!;

    await pumpApp(tester);
    await openVehicleList(tester);
    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    // One refueling + one reading = 2 records (the fuel line inside the
    // refueling isn't counted on its own — it's a child of it).
    expect(
      find.text('"Honda" and its 2 records will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect((await allRows()).single.deletedAt, isNotNull);
    final fuelLine = await (db.select(
      db.refuelingFuels,
    )..where((r) => r.refuelingId.equals(refuelingId))).getSingle();
    expect(fuelLine.deletedAt, isNotNull);
    final refueling = await (db.select(
      db.refuelings,
    )..where((r) => r.id.equals(refuelingId))).getSingle();
    expect(refueling.deletedAt, isNotNull);
    final reading = await (db.select(
      db.readings,
    )..where((r) => r.vehicleId.equals(id))).getSingle();
    expect(reading.deletedAt, isNotNull);
  });
}
