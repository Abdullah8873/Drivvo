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

  /// The app with "today" pinned so period filters are deterministic.
  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      reportNowProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12)),
    ],
    child: const MotoLogApp(),
  );

  Future<void> openReports(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final vid = await addTestVehicle(db);
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 8, 10, 9),
      odometer: 1000,
      volume: 5,
    ); // 1465.15
    await addEntry(
      db,
      vid,
      kind: EntryKind.service,
      date: DateTime(2026, 8, 20, 12),
      odometer: 1100,
      items: {'Oil Change': 1200, 'Oil Filter': 300},
    );
    await addRefuel(
      db,
      vid,
      date: DateTime(2026, 9, 5, 8),
      odometer: 1200,
      volume: 5,
    ); // 1465.15
    await addEntry(
      db,
      vid,
      kind: EntryKind.income,
      date: DateTime(2026, 9, 10, 18),
      odometer: 1250,
      items: {'Ride': 5000},
    );
  });

  String statText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .join(' | ');

  testWidgets('no vehicle: offers to add one', (tester) async {
    await openReports(tester);
    expect(find.text('No vehicle yet'), findsOneWidget);
    expect(find.text('Add your first vehicle'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('General tab shows the all-time figures and charts', (
    tester,
  ) async {
    await seed(tester);
    await openReports(tester);

    // Period card: all records, first → last record day.
    expect(find.text('4 entries (2026-08-10 - 2026-09-10)'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);

    // Cost 4430.30 over 32 days and 250 km; income 5000.
    final cost = statText(tester, 'stat-cost');
    expect(cost, contains('PKR4,430.30'));
    expect(cost, contains('PKR138.45')); // by day
    expect(cost, contains('PKR17.721/km')); // by km
    expect(statText(tester, 'stat-income'), contains('PKR5,000.00'));
    expect(statText(tester, 'stat-balance'), contains('PKR569.70'));
    final distance = statText(tester, 'stat-distance');
    expect(distance, contains('250 km'));
    expect(distance, contains('7.8 km'));

    expect(find.text('Expenses and income chart'), findsOneWidget);
    expect(find.text('Cost comparison chart'), findsOneWidget);
    expect(find.text('Service - PKR1,500.00'), findsOneWidget);
    expect(find.text('Refueling - PKR2,930.30'), findsOneWidget);
    expect(find.text('Odometer chart'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('filter: an empty period shows the empty state, clear resets', (
    tester,
  ) async {
    await seed(tester);
    await openReports(tester);

    await tester.tap(find.byKey(const Key('report-period-card')));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-period-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Current month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY FILTER'));
    await tester.pumpAndSettle();

    // October 2026 has no records (today is pinned to 15 Oct).
    expect(find.text('No records in this period'), findsOneWidget);
    expect(find.text('0 entries (2026-10-01 - 2026-10-15)'), findsOneWidget);

    // Previous month = September: the refuel and the income.
    await tester.tap(find.byKey(const Key('report-period-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-period-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY FILTER'));
    await tester.pumpAndSettle();
    expect(find.text('2 entries (2026-09-01 - 2026-09-30)'), findsOneWidget);
    expect(statText(tester, 'stat-cost'), contains('PKR1,465.15'));

    // CLEAR FILTERS goes back to all time.
    await tester.tap(find.byKey(const Key('report-period-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLEAR FILTERS'));
    await tester.pumpAndSettle();
    expect(find.text('4 entries (2026-08-10 - 2026-09-10)'), findsOneWidget);
    await unmountApp(tester);
  });
}
