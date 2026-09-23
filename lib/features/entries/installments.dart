import 'dart:math' as math;

/// How far apart the installments of a split expense/income are.
enum InstallmentInterval {
  weekly('Weekly'),
  every15Days('Every 15 days'),
  monthly('Monthly');

  const InstallmentInterval(this.label);

  final String label;
}

/// One installment of a split entry, as computed by [planInstallments].
class InstallmentShare {
  const InstallmentShare({
    required this.number,
    required this.date,
    required this.totalCost,
    required this.discount,
    required this.itemAmounts,
  });

  /// 1-based position in the group (1 = the parent row).
  final int number;
  final DateTime date;
  final double totalCost;
  final double discount;

  /// This installment's share of each line item, in the same order.
  final List<double> itemAmounts;
}

/// Pure installment math (no Flutter, no database) so it can be unit-tested.
///
/// Splits [total], [discount] and every entry of [itemAmounts] into [count]
/// equal parts (the cent remainder goes on the first installment, so every
/// column still adds up exactly) and spaces the dates by [interval].
List<InstallmentShare> planInstallments({
  required DateTime firstDate,
  required int count,
  required InstallmentInterval interval,
  required double total,
  double discount = 0,
  List<double> itemAmounts = const [],
}) {
  final dates = installmentDates(firstDate, count, interval);
  final totals = splitAmount(total, count);
  final discounts = splitAmount(discount, count);
  final items = [for (final a in itemAmounts) splitAmount(a, count)];
  return [
    for (var i = 0; i < count; i++)
      InstallmentShare(
        number: i + 1,
        date: dates[i],
        totalCost: totals[i],
        discount: discounts[i],
        itemAmounts: [for (final split in items) split[i]],
      ),
  ];
}

/// Splits [amount] into [count] parts, rounded to cents. The rounding
/// remainder is added to the first part: `splitAmount(100, 3)` →
/// `[33.34, 33.33, 33.33]`.
List<double> splitAmount(double amount, int count) {
  if (count < 1) throw ArgumentError.value(count, 'count', 'must be >= 1');
  // Work in integer cents to avoid floating-point drift (0.1 + 0.2 != 0.3).
  final cents = (amount * 100).round();
  final base = (cents / count).floor();
  final remainder = cents - base * count;
  return [
    for (var i = 0; i < count; i++) (base + (i == 0 ? remainder : 0)) / 100,
  ];
}

/// Dates of [count] installments starting at [first] (kept as installment 1).
/// Monthly steps clamp to the end of shorter months (Jan 31 → Feb 28).
/// Uses calendar arithmetic, so the time of day survives DST changes.
List<DateTime> installmentDates(
  DateTime first,
  int count,
  InstallmentInterval interval,
) {
  DateTime at(int i) => switch (interval) {
    InstallmentInterval.weekly => _withDay(
      first,
      first.month,
      first.day + 7 * i,
    ),
    InstallmentInterval.every15Days => _withDay(
      first,
      first.month,
      first.day + 15 * i,
    ),
    InstallmentInterval.monthly => _withDay(
      first,
      first.month + i,
      math.min(first.day, _daysInMonth(first.year, first.month + i)),
    ),
  };
  return [for (var i = 0; i < count; i++) at(i)];
}

/// Guesses the interval of an existing group from its first two dates
/// (the interval itself isn't stored). Defaults to monthly.
InstallmentInterval inferInterval(DateTime first, DateTime second) {
  for (final interval in InstallmentInterval.values) {
    if (installmentDates(first, 2, interval)[1] == second) return interval;
  }
  return InstallmentInterval.monthly;
}

// DateTime normalizes overflow (month 13 → January next year, day 35 → next
// month), which is exactly what we want here.
DateTime _withDay(DateTime base, int month, int day) => DateTime(
  base.year,
  month,
  day,
  base.hour,
  base.minute,
  base.second,
  base.millisecond,
);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
