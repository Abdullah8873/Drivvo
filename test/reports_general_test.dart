import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/history/history_queries.dart';
import 'package:motolog/features/reports/general_report.dart';
import 'package:motolog/features/reports/report_period.dart';

var _id = 0;

TimelineRecord rec(
  RecordModule module,
  DateTime date,
  double amount, {
  double? odometer,
}) => TimelineRecord(
  module: module,
  id: '${_id++}',
  vehicleId: 'v',
  date: date,
  amount: amount,
  odometer: odometer,
);

void main() {
  // Newest first, like the History timeline.
  final timeline = [
    rec(RecordModule.reading, DateTime(2026, 9, 20), 0, odometer: 1400),
    rec(RecordModule.income, DateTime(2026, 9, 15), 5000, odometer: 1350),
    rec(RecordModule.route, DateTime(2026, 9, 12), 800, odometer: 1300),
    rec(RecordModule.refueling, DateTime(2026, 9, 5), 1500, odometer: 1200),
    rec(RecordModule.service, DateTime(2026, 8, 20), 2000, odometer: 1100),
    rec(RecordModule.expense, DateTime(2026, 8, 15), 500),
    rec(RecordModule.refueling, DateTime(2026, 8, 10), 1000, odometer: 1000),
    rec(RecordModule.refueling, DateTime(2026, 6, 1), 900, odometer: 600),
  ];

  group('buildGeneralReport', () {
    test('all time: totals, balance and per-day / per-distance', () {
      final r = buildGeneralReport(
        timeline: timeline,
        range: ReportRange.unbounded,
        days: 100,
      );
      expect(r.entryCount, 8);
      expect(r.cost, 1500 + 2000 + 500 + 1000 + 900);
      // Income entries only — route values stay on the Route tab, so
      // General agrees with the Income tab.
      expect(r.income, 5000);
      // Balance = cost − income (positive = spent more than earned).
      expect(r.balance, 5900 - 5000);
      expect(r.distance, 1400 - 600);
      expect(r.costPerDay, 59);
      expect(r.costPerDistance, closeTo(5900 / 800, 1e-9));
      expect(r.incomePerDay, 50);
      expect(r.balancePerDay, 9);
      expect(r.balancePerDistance, closeTo(900 / 800, 1e-9));
      expect(r.dailyDistance, 8);
    });

    test('cost split, monthly series and odometer points', () {
      final r = buildGeneralReport(
        timeline: timeline,
        range: ReportRange.unbounded,
        days: 100,
      );
      expect(r.costByModule, {
        RecordModule.refueling: 3400,
        RecordModule.expense: 500,
        RecordModule.service: 2000,
      });
      // June → September with the empty July kept on the axis.
      expect(r.months, [
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
      ]);
      expect(r.monthly[RecordModule.refueling], {
        DateTime(2026, 6): 900,
        DateTime(2026, 8): 1000,
        DateTime(2026, 9): 1500,
      });
      // Route values aren't income on the General tab (see above).
      expect(r.monthly[RecordModule.income], {DateTime(2026, 9): 5000});
      expect(r.monthly.containsKey(RecordModule.route), isFalse);
      expect(r.monthly.containsKey(RecordModule.reading), isFalse);
      // Oldest first; the expense without an odometer is skipped.
      expect(r.odometerPoints.map((p) => p.odometer), [
        600,
        1000,
        1100,
        1200,
        1300,
        1350,
        1400,
      ]);
      expect(r.odometerPoints.first.module, RecordModule.refueling);
      expect(r.odometerPoints.last.module, RecordModule.reading);
    });

    test('a period only counts its records; distance starts from the '
        'odometer before it', () {
      final r = buildGeneralReport(
        timeline: timeline,
        range: ReportRange(from: DateTime(2026, 9), to: DateTime(2026, 10)),
        days: 24,
      );
      expect(r.entryCount, 4);
      expect(r.cost, 1500);
      expect(r.income, 5000);
      expect(r.balance, 1500 - 5000);
      // Highest in September (1400) − highest before it (1100).
      expect(r.distance, 300);
      expect(r.costPerDay, 62.5);
      expect(r.costPerDistance, 5);
      expect(r.costByModule, {RecordModule.refueling: 1500});
      expect(r.months, [DateTime(2026, 9)]);
    });

    test('balance is cost − income, like Drivvo (cost 2,700, no income → '
        '2,700)', () {
      final r = buildGeneralReport(
        timeline: [
          rec(RecordModule.refueling, DateTime(2026, 9, 1), 2000, odometer: 0),
          rec(RecordModule.expense, DateTime(2026, 9, 2), 700, odometer: 100),
          // A route value is not income here.
          rec(RecordModule.route, DateTime(2026, 9, 3), 400, odometer: 150),
        ],
        range: ReportRange.unbounded,
        days: 3,
      );
      expect(r.income, 0);
      expect(r.balance, 2700);
      expect(r.balancePerDay, 900);
      expect(r.balancePerDistance, 18);
    });

    test('zero days / zero distance give no averages', () {
      final single = [
        rec(RecordModule.expense, DateTime(2026, 9, 1), 300, odometer: 50),
      ];
      final r = buildGeneralReport(
        timeline: single,
        range: ReportRange.unbounded,
        days: 0,
      );
      expect(r.cost, 300);
      expect(r.distance, 0);
      expect(r.costPerDay, isNull);
      expect(r.costPerDistance, isNull);
      expect(r.balancePerDay, isNull);
      expect(r.dailyDistance, isNull);
    });

    test('empty period', () {
      final r = buildGeneralReport(
        timeline: timeline,
        range: ReportRange(from: DateTime(2027), to: DateTime(2028)),
        days: 0,
      );
      expect(r.entryCount, 0);
      expect(r.cost, 0);
      expect(r.income, 0);
      expect(r.balance, 0);
      expect(r.costByModule, isEmpty);
      expect(r.months, isEmpty);
      expect(r.odometerPoints, isEmpty);
      expect(r.distance, 0);
    });
  });

  group('periodDistance', () {
    test('first period falls back to its own max − min', () {
      expect(
        periodDistance(
          timeline,
          ReportRange(from: DateTime(2026, 6), to: DateTime(2026, 9)),
        ),
        1100 - 600,
      );
    });

    test('a single record after earlier ones still has a distance', () {
      expect(
        periodDistance(
          timeline,
          ReportRange(from: DateTime(2026, 9, 20), to: DateTime(2026, 9, 21)),
        ),
        1400 - 1350,
      );
    });

    test('no odometer in the period → 0', () {
      expect(
        periodDistance(
          timeline,
          ReportRange(from: DateTime(2026, 8, 15), to: DateTime(2026, 8, 16)),
        ),
        0,
      );
    });
  });
}
