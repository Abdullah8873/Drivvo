import '../../core/theme/record_module.dart';
import 'history_queries.dart';

// Small, pure helpers for the History screens (no widgets here, so they are
// easy to unit-test). The efficiency math is deliberately simple and local;
// TODO(consumption): replace with the shared consumption engine once it lands
// in core/calc/.

/// First day of [d]'s month — used as the grouping key.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

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

  /// Distance driven inside the month: max − min odometer (null if fewer
  /// than two odometer values).
  double? get distance {
    final odos = <double>[
      for (final r in records) ...[
        ?r.odometer,
        if (r.route != null) r.route!.startOdometer,
      ],
    ];
    if (odos.length < 2) return null;
    odos.sort();
    final d = odos.last - odos.first;
    return d > 0 ? d : null;
  }

  /// Average efficiency (distance per volume unit) over the month's refuels.
  double? get efficiency => simpleEfficiency(
    records.where((r) => r.module == RecordModule.refueling).toList(),
  );

  /// Spend change vs the previous month as a fraction (−0.12 = 12% below).
  double? get changeVsPrevious {
    final prev = previousSpent;
    if (prev == null || prev <= 0) return null;
    return (spent - prev) / prev;
  }
}

/// Splits a newest-first timeline into month groups (newest month first) and
/// links each month to the previous calendar month's spend.
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
    final prev = byMonth[DateTime(g.month.year, g.month.month - 1)];
    final spent = prev?.spent;
    g.previousSpent = spent == null || spent <= 0 ? null : spent;
  }
  return groups;
}

/// Full-tank-to-full-tank efficiency over [refuels] (any order): distance
/// between the first and last full tank ÷ volume put in after the first one.
/// Null when there are fewer than two full tanks or nothing to divide.
double? simpleEfficiency(List<TimelineRecord> refuels) {
  final sorted = [...refuels]
    ..sort((a, b) => (a.odometer ?? 0).compareTo(b.odometer ?? 0));
  final first = sorted.indexWhere(_isFull);
  final last = sorted.lastIndexWhere(_isFull);
  if (first < 0 || last <= first) return null;
  final distance = sorted[last].odometer! - sorted[first].odometer!;
  final volume = sorted
      .sublist(first + 1, last + 1)
      .fold(0.0, (s, r) => s + r.totalVolume);
  if (distance <= 0 || volume <= 0) return null;
  return distance / volume;
}

bool _isFull(TimelineRecord r) =>
    r.odometer != null && (r.refueling?.fullTank ?? false);

/// The refuel cycle that ends at [refuel]: from the previous full tank up to
/// this (full) one.
class RefuelCycle {
  const RefuelCycle({
    required this.distance,
    required this.volume,
    required this.cost,
  });

  final double distance;
  final double volume;
  final double cost;

  double get efficiency => distance / volume;
  double get costPerDistance => cost / distance;
}

/// Cycle ending at [refuel] (null if it isn't a full tank, has no previous
/// full tank, or a refuel in between was flagged "missed previous").
RefuelCycle? refuelCycle(List<TimelineRecord> timeline, TimelineRecord refuel) {
  if (!_isFull(refuel)) return null;
  final refuels =
      timeline
          .where(
            (r) => r.module == RecordModule.refueling && r.odometer != null,
          )
          .toList()
        ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
  final end = refuels.indexWhere((r) => r.id == refuel.id);
  if (end <= 0) return null;
  final start = refuels.sublist(0, end).lastIndexWhere(_isFull);
  if (start < 0) return null;
  final inCycle = refuels.sublist(start + 1, end + 1);
  if (inCycle.any((r) => r.refueling!.missedPrevious)) return null;
  final distance = refuel.odometer! - refuels[start].odometer!;
  final volume = inCycle.fold(0.0, (s, r) => s + r.totalVolume);
  if (distance <= 0 || volume <= 0) return null;
  return RefuelCycle(
    distance: distance,
    volume: volume,
    cost: inCycle.fold(0.0, (s, r) => s + r.amount),
  );
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
