/// Calendar-aligned ticks for a chart's date axis.
///
/// Evenly spaced ticks (range ÷ 3) land on arbitrary dates like "11 oct"
/// that match no record, so users think their dates are wrong. Like Drivvo,
/// ticks here sit on calendar boundaries: month starts labelled with the year
/// ("2025-06"), every 1, 3, 6 or 12 months (then 2, 5, 10 years) — the
/// smallest step whose ticks fit in the space — or, for ranges shorter than
/// about two months, whole days ("2025-06-11") every 1, 2, 3, 7 or 14 days.
library;

/// Whether the ticks are month starts or days.
enum DateTickUnit { month, day }

/// The ticks for one axis, in ascending order, and how to label them.
class DateAxisTicks {
  const DateAxisTicks(this.ticks, this.unit, this.step);

  /// Local midnights (the 1st of a month for [DateTickUnit.month]).
  final List<DateTime> ticks;
  final DateTickUnit unit;

  /// Months or days between two ticks.
  final int step;

  /// "2025-06" for months, "2025-06-11" for days.
  String label(DateTime d) {
    final ym = '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}';
    return unit == DateTickUnit.month ? ym : '$ym-${_two(d.day)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Month steps tried in order; 12 and up only tick in January.
  static const monthSteps = [1, 3, 6, 12, 24, 60, 120];

  /// Day steps for short ranges.
  static const daySteps = [1, 2, 3, 7, 14];

  /// Picks the ticks for [start]..[end] (inclusive).
  ///
  /// [maxMonthTicks] / [maxDayTicks] are how many labels of each kind fit
  /// side by side without overlapping (day labels are longer). Month starts
  /// are used whenever at least two of them fall in the range; otherwise
  /// days, and if even the widest day step doesn't fit, the single month
  /// start in range. A range with no calendar boundary at all (under a day)
  /// gets one tick: the day it's on.
  static DateAxisTicks compute(
    DateTime start,
    DateTime end, {
    required int maxMonthTicks,
    required int maxDayTicks,
  }) {
    if (end.isBefore(start)) (start, end) = (end, start);
    final maxMonths = maxMonthTicks < 1 ? 1 : maxMonthTicks;
    final maxDays = maxDayTicks < 1 ? 1 : maxDayTicks;

    final everyMonth = _monthTicks(start, end, 1);
    if (everyMonth.length >= 2) {
      for (final step in monthSteps) {
        final ticks = step == 1 ? everyMonth : _monthTicks(start, end, step);
        if (ticks.length <= maxMonths) {
          return DateAxisTicks(ticks, DateTickUnit.month, step);
        }
      }
      // Centuries of data: keep the widest step, thinned to fit.
      final step = monthSteps.last;
      final ticks = _monthTicks(start, end, step);
      final every = (ticks.length / maxMonths).ceil();
      return DateAxisTicks(
        [for (var i = 0; i < ticks.length; i += every) ticks[i]],
        DateTickUnit.month,
        step * every,
      );
    }

    for (final step in daySteps) {
      final ticks = _dayTicks(start, end, step);
      if (ticks.isNotEmpty && ticks.length <= maxDays) {
        return DateAxisTicks(ticks, DateTickUnit.day, step);
      }
    }
    if (everyMonth.isNotEmpty) {
      return DateAxisTicks(everyMonth, DateTickUnit.month, 1);
    }
    final days = _dayTicks(start, end, daySteps.last);
    if (days.isNotEmpty) {
      return DateAxisTicks([days.first], DateTickUnit.day, daySteps.last);
    }
    return DateAxisTicks(
      [DateTime(start.year, start.month, start.day)],
      DateTickUnit.day,
      1,
    );
  }

  /// Month starts in [start]..[end] whose month index is a multiple of
  /// [step] (so a 3-month step ticks Jan/Apr/Jul/Oct, 6 → Jan/Jul, 12 →
  /// Jan, 24 → Jan of even years).
  static List<DateTime> _monthTicks(DateTime start, DateTime end, int step) {
    var index = start.year * 12 + start.month - 1;
    // The 1st of start's month is only in range if start is exactly on it.
    if (DateTime(start.year, start.month).isBefore(start)) index++;
    final rem = index % step;
    if (rem != 0) index += step - rem;
    final last = end.year * 12 + end.month - 1;
    return [
      for (var i = index; i <= last; i += step) DateTime(i ~/ 12, i % 12 + 1),
    ];
  }

  /// Local midnights in [start]..[end], every [step] days counted from
  /// 1970-01-01 (so ticks don't move when the range changes a little).
  static List<DateTime> _dayTicks(DateTime start, DateTime end, int step) {
    var day = DateTime(start.year, start.month, start.day);
    if (day.isBefore(start)) day = DateTime(day.year, day.month, day.day + 1);
    final offset = _epochDay(day) % step;
    if (offset != 0) {
      day = DateTime(day.year, day.month, day.day + step - offset);
    }
    return [
      for (
        var d = day;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + step)
      )
        d,
    ];
  }

  /// Calendar day number (ignores the time zone offset and DST).
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}
