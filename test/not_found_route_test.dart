import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/router/app_router.dart';

import 'helpers.dart';

/// A URL that matches no route shows a themed "Page not found" screen with
/// a way back, not go_router's bare debug page (found in web QA).
void main() {
  late AppDatabase db;

  setUp(() {
    db = testDatabase();
  });

  tearDown(() => db.close());

  testWidgets('unknown location shows Page not found and goes home', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MotoLogApp(),
      ),
    );
    await tester.pumpAndSettle();

    activeRouter!.go('/no/such/page');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('GO TO HISTORY'));
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsNothing);
    expect(activeRouter!.state.uri.path, '/history');
  });
}
