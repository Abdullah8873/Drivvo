import '../../core/theme/record_module.dart';
import '../history/history_calc.dart';
import '../history/history_queries.dart';
import 'report_period.dart';

// Pure aggregation for the Reports → General tab (no widgets, no providers),
// so every number on the tab is unit-tested. Input is the History timeline
// (`TimelineRecord`s), which already flattens every module into one shape.

/// Distance driven inside [range]: the highest odometer recorded in the
/// range minus the highest one recorded before it (same rule as History's
/// month cards, so a period with a single record still gets a distance).
/// Without earlier records it falls back to the range's own max − min.
/// Routes contribute both their start and end odometer. 0 when unknown.
double periodDistance(List<TimelineRecord> timeline, ReportRange range) {
  double? max;
  double? min;
  double? before;
  for (final r in timeline) {
    final odos = [?r.odometer, if (r.route != null) r.route!.startOdometer];
    if (odos.isEmpty) continue;
    if (range.contains(r.date)) {
      for (final o in odos) {
        if (max == null || o > max) max = o;
        if (min == null || o < min) min = o;
      }
    } else if (range.from != null && r.date.isBefore(range.from!)) {
      for (final o in odos) {
        if (before == null || o > before) before = o;
      }
    }
  }
  if (max == null) return 0;
  final d = max - (before ?? min!);
  return d > 0 ? d : 0;
}

/// Which bar a record's money goes into on the "Expenses and income"
/// chart. Route values count as income (they're money coming in, like
/// `TimelineRecord.isIncome`); readings carry no money.
RecordModule? chartModuleOf(TimelineRecord r) => switch (r.module) {
  RecordModule.refueling ||
  RecordModule.expense ||
  RecordModule.service ||
  RecordModule.income => r.module,
  RecordModule.route => RecordModule.income,
  _ => null,
};

/// One odometer reading for the "Odometer chart" (point colored by module).
class OdometerPoint {
  const OdometerPoint({
    required this.date,
    required this.odometer,
    required this.module,
  });

  final DateTime date;
  final double odometer;
  final RecordModule module;
}

/// Every figure and chart series on the General tab.
class GeneralReport {
  const GeneralReport({
    required this.entryCount,
    required this.days,
    required this.distance,
    required this.cost,
    required this.income,
    required this.costByModule,
    required this.months,
    required this.monthly,
    required this.odometerPoints,
  });

  /// Records in the period (all modules, readings included).
  final int entryCount;

  /// Days the period covers (see `reportSpan`); 0 = no "by day" figures.
  final int days;

  /// Distance driven in the period (vehicle's unit); 0 = unknown.
  final double distance;

  /// Refuels + expenses + services.
  final double cost;

  /// Incomes + route values.
  final double income;

  /// Cost split for the donut (refueling / expense / service), zeros left out.
  final Map<RecordModule, double> costByModule;

  /// Continuous months (first day) from the period's first to last record.
  final List<DateTime> months;

  /// Chart series: module → month → amount (see [chartModuleOf]).
  final Map<RecordModule, Map<DateTime, double>> monthly;

  /// Odometer readings in the period, oldest first.
  final List<OdometerPoint> odometerPoints;

  /// Income − cost (negative when the vehicle cost more than it earned).
  double get balance => income - cost;

  double? perDay(double value) => days > 0 ? value / days : null;
  double? perDistance(double value) => distance > 0 ? value / distance : null;

  double? get balancePerDay => perDay(balance);
  double? get balancePerDistance => perDistance(balance);
  double? get costPerDay => perDay(cost);
  double? get costPerDistance => perDistance(cost);
  double? get incomePerDay => perDay(income);
  double? get incomePerDistance => perDistance(income);

  /// Average distance per day.
  double? get dailyDistance => distance > 0 ? perDay(distance) : null;
}

/// Builds the General report from a vehicle's full [timeline] (any order)
/// for [range]. [days] is the period's day count (`ReportScope.days`).
GeneralReport buildGeneralReport({
  required List<TimelineRecord> timeline,
  required ReportRange range,
  required int days,
}) {
  final inRange = [
    for (final r in timeline)
      if (range.contains(r.date)) r,
  ]..sort((a, b) => a.date.compareTo(b.date));

  var cost = 0.0;
  var income = 0.0;
  final costByModule = <RecordModule, double>{};
  final monthly = <RecordModule, Map<DateTime, double>>{};
  final points = <OdometerPoint>[];

  for (final r in inRange) {
    if (r.isCost) {
      cost += r.amount;
      costByModule[r.module] = (costByModule[r.module] ?? 0) + r.amount;
    } else if (r.isIncome) {
      income += r.amount;
    }
    final chartModule = chartModuleOf(r);
    if (chartModule != null && r.amount != 0) {
      final byMonth = monthly.putIfAbsent(chartModule, () => {});
      final m = monthOf(r.date);
      byMonth[m] = (byMonth[m] ?? 0) + r.amount;
    }
    if (r.odometer != null) {
      points.add(
        OdometerPoint(date: r.date, odometer: r.odometer!, module: r.module),
      );
    }
  }
  costByModule.removeWhere((_, v) => v == 0);

  return GeneralReport(
    entryCount: inRange.length,
    days: days,
    distance: periodDistance(timeline, range),
    cost: cost,
    income: income,
    costByModule: costByModule,
    months: inRange.isEmpty
        ? const []
        : monthsBetween(inRange.first.date, inRange.last.date),
    monthly: monthly,
    odometerPoints: points,
  );
}
