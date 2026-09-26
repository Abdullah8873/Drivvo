import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/date_axis.dart';

void main() {
  List<String> labels(DateAxisTicks t) => [for (final d in t.ticks) t.label(d)];

  DateAxisTicks ticks(DateTime a, DateTime b, {int months = 5, int days = 4}) =>
      DateAxisTicks.compute(a, b, maxMonthTicks: months, maxDayTicks: days);

  group('DateAxisTicks month ticks', () {
    // The owner's real data: 2025-06-11 … 2026-09-17 (15 months).
    final start = DateTime(2025, 6, 11, 11, 50);
    final end = DateTime(2026, 9, 17, 16, 43);

    test('are month starts labelled with the year', () {
      final t = ticks(start, end, months: 20);
      expect(t.unit, DateTickUnit.month);
      expect(t.step, 1);
      expect(t.ticks.first, DateTime(2025, 7));
      expect(t.ticks.last, DateTime(2026, 9));
      expect(labels(t).first, '2025-07');
      expect(t.ticks.every((d) => d.day == 1 && d.hour == 0), isTrue);
    });

    test('step up 1 → 3 → 6 → 12 months to fit the space', () {
      expect(ticks(start, end, months: 15).step, 1);
      final quarters = ticks(start, end, months: 5);
      expect(quarters.step, 3);
      expect(labels(quarters), [
        '2025-07',
        '2025-10',
        '2026-01',
        '2026-04',
        '2026-07',
      ]);
      final halves = ticks(start, end, months: 3);
      expect(halves.step, 6);
      expect(labels(halves), ['2025-07', '2026-01', '2026-07']);
      final years = ticks(start, end, months: 1);
      expect(years.step, 12);
      expect(labels(years), ['2026-01']);
    });

    test('never exceed the limit and never repeat a label', () {
      for (var max = 1; max <= 12; max++) {
        final t = ticks(
          DateTime(2019, 3, 5),
          DateTime(2026, 9, 17),
          months: max,
        );
        expect(t.ticks.length, lessThanOrEqualTo(max), reason: 'max $max');
        expect(labels(t).toSet().length, t.ticks.length);
      }
    });

    test('long ranges use multi-year steps on January', () {
      final t = ticks(DateTime(2001, 5), DateTime(2026, 1, 2), months: 4);
      expect(t.step, 120);
      expect(labels(t), ['2010-01', '2020-01']);
    });

    test('a range starting exactly on the 1st includes it', () {
      final t = ticks(DateTime(2026, 1), DateTime(2026, 3, 15), months: 5);
      expect(labels(t), ['2026-01', '2026-02', '2026-03']);
    });

    test('reversed input is handled', () {
      expect(labels(ticks(end, start, months: 3)), [
        '2025-07',
        '2026-01',
        '2026-07',
      ]);
    });
  });

  group('DateAxisTicks day ticks', () {
    test('short ranges fall back to days', () {
      final t = ticks(
        DateTime(2026, 8, 20, 9),
        DateTime(2026, 9, 5, 18),
        days: 3,
      );
      expect(t.unit, DateTickUnit.day);
      expect(t.step, 7);
      expect(t.ticks.length, inInclusiveRange(1, 3));
      expect(labels(t).first, matches(RegExp(r'^2026-0[89]-\d\d$')));
      for (final d in t.ticks) {
        expect(d.hour, 0);
        expect(d.isAfter(DateTime(2026, 8, 20, 9)), isTrue);
        expect(d.isBefore(DateTime(2026, 9, 5, 18)), isTrue);
      }
    });

    test('a few days get one tick per day', () {
      final t = ticks(DateTime(2026, 9, 1, 12), DateTime(2026, 9, 4, 12));
      expect(t.step, 1);
      expect(labels(t), ['2026-09-02', '2026-09-03', '2026-09-04']);
    });

    test('day ticks cross a month boundary without gaps or repeats', () {
      final t = ticks(DateTime(2026, 1, 30), DateTime(2026, 2, 2, 1), days: 10);
      expect(labels(t), [
        '2026-01-30',
        '2026-01-31',
        '2026-02-01',
        '2026-02-02',
      ]);
    });

    test('ticks stay put when the range grows by a day', () {
      final a = ticks(DateTime(2026, 5, 1), DateTime(2026, 5, 20), days: 3);
      final b = ticks(DateTime(2026, 5, 1), DateTime(2026, 5, 21), days: 3);
      expect(a.step, b.step);
      expect(b.ticks.take(a.ticks.length), a.ticks);
    });

    test('too little room for days → the single month start in range', () {
      final t = ticks(DateTime(2026, 5, 10), DateTime(2026, 6, 25), days: 1);
      expect(t.unit, DateTickUnit.month);
      expect(labels(t), ['2026-06']);
    });

    test('a range inside one day gets that day', () {
      final t = ticks(DateTime(2026, 9, 1, 8), DateTime(2026, 9, 1, 17));
      expect(labels(t), ['2026-09-01']);
    });
  });
}
