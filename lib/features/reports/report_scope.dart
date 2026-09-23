import '../../core/db/app_database.dart';
import '../../core/theme/record_module.dart';
import '../history/history_queries.dart';
import 'report_period.dart';

/// Everything a report tab needs about "which vehicle, which records, which
/// days" — the resolved period filter applied to the vehicle's History
/// timeline. Built by `reportScopeProvider`; every tab reads the same scope,
/// so the period card, counts and "by day" averages agree across tabs.
class ReportScope {
  ReportScope({
    required this.vehicle,
    required this.period,
    required this.range,
    required this.timeline,
    required this.now,
  });

  final Vehicle vehicle;

  /// The period picked in the Filter screen.
  final ReportPeriod period;

  /// [period] resolved at [now] (half-open `[from, to)`).
  final ReportRange range;

  /// Every record of the vehicle (all periods), newest first — needed for
  /// things like "distance driven" which look at the odometer before the
  /// period starts.
  final List<TimelineRecord> timeline;

  final DateTime now;

  /// The records dated inside [range], newest first.
  late final List<TimelineRecord> records = [
    for (final r in timeline)
      if (range.contains(r.date)) r,
  ];

  /// Days the report covers (see `reportSpan`); null when empty.
  late final DateSpan? span = reportSpan(
    range,
    now: now,
    trackingStart: timeline.isEmpty ? null : timeline.last.date,
    lastRecord: records.isEmpty ? null : records.first.date,
  );

  /// Day count used for every "by day" figure (0 when there's no span).
  int get days => span?.days ?? 0;

  /// In-period records of the given modules, newest first.
  List<TimelineRecord> recordsOf(Set<RecordModule> modules) => [
    for (final r in records)
      if (modules.contains(r.module)) r,
  ];

  /// `[from, to)` for providers keyed by an optional range, e.g.
  /// `routeTotalsProvider((vehicleId: id, from: scope.from, to: scope.to))`.
  DateTime? get from => range.from;
  DateTime? get to => range.to;
}
