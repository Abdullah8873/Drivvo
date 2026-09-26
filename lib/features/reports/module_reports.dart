import 'package:flutter/material.dart' show Color;

import '../../core/theme/record_module.dart';
import '../history/history_calc.dart';
import '../history/history_queries.dart';
import '../routes/route_math.dart';
import '../routes/route_queries.dart';
import '../readings/reading_math.dart';
import 'general_report.dart' show periodDistance;
import 'report_period.dart';

// Pure aggregation for the Reports → Expense / Income / Service / Route /
// Reading tabs (no widgets, no providers — same idea as `general_report.dart`,
// so every number is unit-tested). Each `build...Report` takes the records
// `ReportScope` already filtered to the period (`scope.recordsOf({module})`),
// so installments — stored as their own `TimelineRecord` dated on their own
// installment date — land in the right month for free.

/// One named amount going into a [typeBreakdown] (an expense/service/income
/// line, e.g. "Oil Change" → 1200).
class TypeAmount {
  const TypeAmount({required this.name, required this.amount});

  final String name;
  final double amount;
}

/// A [typeBreakdown] slice, ready for `DonutSlice(label: name, value: amount,
/// color: color)` — kept out of the widgets layer so the "top N + Others"
/// folding is unit-tested.
typedef ColoredAmount = ({String name, double amount, Color color});

/// Fixed categorical palette for per-type donut slices. Unlike modules, a
/// "type of expense" is a catalog item the user names freely and has no
/// color of its own, so slices just cycle this palette; "Others" always
/// gets the trailing grey.
const typePalette = [
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFFFA726), // orange
  Color(0xFFEF5350), // red
];

const _othersColor = Color(0xFF9E9E9E);

/// Groups [lines] by name, keeps the [top] largest totals and folds the
/// remainder into one "Others" slice (added only when there's a remainder).
/// Zero/negative totals are dropped before ranking, same as [DonutChart].
List<ColoredAmount> typeBreakdown(Iterable<TypeAmount> lines, {int top = 4}) {
  final byName = <String, double>{};
  for (final l in lines) {
    byName[l.name] = (byName[l.name] ?? 0) + l.amount;
  }
  final sorted = byName.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final result = <ColoredAmount>[
    for (final (i, e) in sorted.take(top).indexed)
      (
        name: e.key,
        amount: e.value,
        color: typePalette[i % typePalette.length],
      ),
  ];
  if (sorted.length > top) {
    final rest = sorted.skip(top).fold(0.0, (s, e) => s + e.value);
    if (rest > 0) {
      result.add((name: 'Others', amount: rest, color: _othersColor));
    }
  }
  return result;
}

/// The per-type lines of one expense/service/income record, scaled so they
/// add up to the record's post-discount `amount`: each item gets
/// `item × amount / itemsSum`. Without this the donut would show the
/// pre-discount prices while the card shows the discounted total. A record
/// with no items (or items that are all 0) becomes one line named after it.
List<TypeAmount> entryTypeAmounts(TimelineRecord r) {
  final itemsSum = r.items.fold(0.0, (s, i) => s + i.amount);
  if (itemsSum == 0) {
    return [if (r.amount != 0) TypeAmount(name: r.title, amount: r.amount)];
  }
  return [
    for (final item in r.items)
      TypeAmount(name: item.name, amount: item.amount * r.amount / itemsSum),
  ];
}

/// Every figure and chart series for the Expense / Income / Service tabs.
class ModuleMoneyReport {
  const ModuleMoneyReport({
    required this.total,
    required this.days,
    required this.distance,
    required this.monthly,
    required this.typeBreakdown,
  });

  /// Sum of the in-period records' amounts (post-discount, like History).
  final double total;

  /// Days the period covers (`ReportScope.days`); 0 = no "by day" figure.
  final int days;

  /// Distance driven by the vehicle in the period (any module); 0 = unknown.
  final double distance;

  /// Month (first day) → total, for the monthly bar chart.
  final Map<DateTime, double> monthly;

  /// Top types + "Others" for the breakdown donut.
  final List<ColoredAmount> typeBreakdown;

  double? get perDay => days > 0 ? total / days : null;
  double? get perDistance => distance > 0 ? total / distance : null;
}

