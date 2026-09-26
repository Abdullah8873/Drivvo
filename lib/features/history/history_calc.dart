import '../../core/calc/consumption.dart';
import '../../core/theme/record_module.dart';
import 'history_queries.dart';

// Small, pure helpers for the History screens (no widgets here, so they are
// easy to unit-test): month grouping and month totals. Fuel efficiency comes
// from the shared consumption engine (`core/calc/consumption.dart`); this
// file only aggregates its cycles per month.

/// First day of [d]'s month — used as the grouping key.
///
/// Memoized per month: building a local `DateTime(y, m)` asks the OS for the
/// timezone offset every time, and History/Reports call this for every
/// record (thousands of times per rebuild on a big history). The values are
/// immutable, so sharing one instance per month is safe.
DateTime monthOf(DateTime d) => _months.putIfAbsent(
  d.year * 12 + d.month - 1,
  () => DateTime(d.year, d.month),
);

final _months = <int, DateTime>{};

/// Whether [d] falls in the month starting at [month] (a [monthOf] value).
bool isInMonth(DateTime d, DateTime month) =>
    d.year == month.year && d.month == month.month;

/// Totals for one calendar month of the timeline.
class MonthSummary {
  MonthSummary({required this.month, required this.records});

  /// First day of the month.
  final DateTime month;

  /// The month's records, newest first (same order as the timeline).
  final List<TimelineRecord> records;

  /// Previous month's spend (null when that month has no costs), filled in
  /// by [groupByMonth].
  double? previousSpent;

  /// Highest odometer known before this month (null for the earliest
  /// month), filled in by [groupByMonth].
  double? previousOdometer;

  /// Money spent (refuels + expenses + services; not income/routes).
  double get spent =>
      records.where((r) => r.isCost).fold(0.0, (s, r) => s + r.amount);

  /// Cost per module, for the month's donut chart.
  Map<RecordModule, double> get costByModule {
    final map = <RecordModule, double>{};
    for (final r in records.where((r) => r.isCost)) {
      map[r.module] = (map[r.module] ?? 0) + r.amount;
    }
    return map;
  }

  /// Every odometer value recorded this month (routes add their start).
  /// Checklist odometers are optional notes on an inspection and are left
  /// out of distance math.
  List<double> get odometers => [
    for (final r in records)
      if (r.module != RecordModule.checklist) ...[
        ?r.odometer,
        if (r.route != null) r.route!.startOdometer,
      ],
  ];

  /// Distance driven in the month: this month's highest odometer minus the
  /// highest one known before it — so a month with a single record still
  /// gets a distance. The earliest month falls back to its own max − min.
  /// Null when there's nothing positive to show.
  double? get distance {
    final odos = odometers;
    if (odos.isEmpty) return null;
    final max = odos.reduce((a, b) => a > b ? a : b);
    final base = previousOdometer ?? odos.reduce((a, b) => a < b ? a : b);
    final d = max - base;
    return d > 0 ? d : null;
  }

  /// Average efficiency of the engine [cycles] that END in this month (a
  /// cycle may start in the previous month): total distance ÷ total volume.
  double? efficiencyFrom(Iterable<FuelCycle> cycles) =>
      monthEfficiency(cycles, month);

  /// Spend change vs the previous month as a fraction (−0.12 = 12% below).
  double? get changeVsPrevious {
    final prev = previousSpent;
    if (prev == null || prev <= 0) return null;
    return (spent - prev) / prev;
  }
}

/// Distance ÷ volume over the [cycles] whose closing refuel falls in
/// [month] (weights long cycles more than averaging cycle values would).
/// Null when no cycle ends in that month.
double? monthEfficiency(Iterable<FuelCycle> cycles, DateTime month) {
  var distance = 0.0;
  var volume = 0.0;
  for (final c in cycles) {
    if (!isInMonth(c.end.date, month)) continue;
    distance += c.distance;
    volume += c.volume;
  }
  return distance > 0 && volume > 0 ? distance / volume : null;
}

/// Splits a newest-first timeline into month groups (newest month first),
/// links each month to the previous calendar month's spend and to the
/// highest odometer recorded before it.
List<MonthSummary> groupByMonth(List<TimelineRecord> timeline) {
  final groups = <MonthSummary>[];
  for (final r in timeline) {
    final m = monthOf(r.date);
    if (groups.isEmpty || groups.last.month != m) {
      groups.add(MonthSummary(month: m, records: []));
    }
    groups.last.records.add(r);
  }
  final byMonth = {for (final g in groups) g.month: g};
  for (final g in groups) {
    final prev = byMonth[monthOf(DateTime(g.month.year, g.month.month - 1))];
    final spent = prev?.spent;
    g.previousSpent = spent == null || spent <= 0 ? null : spent;
  }
  // Oldest → newest, carrying the running max odometer forward.
  double? runningMax;
  for (final g in groups.reversed) {
    g.previousOdometer = runningMax;
    for (final o in g.odometers) {
      if (runningMax == null || o > runningMax) runningMax = o;
    }
  }
  return groups;
}

/// Odometer distance since the previous (older) record of the same module.
double? distanceSincePrevious(
  List<TimelineRecord> timeline,
  TimelineRecord record,
) {
  final odo = record.odometer;
  if (odo == null) return null;
  final same = timeline.where((r) => r.module == record.module).toList();
  final i = same.indexWhere((r) => r.id == record.id);
  if (i < 0) return null;
  // The timeline is newest first, so "previous" records come after i.
  final prev = same.skip(i + 1).where((r) => r.odometer != null).firstOrNull;
  if (prev == null) return null;
  final d = odo - prev.odometer!;
  return d >= 0 ? d : null;
}
