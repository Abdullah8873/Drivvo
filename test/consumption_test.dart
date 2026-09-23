import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/consumption.dart';
import 'package:motolog/core/settings/app_settings.dart';

RefuelSample r(
  String id,
  DateTime date,
  double odo,
  double volume, {
  double? cost,
  bool full = true,
  bool missed = false,
}) => RefuelSample(
  id: id,
  date: date,
  odometer: odo,
  volume: volume,
  cost: cost ?? volume * 300,
  fullTank: full,
  missedPrevious: missed,
);

/// A realistic motorcycle log (dates in Aug 2026, PKR 300/L unless noted).
final dataset = [
  r('r1', DateTime(2026, 8, 1), 54682, 7.368),
  r('r2', DateTime(2026, 8, 6), 54985, 5.063), // closes 303 km / 5.063 L
  r('r3', DateTime(2026, 8, 10), 55150, 2.0, full: false), // partial
  r('r4', DateTime(2026, 8, 14), 55300, 4.5, cost: 1440), // 315 / 6.5 L
  r('r5', DateTime(2026, 8, 20), 55500, 3.0, missed: true), // chain break
  r('r6', DateTime(2026, 8, 25), 55700, 4.0), // 200 km / 4 L
  r('r7', DateTime(2026, 8, 28), 55800, 1.5, full: false), // open cycle
];

