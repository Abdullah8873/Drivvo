import '../db/tables.dart' show PeriodUnit;

/// One known (date, odometer) reading of a vehicle — from a refueling,
/// expense/service, reading or route. A Dart "record" type, like a TS tuple
/// type with named fields.
typedef OdometerPoint = ({DateTime date, double odometer});

/// How urgent a reminder is.
enum ReminderStatus { ok, soon, overdue }

/// The trigger settings of a reminder, copied from the `Reminders` row so the
/// math stays independent of the database classes.
class ReminderSchedule {
  const ReminderSchedule({
    required this.repeat,
    this.byDistance = false,
    this.dueOdometer,
    this.everyDistance,
    this.byDate = false,
    this.dueDate,
    this.everyAmount,
    this.everyUnit,
  });

  /// false = "just one time", true = "repeat every".
  final bool repeat;
  final bool byDistance;
  final double? dueOdometer;
  final double? everyDistance;
  final bool byDate;
  final DateTime? dueDate;
  final int? everyAmount;
  final PeriodUnit? everyUnit;
}

/// Where a repeating interval starts counting from (the last time the
/// service/expense was done).
typedef Baseline = ({DateTime date, double? odometer});

/// Result of [ReminderMath.evaluate]: when the reminder is due and how far
/// away that is.
class ReminderDue {
  const ReminderDue({
    this.dueOdometer,
    this.dueDate,
    this.remainingDistance,
    this.remainingDays,
    this.predictedDate,
    this.displayDate,
    this.displayDays,
    required this.status,
    this.progress,
  });

  /// Odometer at which the distance trigger fires (null = no distance trigger).
  final double? dueOdometer;

  /// Date at which the date trigger fires (null = no date trigger).
  final DateTime? dueDate;

  /// `dueOdometer - currentOdometer` (negative = overdue).
  final double? remainingDistance;

  /// Whole calendar days until [dueDate] (negative = overdue).
  final int? remainingDays;

  /// When the distance trigger is expected to fire, from the average
  /// distance driven per day.
  final DateTime? predictedDate;

  /// The date to show: the earlier of [dueDate] and [predictedDate]
  /// ("whichever comes first").
  final DateTime? displayDate;

  /// Whole days until [displayDate].
  final int? displayDays;
  final ReminderStatus status;

  /// 0..1 — how much of the interval has been used up (for a progress bar).
  final double? progress;
}

/// Pure reminder / prediction math (no Flutter, no database) so it can be
/// unit tested in isolation. Screens and providers call these functions.
class ReminderMath {
  ReminderMath._();

  /// How many recent days of history [averageDistancePerDay] looks at.
  static const averageWindowDays = 90;

  /// Strips the time part, so day differences count calendar days.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) {
    // Use UTC dates so daylight-saving shifts don't produce 23h "days".
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// [from] plus [amount] days / months / years. Month and year steps clamp
  /// to the last day of the month (31 jan + 1 month = 28/29 feb).
  static DateTime addPeriod(DateTime from, int amount, PeriodUnit unit) {
    switch (unit) {
      case PeriodUnit.day:
        return DateTime(
          from.year,
          from.month,
          from.day + amount,
          from.hour,
          from.minute,
        );
      case PeriodUnit.month:
      case PeriodUnit.year:
        final months = unit == PeriodUnit.month ? amount : amount * 12;
        final firstOfTarget = DateTime(from.year, from.month + months);
        // Day 0 of the next month = last day of this month.
        final lastDay = DateTime(
          firstOfTarget.year,
          firstOfTarget.month + 1,
          0,
        ).day;
        return DateTime(
          firstOfTarget.year,
          firstOfTarget.month,
          from.day > lastDay ? lastDay : from.day,
          from.hour,
          from.minute,
        );
    }
  }

  /// Average distance driven per day. Uses the last [averageWindowDays] of
  /// history (ending at the newest point) when that window holds at least
  /// two points spanning a day or more, otherwise all points.
  /// Returns null when there isn't enough data (fewer than two points on
  /// different days).
  static double? averageDistancePerDay(List<OdometerPoint> points) {
    if (points.length < 2) return null;
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final newest = sorted.last.date;
    final windowStart = newest.subtract(
      const Duration(days: averageWindowDays),
    );
    final recent = sorted.where((p) => !p.date.isBefore(windowStart)).toList();
    return _rate(recent) ?? _rate(sorted);
  }

