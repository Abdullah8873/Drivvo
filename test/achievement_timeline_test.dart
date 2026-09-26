import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/achievements.dart';
import 'package:motolog/core/theme/record_module.dart';
import 'package:motolog/features/history/achievement_timeline.dart';
import 'package:motolog/features/history/history_calc.dart';
import 'package:motolog/features/history/history_queries.dart';

TimelineRecord record(DateTime date, double amount) => TimelineRecord(
  module: RecordModule.expense,
  id: 'r-${date.millisecondsSinceEpoch}',
  vehicleId: 'v1',
  date: date,
  amount: amount,
);

void main() {
  group('mergeAchievements', () {
    test('never changes the MonthSummary it was built from (totals proof)', () {
      final records = [
        record(DateTime(2026, 3, 15), 1000),
        record(DateTime(2026, 3, 5), 500),
      ];
      final march = groupByMonth(records).single;
      final spentBefore = march.spent;
      expect(spentBefore, 1500);

      final earned = [
        const Achievement(
          id: 'years_2',
          text: 'Completed 2 years of tracking this vehicle.',
          earnedDate: null,
        ),
        Achievement(
          id: 'first_record',
          text: 'Started monitoring your vehicle expenses.',
          earnedDate: DateTime(2026, 3, 10),
        ),
      ];
      final items = mergeAchievements(march, earned);

      // A row was added for the earned achievement, and only for it — but
      // `MonthSummary.spent` (what the month card / reports read) still
      // comes from the same, untouched `records` list.
      expect(items.length, 3);
      expect(items.whereType<AchievementItem>(), hasLength(1));
      expect(march.records.length, 2);
      expect(march.spent, spentBefore);
      expect(march.spent, 1500);
    });

    test('merges newest-first, same order as the timeline', () {
      final records = [
        record(DateTime(2026, 3, 15), 1000),
        record(DateTime(2026, 3, 1), 200),
      ];
      final march = groupByMonth(records).single;
      final earned = [
        Achievement(id: 'a', text: 'x', earnedDate: DateTime(2026, 3, 10)),
      ];
      final items = mergeAchievements(march, earned);

      expect(items.map((i) => i.date), [
        DateTime(2026, 3, 15),
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 1),
      ]);
    });

    test('an achievement earned in a different month is not merged in', () {
      final march = groupByMonth([record(DateTime(2026, 3, 15), 1000)]).single;
      final earned = [
        Achievement(id: 'a', text: 'x', earnedDate: DateTime(2026, 4, 1)),
      ];
      expect(mergeAchievements(march, earned), hasLength(1));
    });

    test('unearned achievements never produce a row', () {
      final march = groupByMonth([record(DateTime(2026, 3, 15), 1000)]).single;
      const unearned = Achievement(id: 'a', text: 'x', earnedDate: null);
      expect(mergeAchievements(march, const [unearned]), hasLength(1));
    });
  });
}
