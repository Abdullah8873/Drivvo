import '../../core/calc/achievements.dart';
import 'history_calc.dart';
import 'history_queries.dart';

/// One row the History timeline can render: a real record or an earned
/// achievement shown on its earned date (Drivvo's "Completed 1 year of
/// tracking this vehicle" style events). This is a *presentation-only*
/// union — [MonthSummary] (totals, distance, efficiency…) is built from
/// [TimelineRecord]s alone; achievement events are merged in afterwards, so
/// they can never change a total, count, average or report (see
/// `mergeAchievements`, and `test/history_achievement_test.dart` for the
/// proof).
sealed class TimelineItem {
  const TimelineItem();

  DateTime get date;
}

class RecordItem extends TimelineItem {
  const RecordItem(this.record);

  final TimelineRecord record;

  @override
  DateTime get date => record.date;
}

class AchievementItem extends TimelineItem {
  const AchievementItem(this.achievement);

  final Achievement achievement;

  @override
  DateTime get date => achievement.earnedDate!;
}

/// Merges [month]'s real records with the [achievements] earned in that
/// same calendar month, newest first (matching the timeline's own order).
/// Only earned achievements whose date falls in [month.month] are included;
/// an achievement earned in a month with no other records never gets a row
/// (there is no month card to anchor it to).
List<TimelineItem> mergeAchievements(
  MonthSummary month,
  List<Achievement> achievements,
) {
  final items = <TimelineItem>[
    for (final r in month.records) RecordItem(r),
    for (final a in achievements)
      if (a.earned && monthOf(a.earnedDate!) == month.month) AchievementItem(a),
  ];
  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
}