void main() {
  group('ConsumptionStats.compute — cycles', () {
    final stats = ConsumptionStats.compute(dataset.reversed); // any order

    test('sorts oldest first and computes distance since previous', () {
      expect(stats.results.map((x) => x.refuel.id), [
        'r1',
        'r2',
        'r3',
        'r4',
        'r5',
        'r6',
        'r7',
      ]);
      expect(stats.results.first.distanceSincePrevious, isNull);
      expect(stats.results[1].distanceSincePrevious, 303);
      expect(stats.results[3].distanceSincePrevious, 150);
    });

    test('measures full-to-full cycles, accumulating partial fills', () {
      expect(stats.cycles, hasLength(3));
      final c1 = stats.cycles[0];
      expect(c1.start.id, 'r1');
      expect(c1.end.id, 'r2');
      expect(c1.distance, 303);
      expect(c1.efficiency, closeTo(59.846, 0.001));

      final c2 = stats.cycles[1];
      expect((c2.start.id, c2.end.id), ('r2', 'r4'));
      expect(c2.distance, 315);
      expect(c2.volume, closeTo(6.5, 1e-9)); // 2.0 partial + 4.5
      expect(c2.efficiency, closeTo(48.4615, 0.0001));
      expect(c2.cost, closeTo(600 + 1440, 1e-9));
      expect(c2.costPerDistance, closeTo(2040 / 315, 1e-9));
    });

    test('a missed refuel breaks the chain and becomes the new baseline', () {
      // No cycle ends on r5; r5 → r6 is measured.
      expect(stats.cycles.any((c) => c.end.id == 'r5'), isFalse);
      final c3 = stats.cycles[2];
      expect((c3.start.id, c3.end.id), ('r5', 'r6'));
      expect(c3.efficiency, 50);
    });

    test('cycleStart shows the efficiency on the refuel that starts it', () {
      final eff = {for (final x in stats.results) x.refuel.id: x.efficiency};
      expect(eff['r1'], closeTo(59.846, 0.001));
      expect(eff['r2'], closeTo(48.4615, 0.0001));
      expect(eff['r3'], isNull);
      expect(eff['r4'], isNull); // its cycle was broken by r5
      expect(eff['r5'], 50);
      expect(eff['r6'], isNull); // still open
      expect(eff['r7'], isNull);
    });

    test('cycleEnd shows it on the refuel that closes it', () {
      final end = ConsumptionStats.compute(
        dataset,
        position: EconomyPosition.cycleEnd,
      );
      final eff = {for (final x in end.results) x.refuel.id: x.efficiency};
      expect(eff['r1'], isNull);
      expect(eff['r2'], closeTo(59.846, 0.001));
      expect(eff['r4'], closeTo(48.4615, 0.0001));
      expect(eff['r5'], isNull);
      expect(eff['r6'], 50);
      expect(end.resultFor('r4')!.costPerDistance, closeTo(2040 / 315, 1e-9));
    });
  });

  group('ConsumptionStats aggregates', () {
    final stats = ConsumptionStats.compute(dataset);

    test('average efficiency is total cycle distance / total cycle volume', () {
      expect(stats.averageEfficiency, closeTo(818 / 15.563, 1e-9));
      expect(stats.bestEfficiency, closeTo(59.846, 0.001));
      expect(stats.worstEfficiency, closeTo(48.4615, 0.0001));
      expect(stats.lastEfficiency, 50);
    });

    test('routine: full-tank %, distance and days between refuels', () {
      expect(stats.count, 7);
      expect(stats.fullTankRatio, closeTo(5 / 7, 1e-9));
      expect(stats.trackedDistance, 1118);
      expect(stats.averageDistanceBetween, closeTo(1118 / 6, 1e-9));
      expect(stats.averageDaysBetween, closeTo(27 / 6, 1e-9));
    });

    test('prices and cost per distance', () {
      final totalVolume = 7.368 + 5.063 + 2 + 4.5 + 3 + 4 + 1.5;
      expect(stats.totalVolume, closeTo(totalVolume, 1e-9));
      final totalCost = (totalVolume - 4.5) * 300 + 1440;
      expect(stats.totalCost, closeTo(totalCost, 1e-6));
      expect(stats.averagePricePerUnit, closeTo(totalCost / totalVolume, 1e-9));
      expect(stats.lowestPricePerUnit, closeTo(300, 1e-9));
      expect(stats.highestPricePerUnit, closeTo(320, 1e-9));
      final cycleCost = 5.063 * 300 + 2040 + 4 * 300;
      expect(stats.costPerDistance, closeTo(cycleCost / 818, 1e-9));
      expect(stats.estimatedRange(10), closeTo(818 / 15.563 * 10, 1e-9));
      expect(stats.estimatedRange(null), isNull);
    });
  });

  group('edge cases', () {
    test('no refuels → empty stats with null aggregates', () {
      final s = ConsumptionStats.compute(const []);
      expect(s.isEmpty, isTrue);
      expect(s.averageEfficiency, isNull);
      expect(s.fullTankRatio, isNull);
      expect(s.averageDaysBetween, isNull);
    });

    test('first refuel alone has no efficiency', () {
      final s = ConsumptionStats.compute([dataset.first]);
      expect(s.results.single.efficiency, isNull);
      expect(s.results.single.distanceSincePrevious, isNull);
      expect(s.cycles, isEmpty);
    });

    test('partials before the first full tank are ignored', () {
      final s = ConsumptionStats.compute([
        r('a', DateTime(2026, 1, 1), 100, 3, full: false),
        r('b', DateTime(2026, 1, 2), 200, 5),
        r('c', DateTime(2026, 1, 3), 300, 4),
      ]);
      expect(s.cycles.single.start.id, 'b');
      expect(s.cycles.single.efficiency, 25);
    });

    test('a missed partial fill waits for the next full tank', () {
      final s = ConsumptionStats.compute([
        r('a', DateTime(2026, 1, 1), 100, 5),
        r('b', DateTime(2026, 1, 2), 200, 2, full: false, missed: true),
        r('c', DateTime(2026, 1, 3), 300, 4), // new baseline, no cycle
        r('d', DateTime(2026, 1, 4), 400, 5), // 100 km / 5 L
      ]);
      expect(s.cycles.single.start.id, 'c');
      expect(s.cycles.single.efficiency, 20);
    });

    test('same-day refuels are ordered by odometer', () {
      final day = DateTime(2026, 1, 1);
      final s = ConsumptionStats.compute([
        r('b', day, 250, 5),
        r('a', day, 100, 5),
      ]);
      expect(s.results.map((x) => x.refuel.id), ['a', 'b']);
      expect(s.cycles.single.efficiency, 30);
    });

    test('non-increasing odometer yields no cycle', () {
      final s = ConsumptionStats.compute([
        r('a', DateTime(2026, 1, 1), 300, 5),
        r('b', DateTime(2026, 1, 2), 300, 5),
      ]);
      expect(s.cycles, isEmpty);
    });

    test('a backwards odometer is not used as the next baseline', () {
      final s = ConsumptionStats.compute([
        r('a', DateTime(2026, 1, 1), 1000, 5),
        r('b', DateTime(2026, 1, 2), 900, 5), // typo: odometer went back
        r('c', DateTime(2026, 1, 3), 1400, 5), // new baseline, no cycle
        r('d', DateTime(2026, 1, 4), 1700, 6), // 300 km / 6 L
      ]);
      expect(s.cycles.map((c) => (c.start.id, c.end.id)), [('c', 'd')]);
      expect(s.cycles.single.efficiency, 50);
    });
  });
}
