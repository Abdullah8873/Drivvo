import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/achievements.dart';
import '../../core/theme/record_module.dart';
import '../history/history_providers.dart';
import '../history/history_queries.dart';
import '../reports/report_providers.dart' show reportNowProvider;

/// Maps a History `TimelineRecord` down to the minimal shape
/// `core/calc/achievements.dart` needs — kept here (not in core/calc) so the
/// pure calculator has no dependency on the History feature.
AchievementRecord _toAchievementRecord(TimelineRecord r) => AchievementRecord(
  date: r.date,
  isRefueling: r.module == RecordModule.refueling,
  gasStation: r.module == RecordModule.refueling ? r.place : null,
  fullTank: r.refueling?.fullTank ?? false,
);

/// The 20 achievement badges for one vehicle, live: re-evaluates whenever
/// its timeline changes or "today" moves (so a "years of tracking" badge
/// unlocks itself on its anniversary without the user touching anything).
/// Reuses [reportNowProvider] so achievements and Reports always agree on
/// what day it is, and so tests can pin "today" the same way.
final achievementsProvider = Provider.autoDispose
    .family<AsyncValue<List<Achievement>>, String>((ref, vehicleId) {
      final now = ref.watch(reportNowProvider)();
      return ref
          .watch(timelineProvider(vehicleId))
          .whenData(
            (records) => Achievements.compute([
              for (final r in records) _toAchievementRecord(r),
            ], now),
          );
    });

/// Just the earned badges (non-null [Achievement.earnedDate]), for the
/// History timeline overlay — presentation-only, see
/// `features/history/achievement_timeline.dart`.
final earnedAchievementsProvider = Provider.autoDispose
    .family<List<Achievement>, String>(
      (ref, vehicleId) =>
          ref
              .watch(achievementsProvider(vehicleId))
              .value
              ?.where((a) => a.earned)
              .toList() ??
          const [],
    );