  static double? _rate(List<OdometerPoint> sorted) {
    if (sorted.length < 2) return null;
    final days = daysBetween(sorted.first.date, sorted.last.date);
    if (days <= 0) return null;
    // Odometers can be logged out of order; use the range seen.
    final odos = sorted.map((p) => p.odometer);
    final distance =
        odos.reduce((a, b) => a > b ? a : b) -
        odos.reduce((a, b) => a < b ? a : b);
    return distance / days;
  }

  /// The highest odometer known on or before [date], or null.
  static double? odometerAt(List<OdometerPoint> points, DateTime date) {
    double? best;
    for (final p in points) {
      if (p.date.isAfter(date)) continue;
      if (best == null || p.odometer > best) best = p.odometer;
    }
    return best;
  }

  /// Picks where a reminder's interval starts:
  /// 1. the latest logged service/expense of the reminder's type
  ///    ([lastLogged]) — this is the auto-reschedule: logging the service
  ///    moves the next due point without editing the reminder;
  /// 2. otherwise the baseline stored on the reminder when it was created
  ///    ([storedOdometer] / [storedDate]);
  /// 3. otherwise the creation date and the odometer known at that time,
  ///    falling back to [currentOdometer].
  static Baseline resolveBaseline({
    Baseline? lastLogged,
    double? storedOdometer,
    DateTime? storedDate,
    required DateTime createdAt,
    double? currentOdometer,
    List<OdometerPoint> history = const [],
  }) {
    if (lastLogged != null) {
      return (
        date: lastLogged.date,
        odometer:
            lastLogged.odometer ??
            odometerAt(history, lastLogged.date) ??
            currentOdometer,
      );
    }
    final date = storedDate ?? createdAt;
    return (
      date: date,
      odometer: storedOdometer ?? odometerAt(history, date) ?? currentOdometer,
    );
  }

  /// Next due odometer/date. One-time reminders use their fixed values;
  /// repeating ones add the interval to the [baseline].
  static ({double? odometer, DateTime? date}) nextDue(
    ReminderSchedule s,
    Baseline baseline,
  ) {
    if (!s.repeat) {
      return (
        odometer: s.byDistance ? s.dueOdometer : null,
        date: s.byDate ? s.dueDate : null,
      );
    }
    final odo =
        s.byDistance && s.everyDistance != null && baseline.odometer != null
        ? baseline.odometer! + s.everyDistance!
        : null;
    final date = s.byDate && s.everyAmount != null && s.everyUnit != null
        ? addPeriod(baseline.date, s.everyAmount!, s.everyUnit!)
        : null;
    return (odometer: odo, date: date);
  }

  /// Status from the remaining distance/days: overdue once the odometer is
  /// reached or the date has passed; "soon" within the warn-ahead settings.
  static ReminderStatus status({
    double? remainingDistance,
    int? remainingDays,
    required num distanceAhead,
    required int daysAhead,
  }) {
    if ((remainingDistance != null && remainingDistance <= 0) ||
        (remainingDays != null && remainingDays < 0)) {
      return ReminderStatus.overdue;
    }
    if ((remainingDistance != null && remainingDistance <= distanceAhead) ||
        (remainingDays != null && remainingDays <= daysAhead)) {
      return ReminderStatus.soon;
    }
    return ReminderStatus.ok;
  }

  /// Full evaluation of one reminder at [now].
  static ReminderDue evaluate({
    required ReminderSchedule schedule,
    required Baseline baseline,
    required DateTime now,
    double? currentOdometer,
    double? avgDistancePerDay,
    required num distanceAhead,
    required int daysAhead,
  }) {
    final due = nextDue(schedule, baseline);
    return _describe(
      dueOdometer: due.odometer,
      dueDate: due.date,
      baseline: baseline,
      now: now,
      currentOdometer: currentOdometer,
      avgDistancePerDay: avgDistancePerDay,
      distanceAhead: distanceAhead,
      daysAhead: daysAhead,
    );
  }

