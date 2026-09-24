import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/routes/route_math.dart';

void main() {
  final start = DateTime(2026, 9, 1, 8);

  RouteSpan span({
    double startOdo = 1000,
    double? endOdo,
    Duration? duration,
    double? value,
  }) => (
    start: start,
    end: duration == null ? null : start.add(duration),
    startOdometer: startOdo,
    endOdometer: endOdo,
    value: value,
  );

  test('distance and duration are null while the route is open', () {
    expect(RouteMath.distance(1000, null), isNull);
    expect(RouteMath.distance(1000, 1120.5), 120.5);
    expect(RouteMath.durationMinutes(start, null), isNull);
    expect(
      RouteMath.durationMinutes(start, start.add(const Duration(minutes: 95))),
      95,
    );
  });

  test('trip total = distance x value per distance unit', () {
    expect(
      RouteMath.tripTotal(
        startOdometer: 1000,
        endOdometer: 1150,
        valuePerDistance: 12.5,
      ),
      1875,
    );
    expect(
      RouteMath.tripTotal(startOdometer: 1000, valuePerDistance: 12.5),
      isNull,
    );
    expect(RouteMath.tripTotal(startOdometer: 1000, endOdometer: 1150), isNull);
  });

  test('totals skip distance/time of open routes but keep their value', () {
    final t = RouteMath.totals([
      span(endOdo: 1100, duration: const Duration(hours: 2), value: 500),
      span(startOdo: 1100, endOdo: 1150, duration: const Duration(minutes: 30)),
      span(startOdo: 1150, value: 250), // open freight with a value
    ]);
    expect(t.count, 3);
    expect(t.finishedCount, 2);
    expect(t.distance, 150);
    expect(t.minutes, 150);
    expect(t.value, 750);
    // Only the finished routes' value (500) over their distance (150).
    expect(t.valuePerDistance, closeTo(500 / 150, 1e-9));
    expect(t.averageDistance, 75);
  });

  test(
    'value per distance only uses finished routes (same set as distance)',
    () {
      final t = RouteMath.totals([
        span(endOdo: 1100, value: 500), // finished: 100 km, 500
        span(startOdo: 1100, value: 1000), // open: its value has no distance
      ]);
      expect(t.value, 1500); // the Value card still shows every route
      expect(t.finishedValue, 500);
      expect(t.valuePerDistance, 5); // 500 / 100, not 1500 / 100
    },
  );

  test('empty totals', () {
    final t = RouteMath.totals(const []);
    expect(t.count, 0);
    expect(t.valuePerDistance, isNull);
    expect(t.averageDistance, isNull);
  });

  test('formatDuration', () {
    expect(RouteMath.formatDuration(45), '45min');
    expect(RouteMath.formatDuration(125), '2h 05min');
  });
}
