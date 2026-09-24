import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/reports/module_reports.dart';
import 'package:motolog/features/reports/report_period.dart';
import 'package:motolog/features/reports/report_providers.dart';
import 'package:motolog/features/routes/route_math.dart';

import 'helpers.dart';
import 'history_fixtures.dart';

var _id = 0;

/// An expense/service/income TimelineRecord with typed lines; [items] drive
/// both `amount` (their sum) and the type breakdown.
TimelineRecord entryRec(
  RecordModule module,
  DateTime date, {
  List<ItemLine> items = const [],
}) {
  final amount = items.fold(0.0, (s, i) => s + i.amount);
  return TimelineRecord(
    module: module,
    id: '${_id++}',
    vehicleId: 'v',
    date: date,
    amount: amount,
    items: items,
  );
}

/// A minimal drift `Route` row for [routeRec].
Route route({
  required DateTime start,
  required double startOdo,
  DateTime? end,
  double? endOdo,
  double? value,
}) => Route(
  id: '${_id++}',
  createdAt: start,
  updatedAt: start,
  vehicleId: 'v',
  mode: RouteMode.trip,
  startDate: start,
  startOdometer: startOdo,
  endDate: end,
  endOdometer: endOdo,
  total: value,
  installments: 1,
);

TimelineRecord routeRec(Route r) => TimelineRecord(
  module: RecordModule.route,
  id: '${_id++}',
  vehicleId: 'v',
  date: r.startDate,
  amount: r.total ?? 0,
  odometer: r.endOdometer ?? r.startOdometer,
  route: r,
);

/// A reading TimelineRecord (only `date`/`odometer` matter to the reading
/// report — it never touches the raw `reading` field).
TimelineRecord readingRec(DateTime date, double odometer) => TimelineRecord(
  module: RecordModule.reading,
  id: '${_id++}',
  vehicleId: 'v',
  date: date,
  amount: 0,
  odometer: odometer,
);

