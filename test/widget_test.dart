import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('shell shows the four tabs and opens the + menu', (tester) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();

    for (final tab in ['History', 'Reports', 'Reminders', 'More']) {
      expect(find.text(tab), findsOneWidget);
    }

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Refueling'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);

    await tester.tap(find.text('Refueling'));
    await tester.pumpAndSettle();
    expect(find.text('Are you filling up the tank?'), findsOneWidget);
  });

  testWidgets('refueling form computes total from price and liters', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refueling'));
    await tester.pumpAndSettle();

    Finder field(String label) =>
        find.widgetWithText(TextField, label).hitTestable();

    await tester.enterText(field('Price / L'), '293.03');
    await tester.enterText(field('Liters'), '5.017');
    await tester.pump();

    final total = tester.widget<TextField>(field('Total cost'));
    expect(total.controller!.text, '1470.13');
  });
}
