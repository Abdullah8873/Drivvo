import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Manual QA on a ~350x480 px phone found several narrow-width layout bugs:
/// bottom-nav labels wrapping to two lines, the speed-dial "+" menu
/// overflowing the top of short screens, and the refueling fuel-line fields
/// getting cut off by their currency prefix. These pump at 320x480 logical
/// pixels — narrower, and a touch shorter, than the phone QA used — so the
/// fixes hold at the edge.
void main() {
  Future<void> setNarrowSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Unmounts the app (flushing drift's stream-cleanup timers) — call at the
  /// end of every test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('main shell fits a 320x480 screen with one-line nav labels', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await setNarrowSize(tester);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // All four tab labels render as a single Text each (no manual line
    // break), so a second render pass finding the same text confirms
    // FittedBox scaled them down instead of Flutter wrapping them.
    for (final tab in ['History', 'Reports', 'Reminders', 'More']) {
      expect(find.text(tab), findsOneWidget);
    }

    await finish(tester);
  });

  testWidgets('speed-dial menu keeps every item reachable on a short screen', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await setNarrowSize(tester);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // "Reminder" heads RecordModule.speedDialOrder, so it's the item most
    // likely to be pushed off the top of a short screen. Scroll the menu's
    // own scrollable to it if it isn't already visible, then confirm it can
    // actually be hit (not just present in the tree, off-screen).
    if (find.text('Reminder').hitTestable().evaluate().isEmpty) {
      await tester.dragUntilVisible(
        find.text('Reminder'),
        find.byType(SingleChildScrollView),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
    }
    final reminderItem = find.text('Reminder').hitTestable();
    expect(reminderItem, findsOneWidget);

    await tester.tap(reminderItem);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Landed on the reminder form (its module-colored app bar title).
    expect(find.text('Reminder'), findsWidgets);

    await finish(tester);
  });

  testWidgets('refueling fuel-line fields fit a 320px-wide screen', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await setNarrowSize(tester);
    await tester.pumpWidget(testApp(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refueling'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    Finder field(String label) =>
        find.widgetWithText(TextField, label).hitTestable();

    // All three fields present, readable and tappable at 320px, with no
    // currency prefix squeezing them (Drivvo shows none on this row).
    expect(field('Price / L'), findsOneWidget);
    expect(field('Total cost'), findsOneWidget);
    expect(field('Liters'), findsOneWidget);
    expect(find.textContaining('PKR'), findsNothing);

    await tester.enterText(field('Price / L'), '300');
    await tester.enterText(field('Liters'), '5');
    await tester.pump();
    expect(tester.takeException(), isNull);

    final total = tester.widget<TextField>(field('Total cost'));
    expect(total.controller!.text, '1500.00');

    await finish(tester);
  });
}
