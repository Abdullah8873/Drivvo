import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';

import 'helpers.dart';

/// Pumps the app on a tall screen (so long lists fit without scrolling) and
/// opens More → [label]. Call [closeApp] at the end of the test.
Future<AppDatabase> openFromMore(WidgetTester tester, String label) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = testDatabase();
  await tester.pumpWidget(testApp(db));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  return db;
}

/// Unmounts the app so drift stream subscriptions are cancelled, lets
/// drift's zero-length "close stream" timer fire (otherwise the test fails
/// with "A Timer is still pending"), then closes the database.
Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
  await tester.runAsync(db.close);
}
