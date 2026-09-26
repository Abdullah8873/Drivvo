import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/features/readings/reading_math.dart';

void main() {
  test('no readings', () {
    final s = ReadingMath.stats(const []);
    expect(s.count, 0);
    expect(s.distance, 0);
    expect(s.dailyAverage, isNull);
    expect(s.averageDaysBetween, isNull);
  });

  test('single reading has no averages', () {
    final s = ReadingMath.stats([(date: DateTime(2026, 9, 1), odometer: 500)]);
    expect(s.count, 1);
    expect(s.distance, 0);
    expect(s.dailyAverage, isNull);
    expect(s.averageDaysBetween, isNull);
  });

  test('distance, daily average and days between (order-independent)', () {
    final s = ReadingMath.stats([
      (date: DateTime(2026, 9, 11, 9), odometer: 1300),
      (date: DateTime(2026, 9, 1, 22), odometer: 1000),
      (date: DateTime(2026, 9, 5, 7), odometer: 1100),
    ]);
    expect(s.count, 3);
    expect(s.distance, 300);
    expect(s.days, 10);
    expect(s.dailyAverage, 30);
    expect(s.averageDaysBetween, 5);
  });
}
