import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/catalog/catalog_queries.dart';

import 'catalog_test_utils.dart';
import 'helpers.dart';

Finder dropdownField<T>() => find.byType(DropdownButtonFormField<T>);

Future<AppDatabase> openCatalog(WidgetTester tester, String label) =>
    openFromMore(tester, label);

Future<List<CatalogItem>> allOf(
  WidgetTester tester,
  AppDatabase db,
  CatalogKind kind,
) async => (await tester.runAsync(
  () => (db.select(
    db.catalogItems,
  )..where((c) => c.kind.equalsValue(kind))).get(),
))!;

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('CatalogQueries', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    test('duplicate check ignores case, self and deleted items', () async {
      expect(await db.catalogNameExists(CatalogKind.reason, ' trip '), isTrue);
      expect(await db.catalogNameExists(CatalogKind.fuel, 'trip'), isFalse);

      final item = await db.addCatalogItem(
        kind: CatalogKind.reason,
        name: 'Holiday',
      );
      expect(
        await db.catalogNameExists(
          CatalogKind.reason,
          'holiday',
          exceptId: item.id,
        ),
        isFalse,
      );
      await db.softDeleteCatalogItem(item.id);
      expect(
        await db.catalogNameExists(CatalogKind.reason, 'Holiday'),
        isFalse,
      );
    });

    test('update trims the name and bumps updatedAt', () async {
      final old = DateTime(2020);
      final item = await db
          .into(db.catalogItems)
          .insertReturning(
            CatalogItemsCompanion.insert(
              kind: CatalogKind.place,
              name: 'Home',
              address: const Value('Old street'),
              createdAt: Value(old),
              updatedAt: Value(old),
            ),
          );
      await db.updateCatalogItem(item.id, name: '  House ');
      final row = await (db.select(
        db.catalogItems,
      )..where((c) => c.id.equals(item.id))).getSingle();
      expect(row.name, 'House');
      expect(row.address, 'Old street'); // absent = untouched
      expect(row.updatedAt.isAfter(old), isTrue);
    });

    test('counts only non-deleted refueling-fuel lines using a fuel', () async {
      final fuel = await db.addCatalogItem(
        kind: CatalogKind.fuel,
        name: 'Petrol',
      );
      expect(await db.countRefuelingsUsingFuel(fuel.id), 0);

      final vehicleId = await addTestVehicle(db);
      Future<RefuelingFuel> addLine() async {
        final refueling = await db
            .into(db.refuelings)
            .insertReturning(
              RefuelingsCompanion.insert(
                vehicleId: vehicleId,
                date: DateTime(2026, 1, 1),
                odometer: 1000,
                totalCost: 5000,
              ),
            );
        return db
            .into(db.refuelingFuels)
            .insertReturning(
              RefuelingFuelsCompanion.insert(
                refuelingId: refueling.id,
                fuelId: fuel.id,
                pricePerUnit: 250,
                total: 5000,
                volume: 20,
              ),
            );
      }

      await addLine();
      final second = await addLine();
      expect(await db.countRefuelingsUsingFuel(fuel.id), 2);

      // A soft-deleted line no longer counts.
      await (db.update(db.refuelingFuels)..where((r) => r.id.equals(second.id)))
          .write(RefuelingFuelsCompanion(deletedAt: Value(DateTime.now())));
      expect(await db.countRefuelingsUsingFuel(fuel.id), 1);
    });
  });

  testWidgets('add, rename and delete a reason', (tester) async {
    final db = await openCatalog(tester, 'Reasons');
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    // Add.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Holiday');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday'), findsOneWidget);

    // Edit.
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Office');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Work'), findsNothing);

    // Delete from the edit form.
    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('Office'), findsNothing);
    expect(find.text('Reasons'), findsOneWidget); // back on the list

    final rows = await allOf(tester, db, CatalogKind.reason);
    final office = rows.singleWhere((r) => r.name == 'Office');
    expect(office.deletedAt, isNotNull); // soft delete keeps the row
    expect(rows.map((r) => r.name), contains('Holiday'));
    await closeApp(tester, db);
  });

  testWidgets('rejects empty and duplicate names', (tester) async {
    final db = await openCatalog(tester, 'Payment methods');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(field('Name'), 'credit CARD');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('"credit CARD" already exists'), findsOneWidget);

    expect(await allOf(tester, db, CatalogKind.paymentMethod), hasLength(4));
    await closeApp(tester, db);
  });

  testWidgets('gas station stores an address', (tester) async {
    final db = await openCatalog(tester, 'Gas stations');
    expect(find.textContaining('Nothing here yet'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Shell Blue Area');
    await tester.enterText(field('Address'), 'Jinnah Ave, Islamabad');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Shell Blue Area'), findsOneWidget);
    expect(find.text('Jinnah Ave, Islamabad'), findsOneWidget);
    final rows = await allOf(tester, db, CatalogKind.gasStation);
    expect(rows.single.address, 'Jinnah Ave, Islamabad');
    await closeApp(tester, db);
  });

  testWidgets('fuel stores its tank kind; long-press deletes', (tester) async {
    final db = await openCatalog(tester, 'Fuel');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(field('Name'), 'Hydrogen');
    await tester.tap(find.text('Liquids'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    var rows = await allOf(tester, db, CatalogKind.fuel);
    expect(
      rows.singleWhere((r) => r.name == 'Hydrogen').fuelKind,
      FuelKind.gas,
    );

    await tester.longPress(find.text('Hydrogen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('Hydrogen'), findsNothing);
    rows = await allOf(tester, db, CatalogKind.fuel);
    expect(rows.singleWhere((r) => r.name == 'Hydrogen').deletedAt, isNotNull);
    await closeApp(tester, db);
  });

  testWidgets('locks "Type of fuel" once the fuel is used in a refueling', (
    tester,
  ) async {
    final db = await openCatalog(tester, 'Fuel');
    final fuel = (await allOf(
      tester,
      db,
      CatalogKind.fuel,
    )).firstWhere((f) => f.name == 'Petrol');

    await tester.runAsync(() async {
      final vehicleId = await addTestVehicle(db);
      final refueling = await db
          .into(db.refuelings)
          .insertReturning(
            RefuelingsCompanion.insert(
              vehicleId: vehicleId,
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
    });

    await tester.tap(find.text('Petrol'));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't change: this fuel is used in 1 refuelings"),
      findsOneWidget,
    );
    final dropdown = tester.widget<DropdownButtonFormField<FuelKind>>(
      dropdownField<FuelKind>(),
    );
    expect(dropdown.onChanged, isNull);
    await closeApp(tester, db);
  });
}
