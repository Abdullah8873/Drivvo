/// Pure route math (no Flutter/drift imports, so it's trivially unit-tested).
///
/// A route is "open" while it has no final odometer: it only contributes its
/// value to totals, not distance or time.
library;

/// The numbers of one route that the math needs. Build it from a drift `Route`
/// with the `route.span` getter in `route_queries.dart`.
typedef RouteSpan = ({
  DateTime start,
  DateTime? end,
  double startOdometer,
  double? endOdometer,

  /// Trip total or freight value (null = no value entered).
  double? value,
});

/// Aggregated numbers for the Route report card.
class RouteTotals {
  const RouteTotals({
    this.count = 0,
    this.finishedCount = 0,
    this.distance = 0,
    this.minutes = 0,
    this.value = 0,
    this.finishedValue = 0,
  });

  /// All routes, and how many of them are finished (have a final odometer).
  final int count;
  final int finishedCount;

  /// Sum over finished routes, in the vehicle's distance unit.
  final double distance;

  /// Sum of route durations (finished routes with an end date).
  final int minutes;

  /// Sum of trip totals + freight values (every route, open ones too).
  final double value;

  /// Sum of the values of finished routes only — the routes [distance] is
  /// measured over, so "by km" divides like by like.
  final double finishedValue;

  /// Average value per distance unit over finished routes, or null when
  /// nothing was driven. An open route's value is left out: it has no
  /// distance yet, so counting it would inflate the rate.
  double? get valuePerDistance =>
      distance > 0 ? finishedValue / distance : null;

  /// Average distance per finished route.
  double? get averageDistance =>
      finishedCount > 0 ? distance / finishedCount : null;
}

class RouteMath {
  RouteMath._();

  /// Distance driven, or null while the route is open.
  static double? distance(double startOdometer, double? endOdometer) =>
      endOdometer == null ? null : endOdometer - startOdometer;

  /// Whole minutes between start and end, or null while open.
  static int? durationMinutes(DateTime start, DateTime? end) =>
      end?.difference(start).inMinutes;

  /// Trip mode total: `(final − initial) × value per distance unit`.
  /// Null when either the final odometer or the value is missing.
  static double? tripTotal({
    required double startOdometer,
    double? endOdometer,
    double? valuePerDistance,
  }) {
    final d = distance(startOdometer, endOdometer);
    if (d == null || valuePerDistance == null) return null;
    return d * valuePerDistance;
  }

  /// Sums a list of routes (already filtered to the wanted period).
  static RouteTotals totals(Iterable<RouteSpan> routes) {
    var count = 0, finished = 0, minutes = 0;
    double distanceSum = 0, valueSum = 0, finishedValueSum = 0;
    for (final r in routes) {
      count++;
      valueSum += r.value ?? 0;
      final d = distance(r.startOdometer, r.endOdometer);
      if (d == null) continue; // open route
      finished++;
      distanceSum += d;
      finishedValueSum += r.value ?? 0;
      minutes += durationMinutes(r.start, r.end) ?? 0;
    }
    return RouteTotals(
      count: count,
      finishedCount: finished,
      distance: distanceSum,
      minutes: minutes,
      value: valueSum,
      finishedValue: finishedValueSum,
    );
  }

  /// "2h 05min" / "45min" — compact duration label for route rows/reports.
  static String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h ${m.toString().padLeft(2, '0')}min';
  }
}
