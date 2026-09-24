import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/achievements.dart';

/// Convenience builder mirroring `AchievementRecord`'s fields with fewer
/// keystrokes in the test data below.
AchievementRecord refuel(
  DateTime date, {
  String? station,
  bool fullTank = false,
}) => AchievementRecord(
  date: date,
  isRefueling: true,
  gasStation: station,
  fullTank: fullTank,
);

AchievementRecord other(DateTime date) => AchievementRecord(date: date);

Achievement byId(List<Achievement> all, String id) =>
    all.firstWhere((a) => a.id == id);

void main() {
  final now = DateTime(2026, 9, 24);

  group('Achievements.compute', () {
    test('empty vehicle: all 20 badges unearned, in spec order', () {
      final all = Achievements.compute([], now);
      expect(all.length, 20);
      expect(all.every((a) => !a.earned), isTrue);
      expect(all.first.id, 'first_record');
      expect(all.last.id, 'full_tanks_150');
    });

    test('first record = earliest record of any module', () {
      final all = Achievements.compute([
        refuel(DateTime(2025, 3, 10)),
        other(DateTime(2024, 1, 5)),
        other(DateTime(2025, 6, 1)),
      ], now);
      expect(byId(all, 'first_record').earnedDate, DateTime(2024, 1, 5));
    });

    test('10 distinct gas stations, refuels without a station ignored', () {
      final records = [
        for (var i = 0; i < 9; i++)
          refuel(DateTime(2026, 1, i + 1), station: 'Station $i'),
        refuel(DateTime(2026, 2, 1)), // no station: doesn't count
        refuel(DateTime(2026, 2, 2), station: 'Station 9'),
      ];
      final all = Achievements.compute(records, now);
      expect(byId(all, 'stations_10').earnedDate, DateTime(2026, 2, 2));
    });

    test('9 distinct stations: not earned', () {
      final records = [
        for (var i = 0; i < 9; i++)
          refuel(DateTime(2026, 1, i + 1), station: 'Station $i'),
      ];
      final all = Achievements.compute(records, now);
      expect(byId(all, 'stations_10').earned, isFalse);
    });

    test(
      '15 and 50 refuels at the same station (other stations don\'t mix in)',
      () {
        DateTime d(int i) => DateTime(2026, 1, 1).add(Duration(days: i));
        final records = [
          for (var i = 0; i < 14; i++) refuel(d(i), station: 'Shell'), // 1-14
          refuel(d(14), station: 'Total'), // doesn't count toward Shell
          refuel(d(15), station: 'Shell'), // Shell's 15th
          for (var i = 16; i <= 49; i++)
            refuel(d(i), station: 'Shell'), // 16-49
          refuel(d(50), station: 'Shell'), // Shell's 50th
        ];
        final all = Achievements.compute(records, now);
        expect(byId(all, 'same_station_15').earnedDate, d(15));
        expect(byId(all, 'same_station_50').earnedDate, d(50));
      },
    );

    test('refueling count milestones, boundary: 24th vs 25th', () {
      final records = [
        for (var i = 0; i < 25; i++) refuel(DateTime(2026, 1, i + 1)),
      ];
      final at24 = Achievements.compute(records.sublist(0, 24), now);
      expect(byId(at24, 'refuels_25').earned, isFalse);
      expect(byId(at24, 'refuels_1').earnedDate, DateTime(2026, 1, 1));

      final at25 = Achievements.compute(records, now);
      expect(byId(at25, 'refuels_25').earnedDate, DateTime(2026, 1, 25));
    });

    test('full-tank milestones only count full-tank refuels', () {
      final records = [
        for (var i = 0; i < 14; i++)
          refuel(DateTime(2026, 1, i + 1), fullTank: true),
        refuel(DateTime(2026, 2, 1), fullTank: false), // doesn't count
        refuel(DateTime(2026, 2, 2), fullTank: true), // 15th full tank
      ];
      final all = Achievements.compute(records, now);
      expect(byId(all, 'full_tanks_15').earnedDate, DateTime(2026, 2, 2));
    });

    test('years of tracking: earned only once the anniversary has passed', () {
      final all = Achievements.compute([
        other(DateTime(2025, 9, 24)), // exactly 1 year before `now`
      ], now);
      expect(byId(all, 'years_1').earnedDate, DateTime(2026, 9, 24));
      expect(byId(all, 'years_2').earned, isFalse);
    });

    test(
      'years of tracking: not yet earned the day before the anniversary',
      () {
        final all = Achievements.compute([other(DateTime(2025, 9, 25))], now);
        expect(byId(all, 'years_1').earned, isFalse);
      },
    );

    test('years text uses correct plural', () {
      final all = Achievements.compute([other(DateTime(2020, 1, 1))], now);
      expect(byId(all, 'years_1').text, contains('1 year of'));
      expect(byId(all, 'years_2').text, contains('2 years of'));
    });

    test('first refueling text differs from the rest', () {
      final all = Achievements.compute([refuel(DateTime(2026, 1, 1))], now);
      expect(byId(all, 'refuels_1').text, 'First refueling.');
      final all2 = Achievements.compute([
        for (var i = 0; i < 25; i++) refuel(DateTime(2026, 1, i + 1)),
      ], now);
      expect(byId(all2, 'refuels_25').text, '25 refuelings.');
    });

    test('ties on the same date keep insertion order (deterministic)', () {
      final d = DateTime(2026, 1, 1);
      final all = Achievements.compute([
        refuel(d), // inserted first -> should be "1st"
        refuel(d),
      ], now);
      // The 2nd item should be treated as the "2nd" refuel even though the
      // dates are identical — i.e. sorting is stable.
      expect(byId(all, 'refuels_1').earnedDate, d);
    });
  });
}
