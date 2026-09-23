import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';

/// Widget-test helpers for the Route and Reading form tests.

/// Tall test screen so the whole form (and SAVE) is built without scrolling.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder field(String label) => find.widgetWithText(TextField, label);

/// Opens a form from the "+" speed dial (e.g. `'Route'`, `'Reading'`).
Future<void> openForm(WidgetTester tester, String module) async {
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.tap(find.text(module));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('SAVE'));
  await tester.pumpAndSettle();
}

/// Adds a vehicle (plus a reading at [lastOdometer]) using real async —
/// drift schedules timers that flutter_test's fake clock would never fire.
Future<String> seedVehicle(
  WidgetTester tester,
  AppDatabase db, {
  double? lastOdometer,
}) async {
  final id = await tester.runAsync(() async {
    final vid = await addTestVehicle(db);
    if (lastOdometer != null) {
      await db
          .into(db.readings)
          .insert(
            ReadingsCompanion.insert(
              vehicleId: vid,
              date: DateTime(2026, 9, 1),
              odometer: lastOdometer,
            ),
          );
    }
    return vid;
  });
  return id!;
}

/// Unmounts the app so drift's stream-cleanup timers fire before the test
/// ends (otherwise flutter_test reports "A Timer is still pending").
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}
