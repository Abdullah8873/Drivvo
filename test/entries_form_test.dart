import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/widgets/module_form_scaffold.dart';

import 'helpers.dart';

void main() {
  /// Widget tests run on a fake clock, but drift answers queries after a
  /// real async gap. Let a little real time pass, then pump, until [until]
  /// holds (or a few rounds have passed).
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      if (until == null ? i >= 2 : until.evaluate().isNotEmpty) return;
    }
  }

  /// Unmounts the app so drift's stream-closing timers fire before the
  /// test ends (otherwise: "A Timer is still pending").
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  /// Opens the app and taps "+" → [module] in the speed dial.
  Future<void> openForm(
    WidgetTester tester,
    AppDatabase db,
    String module,
  ) async {
    await tester.pumpWidget(testApp(db));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(module));
    await settle(tester);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  /// Opens the type picker, ticks each item (via the search box), confirms
  /// with ✓, then answers the price dialog shown for each new type.
  Future<void> pickTypes(
    WidgetTester tester,
    String fieldLabel,
    Map<String, String> prices,
  ) async {
    final items = prices.keys;
    await tester.tap(find.widgetWithText(PickerField, fieldLabel));
    final search = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(TextField),
    );
    await settle(tester, until: search);
    for (final item in items) {
      await tester.enterText(search, item);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, item));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final priceField = find.byKey(const Key('price-dialog-field'));
    while (priceField.evaluate().isNotEmpty) {
      final title = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            )
            .first,
      );
      await tester.enterText(priceField, prices[title.data]!);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> save(WidgetTester tester, String savedMessage) async {
    await tester.dragUntilVisible(
      find.text('SAVE'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('SAVE'));
    await settle(tester, until: find.text(savedMessage));
  }

  Future<List<Entry>> liveEntries(WidgetTester tester, AppDatabase db) async {
    final rows = await tester.runAsync(
      () =>
          (db.select(db.entries)
                ..where((e) => e.deletedAt.isNull())
                ..orderBy([(e) => OrderingTerm.asc(e.installmentNo)]))
              .get(),
    );
    return rows!;
  }

  Future<List<EntryItem>> liveItems(WidgetTester tester, AppDatabase db) async {
    final rows = await tester.runAsync(
      () =>
          (db.select(db.entryItems)..where((i) => i.deletedAt.isNull())).get(),
    );
    return rows!;
  }

  testWidgets('without a vehicle the form asks to add one', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await openForm(tester, db, 'Expense');
    expect(find.text('ADD VEHICLE'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saves a service with two types', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => addTestVehicle(db));
    await openForm(tester, db, 'Service');

    await tester.enterText(field('Odometer (km)'), '56403');
    await pickTypes(tester, 'Type of service', {
      'Oil Change': '1200',
      'Air Filter': '800',
    });
    expect(find.text('PKR1,200.00'), findsOneWidget);
    await tester.pump();
    expect(find.text('PKR2,000.00'), findsOneWidget);
    // Services have no Reason field.
    expect(find.text('Reason'), findsNothing);

    await save(tester, 'Service saved');
    expect(find.text('Service saved'), findsOneWidget);

    final rows = await liveEntries(tester, db);
    expect(rows, hasLength(1));
    expect(rows.single.kind, EntryKind.service);
    expect(rows.single.totalCost, 2000);
    expect(rows.single.odometer, 56403);
    final items = await liveItems(tester, db);
    expect(items.map((i) => i.amount), unorderedEquals([1200, 800]));
    await unmount(tester);
  });

  testWidgets('saves an expense split into 3 monthly installments', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.runAsync(() => addTestVehicle(db));
    await openForm(tester, db, 'Expense');

    await pickTypes(tester, 'Type of expense', {'Tax': '1000'});

    expect(find.text('Monthly'), findsNothing);
    await tester.enterText(field('Installments'), '3');
    await tester.pump();
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('3 × PKR333.34'), findsOneWidget);

    await save(tester, 'Expense saved');

    final rows = await liveEntries(tester, db);
    expect(rows, hasLength(3));
    expect(rows.map((r) => r.totalCost), [333.34, 333.33, 333.33]);
    expect(rows.first.parentId, isNull);
    expect(rows.skip(1).map((r) => r.parentId), [rows.first.id, rows.first.id]);
    expect(rows.map((r) => r.installmentNo), [1, 2, 3]);
    expect(rows.map((r) => r.installmentCount), [3, 3, 3]);
    expect(rows[1].date.month, rows.first.date.month % 12 + 1);
    expect(await liveItems(tester, db), hasLength(3));
    await unmount(tester);
  });
}
