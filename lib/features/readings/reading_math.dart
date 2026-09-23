/// Pure reading (odometer update) statistics for the Reading report card.
library;

/// One reading's numbers. Build it from a drift `Reading` with `reading.point`
/// in `reading_queries.dart`.
typedef ReadingPoint = ({DateTime date, double odometer});

class ReadingStats {
  const ReadingStats({
    this.count = 0,
    this.distance = 0,
    this.days = 0,
    this.dailyAverage,
    this.averageDaysBetween,
  });

  final int count;

  /// Last odometer − first odometer across the readings.
  final double distance;

  /// Calendar days between the first and last reading.
  final int days;

  /// Distance per day, or null with fewer than two readings on different days.
  final double? dailyAverage;

  /// Average days between consecutive readings, or null with < 2 readings.
  final double? averageDaysBetween;
}

class ReadingMath {
  ReadingMath._();

  static ReadingStats stats(Iterable<ReadingPoint> readings) {
    final sorted = readings.toList()..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return const ReadingStats();
    final first = sorted.first, last = sorted.last;
    final distance = last.odometer - first.odometer;
    // Compare calendar dates so 23:00 → 01:00 next day counts as 1 day.
    final days = _dateOnly(last.date).difference(_dateOnly(first.date)).inDays;
    return ReadingStats(
      count: sorted.length,
      distance: distance,
      days: days,
      dailyAverage: days > 0 ? distance / days : null,
      averageDaysBetween: sorted.length > 1 ? days / (sorted.length - 1) : null,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
