import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/reminder_math.dart';
import 'package:motolog/core/db/tables.dart' show PeriodUnit;

OdometerPoint pt(DateTime date, double odometer) =>
    (date: date, odometer: odometer);

void main() {
  group('dates', () {
    test('daysBetween counts calendar days', () {
      expect(
        ReminderMath.daysBetween(
          DateTime(2026, 9, 23, 23, 59),
          DateTime(2026, 9, 24, 0, 1),
        ),
        1,
      );
      expect(
        ReminderMath.daysBetween(DateTime(2026, 9, 23), DateTime(2026, 9, 20)),
        -3,
      );
    });

    test('addPeriod adds days, months and years (clamped)', () {
      final d = DateTime(2026, 1, 31);
      expect(
        ReminderMath.addPeriod(d, 10, PeriodUnit.day),
        DateTime(2026, 2, 10),
      );
      expect(
        ReminderMath.addPeriod(d, 1, PeriodUnit.month),
        DateTime(2026, 2, 28),
      );
      expect(
        ReminderMath.addPeriod(d, 13, PeriodUnit.month),
        DateTime(2027, 2, 28),
      );
      expect(
        ReminderMath.addPeriod(DateTime(2024, 2, 29), 1, PeriodUnit.year),
        DateTime(2025, 2, 28),
      );
      expect(
        ReminderMath.addPeriod(DateTime(2026, 3, 15), 2, PeriodUnit.year),
        DateTime(2028, 3, 15),
      );
    });
  });

  group('averageDistancePerDay', () {
    test('needs two points on different days', () {
      expect(ReminderMath.averageDistancePerDay([]), isNull);
      expect(
        ReminderMath.averageDistancePerDay([pt(DateTime(2026, 9, 1), 100)]),
        isNull,
      );
      expect(
        ReminderMath.averageDistancePerDay([
          pt(DateTime(2026, 9, 1, 8), 100),
          pt(DateTime(2026, 9, 1, 18), 150),
        ]),
        isNull,
      );
    });

    test('distance over days, order independent', () {
      final avg = ReminderMath.averageDistancePerDay([
        pt(DateTime(2026, 9, 11), 1500),
        pt(DateTime(2026, 9, 1), 1000),
      ]);
      expect(avg, 50);
    });

    test('uses only the last 90 days when enough data is there', () {
      final start = DateTime(2026, 1, 1);
      final avg = ReminderMath.averageDistancePerDay([
        pt(start, 0),
        pt(start.add(const Duration(days: 200)), 1000),
        pt(start.add(const Duration(days: 260)), 2000),
        pt(start.add(const Duration(days: 290)), 3000),
      ]);
      // Window = days 200..290 → 2000 km / 90 days.
      expect(avg, closeTo(2000 / 90, 1e-9));
    });

    test('falls back to all data when the window has one point', () {
      final start = DateTime(2026, 1, 1);
      final avg = ReminderMath.averageDistancePerDay([
        pt(start, 0),
        pt(start.add(const Duration(days: 200)), 1000),
      ]);
      expect(avg, 5);
    });
  });

  group('baseline', () {
    final created = DateTime(2026, 6, 1);
    final history = [
      pt(DateTime(2026, 5, 1), 50000),
      pt(DateTime(2026, 5, 20), 50400),
      pt(DateTime(2026, 7, 1), 51000),
    ];

    test('the latest logged entry wins (auto-reschedule)', () {
      final b = ReminderMath.resolveBaseline(
        lastLogged: (date: DateTime(2026, 7, 1), odometer: 51000),
        storedOdometer: 50400,
        storedDate: created,
        createdAt: created,
        currentOdometer: 52000,
      );
      expect(b.date, DateTime(2026, 7, 1));
      expect(b.odometer, 51000);
    });

    test('logged entry without odometer takes it from history', () {
      final b = ReminderMath.resolveBaseline(
        lastLogged: (date: DateTime(2026, 5, 25), odometer: null),
        createdAt: created,
        currentOdometer: 52000,
        history: history,
      );
      expect(b.odometer, 50400);
    });

    test('then the stored baseline, then creation + history, then current', () {
      expect(
        ReminderMath.resolveBaseline(
          storedOdometer: 50100,
          storedDate: DateTime(2026, 5, 10),
          createdAt: created,
          currentOdometer: 52000,
        ),
        (date: DateTime(2026, 5, 10), odometer: 50100.0),
      );
      expect(
        ReminderMath.resolveBaseline(
          createdAt: created,
          currentOdometer: 52000,
          history: history,
        ),
        (date: created, odometer: 50400.0),
      );
      expect(
        ReminderMath.resolveBaseline(
          createdAt: created,
          currentOdometer: 52000,
        ),
        (date: created, odometer: 52000.0),
      );
    });
  });

  group('nextDue', () {
    final baseline = (date: DateTime(2026, 7, 29), odometer: 56403.0);

    test('one time uses the fixed odometer/date of enabled triggers', () {
      const s = ReminderSchedule(
        repeat: false,
        byDistance: true,
        dueOdometer: 60000,
        byDate: false,
      );
      final due = ReminderMath.nextDue(s, baseline);
      expect(due.odometer, 60000);
      expect(due.date, isNull);
    });

    test('repeat adds the interval to the baseline', () {
      const s = ReminderSchedule(
        repeat: true,
        byDistance: true,
        everyDistance: 1000,
        byDate: true,
        everyAmount: 3,
        everyUnit: PeriodUnit.month,
      );
      final due = ReminderMath.nextDue(s, baseline);
      expect(due.odometer, 57403);
      expect(due.date, DateTime(2026, 10, 29));
    });

    test('repeat by distance needs a baseline odometer', () {
      const s = ReminderSchedule(
        repeat: true,
        byDistance: true,
        everyDistance: 1000,
      );
      final due = ReminderMath.nextDue(s, (
        date: DateTime(2026, 1, 1),
        odometer: null,
      ));
      expect(due.odometer, isNull);
    });
  });

  group('evaluate', () {
    final now = DateTime(2026, 9, 23, 10);
    final baseline = (date: DateTime(2026, 9, 1), odometer: 56000.0);

    ReminderDue eval(ReminderSchedule s, {double current = 56935}) =>
        ReminderMath.evaluate(
          schedule: s,
          baseline: baseline,
          now: now,
          currentOdometer: current,
          avgDistancePerDay: 22,
          distanceAhead: 500,
          daysAhead: 30,
        );

    test('distance reminder: remaining, predicted date, progress', () {
      final due = eval(
        const ReminderSchedule(
          repeat: true,
          byDistance: true,
          everyDistance: 2000,
        ),
      );
      expect(due.dueOdometer, 58000);
      expect(due.remainingDistance, 1065);
      // 1065 / 22 ≈ 48 days.
      expect(due.predictedDate, DateTime(2026, 11, 10));
      expect(due.displayDate, due.predictedDate);
      expect(due.displayDays, 48);
      expect(due.remainingDays, isNull);
      expect(due.progress, closeTo(935 / 2000, 1e-9));
      expect(due.status, ReminderStatus.ok);
    });

    test('soon within the distance warning', () {
      final due = eval(
        const ReminderSchedule(
          repeat: false,
          byDistance: true,
          dueOdometer: 57132,
        ),
      );
      expect(due.remainingDistance, 197);
      expect(due.status, ReminderStatus.soon);
      expect(due.displayDays, 9);
    });

    test('overdue once the odometer is reached', () {
      final due = eval(
        const ReminderSchedule(
          repeat: false,
          byDistance: true,
          dueOdometer: 56900,
        ),
      );
      expect(due.remainingDistance, -35);
      expect(due.status, ReminderStatus.overdue);
      expect(due.progress, 1);
      expect(due.predictedDate, ReminderMath.dateOnly(now));
    });

    test('date reminder: soon, today, overdue', () {
      ReminderDue at(DateTime d) =>
          eval(ReminderSchedule(repeat: false, byDate: true, dueDate: d));
      expect(at(DateTime(2026, 12, 31)).status, ReminderStatus.ok);
      final soon = at(DateTime(2026, 10, 10));
      expect(soon.remainingDays, 17);
      expect(soon.status, ReminderStatus.soon);
      expect(at(DateTime(2026, 9, 23)).status, ReminderStatus.soon);
      final late = at(DateTime(2026, 9, 20));
      expect(late.remainingDays, -3);
      expect(late.status, ReminderStatus.overdue);
    });

    test('both triggers: whichever comes first is displayed', () {
      final due = eval(
        const ReminderSchedule(
          repeat: true,
          byDistance: true,
          everyDistance: 5000,
          byDate: true,
          everyAmount: 1,
          everyUnit: PeriodUnit.month,
        ),
      );
      expect(due.dueDate, DateTime(2026, 10, 1));
      expect(due.displayDate, DateTime(2026, 10, 1));
      expect(due.displayDays, 8);
      expect(due.status, ReminderStatus.soon);
    });

    test('status thresholds', () {
      ReminderStatus s({double? km, int? days}) => ReminderMath.status(
        remainingDistance: km,
        remainingDays: days,
        distanceAhead: 500,
        daysAhead: 30,
      );
      expect(s(), ReminderStatus.ok);
      expect(s(km: 501), ReminderStatus.ok);
      expect(s(km: 500), ReminderStatus.soon);
      expect(s(km: 0), ReminderStatus.overdue);
      expect(s(days: 31), ReminderStatus.ok);
      expect(s(days: 30), ReminderStatus.soon);
      expect(s(days: -1), ReminderStatus.overdue);
      expect(s(km: 2000, days: -1), ReminderStatus.overdue);
    });
  });

  group('next refueling', () {
    final refuels = [
      pt(DateTime(2026, 9, 1), 56000),
      pt(DateTime(2026, 9, 21), 56400),
      pt(DateTime(2026, 9, 11), 56200),
    ];

    test('needs two refuelings', () {
      expect(ReminderMath.predictNextRefueling([]), isNull);
      expect(
        ReminderMath.predictNextRefueling(refuels.take(1).toList()),
        isNull,
      );
    });

    test('averages distance and days between refuels', () {
      final next = ReminderMath.predictNextRefueling(refuels)!;
      expect(next.avgDistance, 200);
      expect(next.avgDays, 10);
      expect(next.odometer, 56600);
      expect(next.date, DateTime(2026, 10, 1));
    });

    test('evaluates remaining and status', () {
      final due = ReminderMath.evaluateNextRefueling(
        refuels: refuels,
        now: DateTime(2026, 9, 23),
        currentOdometer: 56450,
      )!;
      expect(due.remainingDistance, 150);
      expect(due.displayDays, 8);
      expect(due.status, ReminderStatus.ok);

      final soon = ReminderMath.evaluateNextRefueling(
        refuels: refuels,
        now: DateTime(2026, 9, 23),
        currentOdometer: 56570,
      )!;
      expect(soon.status, ReminderStatus.soon);

      final late = ReminderMath.evaluateNextRefueling(
        refuels: refuels,
        now: DateTime(2026, 10, 3),
      )!;
      expect(late.status, ReminderStatus.overdue);
    });
  });
}