/// Builds an Expense/Income/Service report from [records] — already the
/// period's records of one module (`scope.recordsOf({module})`), any order.
/// [timeline] and [range] are the vehicle's full timeline and the resolved
/// period (`scope.timeline`/`scope.range`), needed for the "by km" distance
/// the same way `buildGeneralReport` computes it.
ModuleMoneyReport buildModuleMoneyReport({
  required List<TimelineRecord> records,
  required List<TimelineRecord> timeline,
  required ReportRange range,
  required int days,
}) {
  var total = 0.0;
  final monthly = <DateTime, double>{};
  final lines = <TypeAmount>[];
  for (final r in records) {
    total += r.amount;
    final m = monthOf(r.date);
    monthly[m] = (monthly[m] ?? 0) + r.amount;
    lines.addAll(entryTypeAmounts(r));
  }
  return ModuleMoneyReport(
    total: total,
    days: days,
    distance: periodDistance(timeline, range),
    monthly: monthly,
    typeBreakdown: typeBreakdown(lines),
  );
}

/// Every figure and chart series for the Route tab, built on the same pure
/// math as History/the Route form (`RouteMath`), so open routes (no final
/// odometer) are excluded from distance/time exactly like there.
class RouteReport {
  const RouteReport({
    required this.totals,
    required this.days,
    required this.monthlyDistance,
  });

  final RouteTotals totals;

  /// Days the period covers; 0 = no "by day" figure.
  final int days;

  /// Month (first day) → distance, finished routes only.
  final Map<DateTime, double> monthlyDistance;

  double? get valuePerDay => days > 0 ? totals.value / days : null;

  /// Average route duration, or null when no route in the period finished.
  double? get averageMinutes =>
      totals.finishedCount > 0 ? totals.minutes / totals.finishedCount : null;
}

/// Builds the Route report from [records] — already the period's route
/// records (`scope.recordsOf({RecordModule.route})`).
RouteReport buildRouteReport({
  required List<TimelineRecord> records,
  required int days,
}) {
  final routes = [for (final r in records) r.route!];
  final totals = RouteMath.totals(routes.map((r) => r.span));
  final monthly = <DateTime, double>{};
  for (final r in routes) {
    final d = r.distance;
    if (d == null || d <= 0) continue;
    final m = monthOf(r.startDate);
    monthly[m] = (monthly[m] ?? 0) + d;
  }
  return RouteReport(totals: totals, days: days, monthlyDistance: monthly);
}

/// Every figure and chart series for the Reading tab.
class ReadingReport {
  const ReadingReport({
    required this.count,
    required this.distance,
    required this.days,
    required this.averageDaysBetween,
    required this.monthlyDistance,
  });

  /// Readings in the period.
  final int count;

  /// Distance driven in the period, by readings alone: the highest reading
  /// in the period minus the last one before it (the same rule as General's
  /// `periodDistance`), or the period's own max − min when there's none
  /// before. 0 = unknown.
  final double distance;

  /// Days the period covers (`ReportScope.days`, the same denominator as
  /// General's daily average); 0 = no daily average.
  final int days;

  /// Average days between consecutive readings in the period, or null
  /// with fewer than two.
  final double? averageDaysBetween;

  /// Month (first day) → distance driven between readings that end in it
  /// (same "attribute to the later end" rule as `monthEfficiency`'s fuel
  /// cycles). The first reading in the period is measured from the last
  /// one before it, so the bars add up to [distance].
  final Map<DateTime, double> monthlyDistance;

  /// Distance per day of the period, or null when either is unknown.
  double? get dailyAverage => days > 0 && distance > 0 ? distance / days : null;
}

/// Builds the Reading report from the vehicle's whole [timeline]
/// (`scope.timeline`, any order — only readings are used) for [range];
/// [days] is the period's day count (`scope.days`).
ReadingReport buildReadingReport({
  required List<TimelineRecord> timeline,
  required ReportRange range,
  required int days,
}) {
  final readings = [
    for (final r in timeline)
      if (r.module == RecordModule.reading && r.odometer != null) r,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final inPeriod = [
    for (final r in readings)
      if (range.contains(r.date)) (date: r.date, odometer: r.odometer!),
  ];
  final stats = ReadingMath.stats(inPeriod);

  // Baseline: the last reading before the period, when there is one.
  final before = range.from == null
      ? null
      : readings.lastWhereOrNull((r) => r.date.isBefore(range.from!));
  final points = [
    if (before != null) (date: before.date, odometer: before.odometer!),
    ...inPeriod,
  ];
  final monthly = <DateTime, double>{};
  for (var i = 1; i < points.length; i++) {
    final d = points[i].odometer - points[i - 1].odometer;
    if (d <= 0) continue;
    final m = monthOf(points[i].date);
    monthly[m] = (monthly[m] ?? 0) + d;
  }
  return ReadingReport(
    count: inPeriod.length,
    distance: periodDistance(readings, range),
    days: days,
    averageDaysBetween: stats.averageDaysBetween,
    monthlyDistance: monthly,
  );
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}
