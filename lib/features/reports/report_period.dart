// Pure date-range logic for the Reports period filter (no Flutter imports,
// so it's trivially unit-testable). Every report tab resolves the selected
// `ReportPeriod` into a `ReportRange` — a half-open `[from, to)` window,
// the same convention as `routeTotalsProvider` / `readingStatsProvider`, so
// a range can be passed straight to those providers.

/// The choices in the Filter screen's "Period" list (Drivvo's options).
enum ReportPeriodKind {
  currentMonth('Current month'),
  previousMonth('Previous month'),

  /// Drivvo's "Last month" = the last 30 days (today included).
  lastMonth('Last month'),
  last3Months('Last 3 months'),
  last6Months('Last 6 months'),

  /// The last 12 months (today included), not the previous calendar year.
  lastYear('Last year'),
  allTime('All time'),
  custom('Custom');

  const ReportPeriodKind(this.label);

  final String label;
}

/// Midnight at the start of [d]'s day.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [day] shifted by [months] calendar months, clamping the day of month
/// (31 Mar − 1 month = 28/29 Feb, not 3 Mar like `DateTime` overflow would).
DateTime addMonths(DateTime day, int months) {
  final first = DateTime(day.year, day.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
    first.year,
    first.month,
    day.day > lastDay ? lastDay : day.day,
  );
}

/// Whole calendar days from [a] to [b] (both truncated to the day); DST-safe
/// because it counts in UTC.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Every month (first day) from [first]'s month to [last]'s month
/// inclusive — the x-axis of the monthly bar charts, gaps included.
List<DateTime> monthsBetween(DateTime first, DateTime last) {
  final months = <DateTime>[];
  var m = DateTime(first.year, first.month);
  final end = DateTime(last.year, last.month);
  while (!m.isAfter(end)) {
    months.add(m);
    m = DateTime(m.year, m.month + 1);
  }
  return months;
}

/// A half-open date window `[from, to)`; null = unbounded on that side.
class ReportRange {
  const ReportRange({this.from, this.to});

  static const unbounded = ReportRange();

  final DateTime? from;
  final DateTime? to;

  bool contains(DateTime d) =>
      (from == null || !d.isBefore(from!)) && (to == null || d.isBefore(to!));

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'ReportRange($from, $to)';
}

/// The period picked in the Filter screen. [customFrom]/[customTo] are the
/// inclusive days of a custom range (only used when [kind] is custom).
class ReportPeriod {
  const ReportPeriod(this.kind, {this.customFrom, this.customTo})
    : assert(
        kind != ReportPeriodKind.custom ||
            (customFrom != null && customTo != null),
        'A custom period needs both dates',
      );

  /// Custom range covering the whole days [from]..[to] (order-insensitive).
  factory ReportPeriod.custom(DateTime from, DateTime to) {
    final a = dayOf(from);
    final b = dayOf(to);
    return ReportPeriod(
      ReportPeriodKind.custom,
      customFrom: a.isAfter(b) ? b : a,
      customTo: a.isAfter(b) ? a : b,
    );
  }

  /// What "CLEAR FILTERS" goes back to.
  static const defaultPeriod = ReportPeriod(ReportPeriodKind.allTime);

  final ReportPeriodKind kind;
  final DateTime? customFrom;
  final DateTime? customTo;

  String get label => kind.label;

  /// The window this period covers when it's [now].
  ReportRange rangeAt(DateTime now) {
    final today = dayOf(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    DateTime monthsBack(int n) {
      final d = addMonths(today, -n);
      return DateTime(d.year, d.month, d.day + 1);
    }

    return switch (kind) {
      ReportPeriodKind.currentMonth => ReportRange(
        from: DateTime(today.year, today.month),
        to: DateTime(today.year, today.month + 1),
      ),
      ReportPeriodKind.previousMonth => ReportRange(
        from: DateTime(today.year, today.month - 1),
        to: DateTime(today.year, today.month),
      ),
      ReportPeriodKind.lastMonth => ReportRange(
        from: DateTime(today.year, today.month, today.day - 29),
        to: tomorrow,
      ),
      ReportPeriodKind.last3Months => ReportRange(
        from: monthsBack(3),
        to: tomorrow,
      ),
      ReportPeriodKind.last6Months => ReportRange(
        from: monthsBack(6),
        to: tomorrow,
      ),
      ReportPeriodKind.lastYear => ReportRange(
        from: monthsBack(12),
        to: tomorrow,
      ),
      ReportPeriodKind.allTime => ReportRange.unbounded,
      ReportPeriodKind.custom => ReportRange(
        from: dayOf(customFrom!),
        to: DateTime(customTo!.year, customTo!.month, customTo!.day + 1),
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.customFrom == customFrom &&
      other.customTo == customTo;

  @override
  int get hashCode => Object.hash(kind, customFrom, customTo);
}

/// The inclusive days a report actually covers — shown on the period card
/// ("17 entries (2025-06-11 - 2026-09-17)") and used for every "by day"
/// average, so the two always agree.
class DateSpan {
  const DateSpan(this.start, this.end);

  /// First day (midnight).
  final DateTime start;

  /// Last day (midnight), inclusive.
  final DateTime end;

  /// Number of days, both ends included (≥ 1).
  int get days => daysBetween(start, end) + 1;

  @override
  bool operator ==(Object other) =>
      other is DateSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateSpan($start – $end)';
}

/// The days [range] effectively covers for a vehicle, or null when there's
/// nothing to cover (no records at all, or a range entirely in the future).
///
/// Why not just `[from, to)`: averaging over days the vehicle wasn't tracked
/// yet, or over days that haven't happened, would understate "by day".
/// - start = the range start, but never before [trackingStart] (the
///   vehicle's first record ever); all time starts at [trackingStart].
/// - end = the range end, but never after today; all time ends at
///   [lastRecord] (like Drivvo's label). A record dated after today still
///   extends the span, so a counted record is never outside it.
DateSpan? reportSpan(
  ReportRange range, {
  required DateTime now,
  DateTime? trackingStart,
  DateTime? lastRecord,
}) {
  final tracked = trackingStart == null ? null : dayOf(trackingStart);
  var start = range.from == null ? tracked : dayOf(range.from!);
  if (start == null) return null;
  if (tracked != null && tracked.isAfter(start)) start = tracked;

  final today = dayOf(now);
  final last = lastRecord == null ? null : dayOf(lastRecord);
  DateTime end; // inclusive
  if (range.to == null) {
    end = last ?? today;
  } else {
    final lastInRange = DateTime(
      range.to!.year,
      range.to!.month,
      range.to!.day - 1,
    );
    var cap = today;
    if (last != null && last.isAfter(cap)) cap = last;
    end = lastInRange.isAfter(cap) ? cap : lastInRange;
  }
  if (end.isBefore(start)) return null;
  return DateSpan(start, end);
}
