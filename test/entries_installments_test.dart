import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/entries/installments.dart';

void main() {
  group('splitAmount', () {
    test('puts the cent remainder on the first part', () {
      expect(splitAmount(100, 3), [33.34, 33.33, 33.33]);
      expect(splitAmount(1000, 3), [333.34, 333.33, 333.33]);
    });

    test('parts always add up to the amount', () {
      for (final (amount, n) in [(0.05, 3), (1234.56, 7), (99.99, 12)]) {
        final parts = splitAmount(amount, n);
        final cents = parts.fold(0, (s, p) => s + (p * 100).round());
        expect(cents, (amount * 100).round(), reason: '$amount / $n');
      }
    });

    test('one part is the whole amount', () {
      expect(splitAmount(12.5, 1), [12.5]);
    });

    test('rejects a count below 1', () {
      expect(() => splitAmount(10, 0), throwsArgumentError);
    });
  });

  group('installmentDates', () {
    final first = DateTime(2026, 1, 31, 10, 30);

    test('weekly and every 15 days keep the time of day', () {
      expect(installmentDates(first, 3, InstallmentInterval.weekly), [
        first,
        DateTime(2026, 2, 7, 10, 30),
        DateTime(2026, 2, 14, 10, 30),
      ]);
      expect(installmentDates(first, 3, InstallmentInterval.every15Days), [
        first,
        DateTime(2026, 2, 15, 10, 30),
        DateTime(2026, 3, 2, 10, 30),
      ]);
    });

    test('monthly clamps to the end of shorter months', () {
      expect(installmentDates(first, 4, InstallmentInterval.monthly), [
        first,
        DateTime(2026, 2, 28, 10, 30),
        DateTime(2026, 3, 31, 10, 30),
        DateTime(2026, 4, 30, 10, 30),
      ]);
    });

    test('monthly rolls over the year', () {
      final dates = installmentDates(
        DateTime(2026, 11, 15),
        3,
        InstallmentInterval.monthly,
      );
      expect(dates.last, DateTime(2027, 1, 15));
    });

    test('inferInterval recognizes each interval', () {
      for (final interval in InstallmentInterval.values) {
        final d = installmentDates(first, 2, interval);
        expect(inferInterval(d[0], d[1]), interval);
      }
    });
  });

  test('planInstallments splits totals, discount and items', () {
    final plan = planInstallments(
      firstDate: DateTime(2026, 9, 1),
      count: 3,
      interval: InstallmentInterval.monthly,
      total: 950,
      discount: 50,
      itemAmounts: [700, 300],
    );
    expect(plan.map((s) => s.number), [1, 2, 3]);
    // Each total = that row's items − its discount share.
    expect(plan.map((s) => s.totalCost), [316.66, 316.67, 316.67]);
    expect(plan.map((s) => s.discount), [16.68, 16.66, 16.66]);
    expect(plan.map((s) => s.itemAmounts), [
      [233.34, 100],
      [233.33, 100],
      [233.33, 100],
    ]);
    expect(plan.last.date, DateTime(2026, 11, 1));
  });

  group('planInstallments keeps every row consistent', () {
    int cents(double v) => (v * 100).round();

    for (final (items, discount, count) in [
      (<double>[100, 50], 0.0, 3),
      (<double>[100, 50], 10.0, 3),
      (<double>[0.05, 0.05, 0.05], 0.0, 4),
      (<double>[1234.56, 99.99, 0.01], 3.33, 7),
    ]) {
      test('$items − $discount in $count', () {
        final total = items.fold(0.0, (s, a) => s + a) - discount;
        final plan = planInstallments(
          firstDate: DateTime(2026, 9, 1),
          count: count,
          interval: InstallmentInterval.monthly,
          total: total,
          discount: discount,
          itemAmounts: items,
        );
        for (final s in plan) {
          final itemCents = s.itemAmounts.fold(0, (c, a) => c + cents(a));
          expect(
            cents(s.totalCost),
            itemCents - cents(s.discount),
            reason: 'installment ${s.number}',
          );
        }
        final grand = plan.fold(0, (c, s) => c + cents(s.totalCost));
        expect(grand, cents(total));
      });
    }
  });
}
