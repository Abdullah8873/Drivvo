import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/reports/report_period.dart';

void main() {
  // Thursday 24 Sep 2026, mid-morning.
  final now = DateTime(2026, 9, 24, 10, 30);

  ReportRange range(ReportPeriodKind kind) => ReportPeriod(kind).rangeAt(now);

  group('ReportPeriod.rangeAt', () {
    test('current month = the whole calendar month', () {
      expect(
        range(ReportPeriodKind.currentMonth),
        ReportRange(from: DateTime(2026, 9), to: DateTime(2026, 10)),
      );
    });

    test('previous month = the whole previous calendar month', () {
      expect(
        range(ReportPeriodKind.previousMonth),
        ReportRange(from: DateTime(2026, 8), to: DateTime(2026, 9)),
      );
      // January → December of the previous year.
      expect(
        const ReportPeriod(ReportPeriodKind.previousMonth)
            .rangeAt(DateTime(2026, 1, 15)),
        ReportRange(from: DateTime(2025, 12), to: DateTime(2026)),
      );
    });

    test('last month = the last 30 days, today included', () {
      final r = range(ReportPeriodKind.lastMonth);
      expect(
        r,
        ReportRange(from: DateTime(2026, 8, 26), to: DateTime(2026, 9, 25)),
      );
      expect(daysBetween(r.from!, r.to!), 30);
      expect(r.contains(now), isTrue);
      expect(r.contains(DateTime(2026, 8, 25, 23, 59)), isFalse);
    });

    test('last 3 / 6 months and last year end today', () {
      expect(
        range(ReportPeriodKind.last3Months),
        ReportRange(from: DateTime(2026, 6, 25), to: DateTime(2026, 9, 25)),
      );
      expect(
        range(ReportPeriodKind.last6Months),
        ReportRange(from: DateTime(2026, 3, 25), to: DateTime(2026, 9, 25)),
      );
      expect(
        range(ReportPeriodKind.lastYear),
        ReportRange(from: DateTime(2025, 9, 25), to: DateTime(2026, 9, 25)),
      );
    });

    test('month arithmetic clamps short months', () {
      // 31 May − 3 months = 28 Feb (+1 day → 1 Mar).
      expect(
        const ReportPeriod(ReportPeriodKind.last3Months)
            .rangeAt(DateTime(2026, 5, 31))
            .from,
        DateTime(2026, 3, 1),
      );
      expect(addMonths(DateTime(2024, 3, 31), -1), DateTime(2024, 2, 29));
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('all time is unbounded', () {
      final r = range(ReportPeriodKind.allTime);
      expect(r, ReportRange.unbounded);
      expect(r.contains(DateTime(1990)), isTrue);
    });

    test('custom covers both picked days and ignores their order', () {
      final p = ReportPeriod.custom(
        DateTime(2026, 9, 17, 16),
        DateTime(2025, 6, 11, 8),
      );
      expect(p.customFrom, DateTime(2025, 6, 11));
      expect(p.customTo, DateTime(2026, 9, 17));
      final r = p.rangeAt(now);
      expect(
        r,
        ReportRange(from: DateTime(2025, 6, 11), to: DateTime(2026, 9, 18)),
      );
      expect(r.contains(DateTime(2026, 9, 17, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 9, 18)), isFalse);
    });

    test('every kind has a label for the Period list', () {
      expect(ReportPeriodKind.lastMonth.label, 'Last month');
      expect(ReportPeriod.defaultPeriod.label, 'All time');
    });
  });

  group('monthsBetween', () {
    test('lists every month, gaps and year change included', () {
      expect(monthsBetween(DateTime(2025, 11, 20), DateTime(2026, 2, 3)), [
        DateTime(2025, 11),
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
      ]);
      expect(monthsBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 30)), [
        DateTime(2026, 9),
      ]);
    });
  });

  group('reportSpan', () {
    test('all time runs from the first to the last record', () {
      final span = reportSpan(
        ReportRange.unbounded,
        now: now,
        trackingStart: DateTime(2025, 6, 11, 9),
        lastRecord: DateTime(2026, 9, 17, 16),
      );
      expect(span, DateSpan(DateTime(2025, 6, 11), DateTime(2026, 9, 17)));
      expect(span!.days, 464);
    });

    test('current month stops at today', () {
      final span = reportSpan(
        range(ReportPeriodKind.currentMonth),
        now: now,
        trackingStart: DateTime(2024),
        lastRecord: DateTime(2026, 9, 5),
      );
      expect(span, DateSpan(DateTime(2026, 9, 1), DateTime(2026, 9, 24)));
      expect(span!.days, 24);
    });

    test('a past month covers all its days', () {
      final span = reportSpan(
        range(ReportPeriodKind.previousMonth),
        now: now,
        trackingStart: DateTime(2024),
      );
      expect(span!.days, 31);
    });

    test('never starts before the vehicle was tracked', () {
      final span = reportSpan(
        range(ReportPeriodKind.lastYear),
        now: now,
        trackingStart: DateTime(2026, 9, 10, 18),
        lastRecord: DateTime(2026, 9, 20),
      );
      expect(span, DateSpan(DateTime(2026, 9, 10), DateTime(2026, 9, 24)));
      expect(span!.days, 15);
    });

    test('a future-dated record extends the span', () {
      final span = reportSpan(
        range(ReportPeriodKind.currentMonth),
        now: now,
        trackingStart: DateTime(2026, 9, 2),
        lastRecord: DateTime(2026, 9, 28),
      );
      expect(span!.end, DateTime(2026, 9, 28));
    });

    test('null without records or for a range fully in the future', () {
      expect(reportSpan(ReportRange.unbounded, now: now), isNull);
      expect(
        reportSpan(
          ReportPeriod.custom(
            DateTime(2027, 1, 1),
            DateTime(2027, 1, 31),
          ).rangeAt(now),
          now: now,
          trackingStart: DateTime(2025),
        ),
        isNull,
      );
    });

    test('a bounded range without any record still has its days', () {
      final span = reportSpan(range(ReportPeriodKind.lastMonth), now: now);
      expect(span!.days, 30);
    });
  });
}
