import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/reminder_math.dart';
import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import 'reminder_queries.dart';

/// "What time is it?" — a provider so tests can freeze the clock.
final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

// ---- Raw data (auto-dispose: the DB subscription closes when no screen
// is listening, like unsubscribing in a React effect cleanup) -------------

final remindersProvider = StreamProvider.autoDispose
    .family<List<Reminder>, String>(
      (ref, vehicleId) => ref.watch(databaseProvider).watchReminders(vehicleId),
    );

final odometerHistoryProvider = StreamProvider.autoDispose
    .family<List<OdometerPoint>, String>(
      (ref, vehicleId) =>
          ref.watch(databaseProvider).watchOdometerHistory(vehicleId),
    );

final refuelPointsProvider = StreamProvider.autoDispose
    .family<List<OdometerPoint>, String>(
      (ref, vehicleId) =>
          ref.watch(databaseProvider).watchRefuelPoints(vehicleId),
    );

final lastLoggedByTypeProvider = StreamProvider.autoDispose
    .family<Map<String, Baseline>, String>(
      (ref, vehicleId) =>
          ref.watch(databaseProvider).watchLastLoggedByType(vehicleId),
    );

// ---- Display items ------------------------------------------------------

/// One ready-to-render reminder card (Reminders tab and the History strip).
@immutable
class UpcomingReminder {
  const UpcomingReminder({
    this.reminderId,
    required this.title,
    required this.dueText,
    required this.remainingText,
    required this.status,
    required this.module,
    this.progress,
    this.due,
  });

  /// The reminder row's id; null for the predicted "Next refueling" item.
  final String? reminderId;

  /// Type name, e.g. "Oil Change", or "Next refueling".
  final String title;

  /// e.g. "57132 km · 02 oct".
  final String dueText;

  /// e.g. "in 197 km · in 9 days", or "overdue by 120 km".
  final String remainingText;
  final ReminderStatus status;

  /// Supplies the color and icon (refueling / service / expense).
  final RecordModule module;

  /// 0..1 share of the interval used (null = unknown).
  final double? progress;

  /// The raw numbers behind the texts.
  final ReminderDue? due;

  bool get isPrediction => reminderId == null;
}

/// Builds the display texts for a [ReminderDue]. Kept separate from the
/// providers so it's easy to test.
({String dueText, String remainingText}) describeDue(
  ReminderDue due,
  Formatters fmt,
  DistanceUnit unit,
) {
  String dist(num v) => fmt.distance(v, unit);
  String days(int n) => n == 1 ? '1 day' : '$n days';

  final dueParts = [
    if (due.dueOdometer != null) dist(due.dueOdometer!),
    if (due.displayDate != null) fmt.shortDate(due.displayDate!),
  ];

  final String remaining;
  if (due.status == ReminderStatus.overdue) {
    final rd = due.remainingDistance;
    final dd = due.remainingDays;
    final over = [
      if (rd != null && rd < 0) dist(-rd),
      if (dd != null && dd < 0) days(-dd),
    ];
    remaining = over.isEmpty ? 'overdue' : 'overdue by ${over.join(' · ')}';
  } else {
    final rd = due.remainingDistance;
    final dd = due.displayDays;
    remaining = [
      if (rd != null) 'in ${dist(rd)}',
      if (dd != null) dd == 0 ? 'today' : 'in ${days(dd)}',
    ].join(' · ');
  }
  return (dueText: dueParts.join(' · '), remainingText: remaining);
}

/// Most urgent first: overdue, then soon, then ok; ties by days, then km.
int compareUrgency(UpcomingReminder a, UpcomingReminder b) {
  final byStatus = b.status.index.compareTo(a.status.index);
  if (byStatus != 0) return byStatus;
  int cmp(num? x, num? y) => x == null
      ? (y == null ? 0 : 1)
      : y == null
      ? -1
      : x.compareTo(y);
  final byDays = cmp(a.due?.displayDays, b.due?.displayDays);
  if (byDays != 0) return byDays;
  return cmp(a.due?.remainingDistance, b.due?.remainingDistance);
}