  static ReminderDue _describe({
    double? dueOdometer,
    DateTime? dueDate,
    required Baseline baseline,
    required DateTime now,
    double? currentOdometer,
    double? avgDistancePerDay,
    required num distanceAhead,
    required int daysAhead,
  }) {
    final remainingDistance = dueOdometer != null && currentOdometer != null
        ? dueOdometer - currentOdometer
        : null;
    final remainingDays = dueDate == null ? null : daysBetween(now, dueDate);

    DateTime? predicted;
    if (remainingDistance != null &&
        avgDistancePerDay != null &&
        avgDistancePerDay > 0) {
      final days = remainingDistance <= 0
          ? 0
          : (remainingDistance / avgDistancePerDay).round();
      predicted = dateOnly(now).add(Duration(days: days));
    }

    final displayDate = switch ((dueDate, predicted)) {
      (null, null) => null,
      (final d?, null) => d,
      (null, final p?) => p,
      (final d?, final p?) => d.isBefore(p) ? d : p,
    };

    // Progress: share of the interval used, by distance and/or by time.
    double? progress;
    void consider(double used, double total) {
      if (total <= 0) return;
      final p = (used / total).clamp(0.0, 1.0);
      if (progress == null || p > progress!) progress = p;
    }

    if (dueOdometer != null &&
        currentOdometer != null &&
        baseline.odometer != null) {
      consider(
        currentOdometer - baseline.odometer!,
        dueOdometer - baseline.odometer!,
      );
    }
    if (dueDate != null) {
      consider(
        now.difference(baseline.date).inMinutes.toDouble(),
        dueDate.difference(baseline.date).inMinutes.toDouble(),
      );
    }

    return ReminderDue(
      dueOdometer: dueOdometer,
      dueDate: dueDate,
      remainingDistance: remainingDistance,
      remainingDays: remainingDays,
      predictedDate: predicted,
      displayDate: displayDate,
      displayDays: displayDate == null ? null : daysBetween(now, displayDate),
      status: status(
        remainingDistance: remainingDistance,
        remainingDays: remainingDays,
        distanceAhead: distanceAhead,
        daysAhead: daysAhead,
      ),
      progress: progress,
    );
  }

  /// Averages between consecutive refuelings, and the predicted next one
  /// (after the last refuel). Null with fewer than two refuelings.
  static ({double avgDistance, double avgDays, double odometer, DateTime date})?
  predictNextRefueling(List<OdometerPoint> refuels) {
    if (refuels.length < 2) return null;
    final sorted = [...refuels]..sort((a, b) => a.date.compareTo(b.date));
    final intervals = sorted.length - 1;
    final avgDistance =
        (sorted.last.odometer - sorted.first.odometer) / intervals;
    final avgDays =
        sorted.last.date.difference(sorted.first.date).inMinutes /
        Duration.minutesPerDay /
        intervals;
    if (avgDistance <= 0 && avgDays <= 0) return null;
    return (
      avgDistance: avgDistance,
      avgDays: avgDays,
      odometer: sorted.last.odometer + avgDistance,
      date: dateOnly(sorted.last.date).add(Duration(days: avgDays.round())),
    );
  }

  /// Evaluates the "Next refueling" prediction like a reminder. It is
  /// "soon" within 20% of a typical refuel interval (min 1 day).
  static ReminderDue? evaluateNextRefueling({
    required List<OdometerPoint> refuels,
    required DateTime now,
    double? currentOdometer,
  }) {
    final next = predictNextRefueling(refuels);
    if (next == null) return null;
    final last = refuels.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    return _describe(
      dueOdometer: next.odometer,
      dueDate: next.date,
      baseline: (date: last.date, odometer: last.odometer),
      now: now,
      currentOdometer: currentOdometer ?? last.odometer,
      distanceAhead: next.avgDistance * 0.2,
      daysAhead: (next.avgDays * 0.2).ceil().clamp(1, 1 << 30),
    );
  }
}