void main() {
  group('typeBreakdown', () {
    test('keeps the top N and folds the rest into "Others"', () {
      final result = typeBreakdown([
        const TypeAmount(name: 'A', amount: 500),
        const TypeAmount(name: 'B', amount: 400),
        const TypeAmount(name: 'C', amount: 300),
        const TypeAmount(name: 'D', amount: 200),
        const TypeAmount(name: 'E', amount: 100),
        const TypeAmount(name: 'F', amount: 50),
      ]);
      expect(result.map((s) => s.name), ['A', 'B', 'C', 'D', 'Others']);
      expect(result.map((s) => s.amount), [500, 400, 300, 200, 150]);
      // Each of the top 4 gets a distinct palette color; Others is grey.
      expect(result.take(4).map((s) => s.color).toSet().length, 4);
      expect(result.last.color, isNot(result.first.color));
    });

    test('same name accumulates before ranking', () {
      final result = typeBreakdown([
        const TypeAmount(name: 'Oil Change', amount: 800),
        const TypeAmount(name: 'Oil Change', amount: 400),
      ]);
      expect(result, [
        (name: 'Oil Change', amount: 1200, color: typePalette[0]),
      ]);
    });

    test('no "Others" slice when there are ≤ N types', () {
      final result = typeBreakdown([
        const TypeAmount(name: 'A', amount: 10),
        const TypeAmount(name: 'B', amount: 20),
      ]);
      expect(result.map((s) => s.name), ['B', 'A']);
    });

    test('zero and negative totals are dropped', () {
      final result = typeBreakdown([
        const TypeAmount(name: 'A', amount: 100),
        const TypeAmount(name: 'Z', amount: 0),
        const TypeAmount(name: 'Y', amount: -50),
      ]);
      expect(result.map((s) => s.name), ['A']);
    });
  });

  group('buildModuleMoneyReport', () {
    test('each installment counts in its own month', () {
      final records = [
        entryRec(
          RecordModule.expense,
          DateTime(2026, 1, 10),
          items: [const ItemLine(name: 'Financing', amount: 1000)],
        ),
        entryRec(
          RecordModule.expense,
          DateTime(2026, 2, 10),
          items: [const ItemLine(name: 'Financing', amount: 1000)],
        ),
        entryRec(
          RecordModule.expense,
          DateTime(2026, 3, 10),
          items: [const ItemLine(name: 'Financing', amount: 1000)],
        ),
      ];
      final r = buildModuleMoneyReport(
        records: records,
        timeline: records,
        range: ReportRange.unbounded,
        days: 90,
      );
      expect(r.total, 3000);
      expect(r.monthly, {
        DateTime(2026, 1): 1000,
        DateTime(2026, 2): 1000,
        DateTime(2026, 3): 1000,
      });
      expect(r.typeBreakdown, [
        (name: 'Financing', amount: 3000, color: typePalette[0]),
      ]);
    });

    test('by-day / by-km guard against zero days and zero distance', () {
      final records = [
        entryRec(
          RecordModule.expense,
          DateTime(2026, 9, 1),
          items: [const ItemLine(name: 'Fine', amount: 300)],
        ),
      ];
      final r = buildModuleMoneyReport(
        records: records,
        timeline: records, // no odometer anywhere → distance 0
        range: ReportRange.unbounded,
        days: 0,
      );
      expect(r.total, 300);
      expect(r.perDay, isNull);
      expect(r.perDistance, isNull);
    });

    test('by-day / by-km compute once days and distance are known', () {
      final timeline = [
        entryRec(
          RecordModule.expense,
          DateTime(2026, 9, 1),
          items: [const ItemLine(name: 'Fine', amount: 300)],
        ),
      ];
      final r = buildModuleMoneyReport(
        records: timeline,
        // periodDistance needs two odometer points to find a real span.
        timeline: [
          ...timeline,
          readingRec(DateTime(2026, 8, 20), 0),
          readingRec(DateTime(2026, 9, 5), 100),
        ],
        range: ReportRange.unbounded,
        days: 10,
      );
      expect(r.perDay, 30);
      expect(r.perDistance, 3);
    });

    test('a record with no typed lines falls back to its title', () {
      final records = [entryRec(RecordModule.income, DateTime(2026, 5, 1))];
      // No items and no `entry` row → title falls back to the module label,
      // and with amount 0 no line is added at all (nothing to chart).
      final r = buildModuleMoneyReport(
        records: records,
        timeline: records,
        range: ReportRange.unbounded,
        days: 1,
      );
      expect(r.typeBreakdown, isEmpty);
    });
  });

  group('buildRouteReport', () {
    test('open routes count toward value but not distance/time', () {
      final finished = route(
        start: DateTime(2026, 1, 5, 8),
        startOdo: 1000,
        end: DateTime(2026, 1, 5, 9, 20),
        endOdo: 1100,
        value: 500,
      );
      final open = route(
        start: DateTime(2026, 2, 1),
        startOdo: 1200,
        value: 200,
      );
      final records = [routeRec(finished), routeRec(open)];

      final r = buildRouteReport(records: records, days: 60);
      expect(r.totals.count, 2);
      expect(r.totals.finishedCount, 1);
      expect(r.totals.value, 700);
      expect(r.totals.distance, 100);
      expect(r.totals.minutes, 80);
      expect(r.valuePerDay, closeTo(700 / 60, 1e-9));
      expect(r.averageMinutes, 80);
      // Distance formats to the route's actual duration, matching RouteMath.
      expect(RouteMath.formatDuration(r.totals.minutes), '1h 20min');
      // Only the finished route's month gets a distance bar.
      expect(r.monthlyDistance, {DateTime(2026, 1): 100});
    });

    test('no finished routes → no average duration', () {
      final open = route(start: DateTime(2026, 3, 1), startOdo: 500);
      final r = buildRouteReport(records: [routeRec(open)], days: 30);
      expect(r.averageMinutes, isNull);
      expect(r.monthlyDistance, isEmpty);
    });
  });

  group('buildReadingReport', () {
    test('monthly distance is attributed to the later reading, backwards '
        'jumps are dropped', () {
      final records = [
        readingRec(DateTime(2026, 1, 1), 1000),
        readingRec(DateTime(2026, 1, 20), 1200), // +200 → January
        readingRec(DateTime(2026, 2, 5), 1150), // odometer went down → skip
        readingRec(DateTime(2026, 3, 1), 1400), // +250 → March
      ];
      final r = buildReadingReport(records: records);
      expect(r.stats.count, 4);
      expect(r.monthlyDistance, {
        DateTime(2026, 1): 200,
        DateTime(2026, 3): 250,
      });
    });

    test('fewer than 2 readings give no chart and no averages', () {
      final r = buildReadingReport(
        records: [readingRec(DateTime(2026, 1, 1), 1000)],
      );
      expect(r.stats.count, 1);
      expect(r.stats.dailyAverage, isNull);
      expect(r.stats.averageDaysBetween, isNull);
      expect(r.monthlyDistance, isEmpty);

      final empty = buildReadingReport(records: const []);
      expect(empty.stats.count, 0);
      expect(empty.monthlyDistance, isEmpty);
    });
  });

  group('SERVICE report tab (widget)', () {
    late AppDatabase db;
    setUp(() => db = testDatabase());
    tearDown(() => db.close());

    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        reportNowProvider.overrideWithValue(() => DateTime(2026, 10, 15, 12)),
      ],
      child: const MotoLogApp(),
    );

    String statText(WidgetTester tester, String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join(' | ');

    testWidgets('shows the total for seeded service records', (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final vid = await addTestVehicle(db);
        await addEntry(
          db,
          vid,
          kind: EntryKind.service,
          date: DateTime(2026, 9, 20, 12),
          items: {'Oil Change': 1200, 'Oil Filter': 300},
        );
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SERVICE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SERVICE'));
      await tester.pumpAndSettle();

      expect(statText(tester, 'stat-cost-service'), contains('PKR1,500.00'));
      expect(find.text('Monthly services chart'), findsOneWidget);
      expect(find.text('Services chart'), findsOneWidget);

      await unmountApp(tester);
    });
  });
}