/// Every reminder of a vehicle (active or not) as display items, most
/// urgent first. Screens use [activeReminderItemsProvider] instead.
final reminderItemsProvider = FutureProvider.autoDispose
    .family<List<UpcomingReminder>, String>((ref, vehicleId) async {
      final reminders = await ref.watch(remindersProvider(vehicleId).future);
      if (reminders.isEmpty) return const [];

      final history = await ref.watch(
        odometerHistoryProvider(vehicleId).future,
      );
      final logged = await ref.watch(
        lastLoggedByTypeProvider(vehicleId).future,
      );
      final services = await ref.watch(
        catalogProvider(CatalogKind.serviceType).future,
      );
      final expenses = await ref.watch(
        catalogProvider(CatalogKind.expenseType).future,
      );
      final unit = await _distanceUnit(ref, vehicleId);
      final settings = ref.watch(settingsProvider);
      final fmt = ref.watch(formattersProvider);
      final now = ref.watch(reminderClockProvider)();

      final current = history.isEmpty
          ? null
          : history.map((p) => p.odometer).reduce((a, b) => a > b ? a : b);
      final avgPerDay = ReminderMath.averageDistancePerDay(history);
      final typeNames = {
        for (final c in [...services, ...expenses]) c.id: c.name,
      };

      final items = [
        for (final r in reminders)
          _toItem(
            r,
            title: typeNames[r.typeId] ?? 'Reminder',
            baseline: ReminderMath.resolveBaseline(
              lastLogged: r.repeat ? logged[r.typeId] : null,
              storedOdometer: r.lastDoneOdometer,
              storedDate: r.lastDoneDate,
              createdAt: r.createdAt,
              currentOdometer: current,
              history: history,
            ),
            now: now,
            currentOdometer: current,
            avgPerDay: avgPerDay,
            distanceAhead: settings.reminderDistanceAhead,
            daysAhead: settings.reminderDaysAhead,
            fmt: fmt,
            unit: unit,
          ),
      ]..sort(compareUrgency);
      return items;
    });

/// Only the active reminders (`active == true`) of a vehicle, most urgent
/// first. The Reminders tab and the History strip both use this, so a
/// switched-off reminder disappears from both at once.
final activeReminderItemsProvider = FutureProvider.autoDispose
    .family<List<UpcomingReminder>, String>((ref, vehicleId) async {
      final items = await ref.watch(reminderItemsProvider(vehicleId).future);
      final reminders = await ref.watch(remindersProvider(vehicleId).future);
      final activeIds = {
        for (final r in reminders)
          if (r.active) r.id,
      };
      return [
        for (final i in items)
          if (activeIds.contains(i.reminderId)) i,
      ];
    });

/// What the History screen shows in its "REMINDERS" strip: the predicted
/// "Next refueling" first (when there are 2+ refuelings), then the active
/// reminders, most urgent first.
///
/// Usage: `ref.watch(upcomingRemindersProvider(vehicleId)).value ?? []`.
final upcomingRemindersProvider = FutureProvider.autoDispose
    .family<List<UpcomingReminder>, String>((ref, vehicleId) async {
      final refuels = await ref.watch(refuelPointsProvider(vehicleId).future);
      final history = await ref.watch(
        odometerHistoryProvider(vehicleId).future,
      );
      final reminderItems = await ref.watch(
        activeReminderItemsProvider(vehicleId).future,
      );
      final unit = await _distanceUnit(ref, vehicleId);
      final fmt = ref.watch(formattersProvider);
      final now = ref.watch(reminderClockProvider)();

      final current = history.isEmpty
          ? null
          : history.map((p) => p.odometer).reduce((a, b) => a > b ? a : b);

      final refuelDue = ReminderMath.evaluateNextRefueling(
        refuels: refuels,
        now: now,
        currentOdometer: current,
      );
      final refuelTexts = refuelDue == null
          ? null
          : describeDue(refuelDue, fmt, unit);
      return [
        if (refuelDue != null && refuelTexts != null)
          UpcomingReminder(
            title: 'Next refueling',
            dueText: refuelTexts.dueText,
            remainingText: refuelTexts.remainingText,
            status: refuelDue.status,
            module: RecordModule.refueling,
            progress: refuelDue.progress,
            due: refuelDue,
          ),
        ...reminderItems,
      ];
    });

Future<DistanceUnit> _distanceUnit(Ref ref, String vehicleId) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  return vehicles.where((v) => v.id == vehicleId).firstOrNull?.distanceUnit ??
      DistanceUnit.km;
}

UpcomingReminder _toItem(
  Reminder r, {
  required String title,
  required Baseline baseline,
  required DateTime now,
  required double? currentOdometer,
  required double? avgPerDay,
  required int distanceAhead,
  required int daysAhead,
  required Formatters fmt,
  required DistanceUnit unit,
}) {
  final due = ReminderMath.evaluate(
    schedule: scheduleOf(r),
    baseline: baseline,
    now: now,
    currentOdometer: currentOdometer,
    avgDistancePerDay: avgPerDay,
    distanceAhead: distanceAhead,
    daysAhead: daysAhead,
  );
  final texts = describeDue(due, fmt, unit);
  return UpcomingReminder(
    reminderId: r.id,
    title: title,
    dueText: texts.dueText,
    remainingText: texts.remainingText,
    status: due.status,
    module: r.target == ReminderTarget.service
        ? RecordModule.service
        : RecordModule.expense,
    progress: due.progress,
    due: due,
  );
}

/// Copies a reminder row's trigger settings into the pure-math input.
ReminderSchedule scheduleOf(Reminder r) => ReminderSchedule(
  repeat: r.repeat,
  byDistance: r.byDistance,
  dueOdometer: r.dueOdometer,
  everyDistance: r.everyDistance,
  byDate: r.byDate,
  dueDate: r.dueDate,
  everyAmount: r.everyAmount,
  everyUnit: r.everyUnit,
);
