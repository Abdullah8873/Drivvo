import '../db/tables.dart' show PeriodUnit;
import 'reminder_math.dart';

/// One vehicle record as the achievements calculator needs it — independent
/// of History's `TimelineRecord` so this file stays a pure `core/calc`
/// module (no feature dependencies, no Flutter imports, always unit-tested).
/// The caller is responsible for only passing non-deleted records.
class AchievementRecord {
  const AchievementRecord({
    required this.date,
    this.isRefueling = false,
    this.gasStation,
    this.fullTank = false,
  });

  final DateTime date;

  /// Whether this record is a refueling (the module the fuel/station/full
  /// tank badges care about); every other module only counts toward
  /// "first record".
  final bool isRefueling;

  /// Gas station name of a refueling, or null when none was picked.
  /// Refuels without a station don't count toward the station badges.
  final String? gasStation;

  /// Whether a refueling filled the tank (`Refueling.fullTank`).
  final bool fullTank;
}

/// One of the 20 achievement badges (see `docs/SPEC.md` "Verified hands-on
/// in Drivvo" for the exact wording/order), and whether/when the vehicle
/// earned it.
class Achievement {
  const Achievement({
    required this.id,
    required this.text,
    required this.earnedDate,
  });

  /// Stable id used to look up the badge's icon/shape in the UI, and as a
  /// widget key in tests (e.g. `refuels_25`, `years_1`).
  final String id;

  /// Sentence shown in the badge dialog and the History timeline row.
  final String text;

  /// The date of the record that crossed the achievement's threshold, or
  /// null when it hasn't been earned yet.
  final DateTime? earnedDate;

  bool get earned => earnedDate != null;
}

/// Refuel-count milestones for badges 9–16 (rows 3 and 4 of the grid).
const _refuelMilestones = [1, 25, 50, 75, 100, 250, 500, 1000];

/// Full-tank milestones for badges 17–20 (row 5, the hexagon gauge).
const _fullTankMilestones = [15, 45, 90, 150];

/// Computes the 20 achievements from one vehicle's non-deleted records.
/// Pure and deterministic: same input + [now] always gives the same result,
/// so it's trivial to unit test and to re-run whenever the timeline changes.
class Achievements {
  Achievements._();

  static List<Achievement> compute(List<AchievementRecord> records, DateTime now) {
    if (records.isEmpty) return _badges(firstRecordDate: null, now: now);

    // Stable sort by date (ties keep their original/insertion order) so
    // "the Nth refueling" is deterministic even when several records share
    // a timestamp.
    final indexed = records.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.date.compareTo(b.$2.date);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    final sorted = [for (final e in indexed) e.$2];

    final firstRecordDate = sorted.first.date;
    final refuels = sorted.where((r) => r.isRefueling).toList();

    return _badges(
      firstRecordDate: firstRecordDate,
      now: now,
      tenStationsDate: _nthDistinctStationDate(refuels, 10),
      sameStationDates: _sameStationMilestoneDates(refuels, [15, 50]),
      refuelDates: _milestoneDates(refuels, _refuelMilestones),
      fullTankDates: _milestoneDates(
        refuels.where((r) => r.fullTank).toList(),
        _fullTankMilestones,
      ),
    );
  }

  /// The date of the refuel that brought the count of *distinct* gas
  /// stations used to [n] (refuels without a station are ignored).
  static DateTime? _nthDistinctStationDate(
    List<AchievementRecord> refuels,
    int n,
  ) {
    final seen = <String>{};
    for (final r in refuels) {
      final station = r.gasStation;
      if (station == null || station.isEmpty) continue;
      seen.add(station);
      if (seen.length == n) return r.date;
    }
    return null;
  }

  /// The date each of [milestones] refuelings *at the same station* was
  /// reached (the first station to reach a milestone earns it; every
  /// station is tracked independently). Refuels without a station are
  /// ignored.
  static Map<int, DateTime> _sameStationMilestoneDates(
    List<AchievementRecord> refuels,
    List<int> milestones,
  ) {
    final counts = <String, int>{};
    final found = <int, DateTime>{};
    for (final r in refuels) {
      final station = r.gasStation;
      if (station == null || station.isEmpty) continue;
      final count = (counts[station] ?? 0) + 1;
      counts[station] = count;
      for (final m in milestones) {
        if (count == m && !found.containsKey(m)) found[m] = r.date;
      }
    }
    return found;
  }

  /// The date the Nth record of [records] (already date-sorted) was
  /// reached, for each of [milestones].
  static Map<int, DateTime> _milestoneDates(
    List<AchievementRecord> records,
    List<int> milestones,
  ) {
    final found = <int, DateTime>{};
    for (final (i, r) in records.indexed) {
      final n = i + 1;
      if (milestones.contains(n)) found[n] = r.date;
      if (found.length == milestones.length) break;
    }
    return found;
  }

  /// [firstRecordDate] plus [years] years, or null when that date hasn't
  /// come yet (or there's no first record at all).
  static DateTime? _anniversary(
    DateTime? firstRecordDate,
    int years,
    DateTime now,
  ) {
    if (firstRecordDate == null) return null;
    final target = ReminderMath.addPeriod(firstRecordDate, years, PeriodUnit.year);
    return ReminderMath.dateOnly(target).isAfter(ReminderMath.dateOnly(now))
        ? null
        : target;
  }

  static String _yearsText(int n) =>
      'Completed $n year${n > 1 ? 's' : ''} of tracking this vehicle.';

  static String _refuelText(int n) =>
      n == 1 ? 'First refueling.' : '$n refuelings.';

  static String _fullTankText(int n) => 'Completed $n full tanks.';

  /// Builds the 20 badges in spec order, filling in each earned date from
  /// the (already-computed) lookups — every parameter but [now] is optional
  /// so an empty vehicle still gets the full unearned grid.
  static List<Achievement> _badges({
    required DateTime? firstRecordDate,
    required DateTime now,
    DateTime? tenStationsDate,
    Map<int, DateTime> sameStationDates = const {},
    Map<int, DateTime> refuelDates = const {},
    Map<int, DateTime> fullTankDates = const {},
  }) => [
    // Row 1.
    Achievement(
      id: 'first_record',
      text: 'Started monitoring your vehicle expenses.',
      earnedDate: firstRecordDate,
    ),
    Achievement(
      id: 'stations_10',
      text: 'Refueled at 10 different gas stations.',
      earnedDate: tenStationsDate,
    ),
    Achievement(
      id: 'same_station_15',
      text: 'Refueled 15 times at the same station.',
      earnedDate: sameStationDates[15],
    ),
    Achievement(
      id: 'same_station_50',
      text: 'Refueled 50 times at the same station.',
      earnedDate: sameStationDates[50],
    ),
    // Row 2.
    for (final n in [1, 2, 3, 4])
      Achievement(
        id: 'years_$n',
        text: _yearsText(n),
        earnedDate: _anniversary(firstRecordDate, n, now),
      ),
    // Rows 3–4.
    for (final n in _refuelMilestones)
      Achievement(id: 'refuels_$n', text: _refuelText(n), earnedDate: refuelDates[n]),
    // Row 5.
    for (final n in _fullTankMilestones)
      Achievement(
        id: 'full_tanks_$n',
        text: _fullTankText(n),
        earnedDate: fullTankDates[n],
      ),
  ];
}
