import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/reports/report_providers.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  /// "Today" pinned so the "years of tracking" achievement is deterministic.
  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      reportNowProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
    ],
    child: const MotoLogApp(),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows an achievement row on its earned date, month totals unchanged',
    (tester) async {
      final vid = await addTestVehicle(db);
      // First record ever: 2024-03-10 — its 2-year anniversary (2026-03-10,
      // <= the pinned "today") should be earned and land in March 2026.
      await addEntry(
        db,
        vid,
        kind: EntryKind.expense,
        date: DateTime(2024, 3, 10),
        items: {'Registration': 500},
      );
      // A real record in that same month, so there's a month card to check.
      await addRefuel(
        db,
        vid,
        date: DateTime(2026, 3, 15),
        odometer: 100,
        volume: 5,
      ); // 5 x 293.03 = 1465.15

      await pumpApp(tester);

      expect(find.text('MARCH 2026'), findsOneWidget);
      // The achievement row for the 2-year anniversary.
      expect(
        find.text('Completed 2 years of tracking this vehicle.'),
        findsOneWidget,
      );
      // The month card's "Spent" total is exactly the refuel's cost — the
      // achievement event (no `amount`) didn't change it. (It also shows
      // once more on the refuel's own row — that's expected.)
      expect(
        find.descendant(
          of: find.byKey(const Key('month-2026-3')),
          matching: find.text('PKR1,465.15'),
        ),
        findsOneWidget,
      );

      await unmountApp(tester);
    },
  );

  testWidgets(
    'the same anniversary does not appear for a vehicle with no other '
    'records that month',
    (tester) async {
      final vid = await addTestVehicle(db);
      await addEntry(
        db,
        vid,
        kind: EntryKind.expense,
        date: DateTime(2024, 1, 1),
        items: {'Registration': 500},
      );

      await pumpApp(tester);

      // 2025-01-01 (the 1-year anniversary) has no other record that
      // month, so there's no month card to host the achievement row.
      expect(find.text('JANUARY 2025'), findsNothing);
      expect(
        find.text('Completed 1 year of tracking this vehicle.'),
        findsNothing,
      );

      await unmountApp(tester);
    },
  );
}
