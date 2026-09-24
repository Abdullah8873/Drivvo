import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reminders/reminder_providers.dart';
import '../calc/notification_plan.dart';
import '../calc/reminder_math.dart';
import '../db/app_database.dart';
import '../providers.dart';
import 'noop_notification_scheduler.dart';
import 'notification_scheduler.dart';

/// Which [NotificationScheduler] the app uses. Defaults to the no-op
/// scheduler — the same reason `databaseProvider` throws by default — so
/// every test gets a safe default without needing to override it; `main.dart`
/// overrides this with a real [LocalNotificationScheduler] (except on web,
/// which stays no-op since the plugin doesn't support scheduling there).
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);

/// How long [NotificationController] waits after the last change before
/// rescheduling. Defaults to zero (apply immediately, no `Timer`) so tests
/// never have to deal with a pending timer; `main.dart` overrides this to a
/// real delay so rapid-fire edits (e.g. typing in a reminder's odometer
/// field) don't reschedule on every keystroke.
final notificationDebounceProvider = Provider<Duration>((ref) => Duration.zero);

/// The debounce `main.dart` uses in the real app.
const productionNotificationDebounce = Duration(seconds: 2);

/// Every active vehicle's reminders, evaluated the same way the Reminders
/// tab does (reusing [ReminderMath] — see `reminder_providers.dart`), plus
/// the next-refueling prediction, turned into the flat notification plan by
/// [NotificationPlanner]. Recomputes whenever reminders, the records that
/// feed predictions, vehicles or settings change — like a derived query that
/// depends on several other queries.
final notificationPlanProvider = FutureProvider<List<PlannedNotification>>((
  ref,
) async {
  final settings = ref.watch(settingsProvider);
  final vehicles = await ref.watch(vehiclesProvider.future);
  final active = vehicles.where((v) => v.active).toList();
  final now = ref.watch(reminderClockProvider)();
  final fmt = ref.watch(formattersProvider);

  final reminderInputs = <ReminderNotificationInput>[];
  final refuelInputs = <RefuelingNotificationInput>[];

  for (final v in active) {
    final reminders = await ref.watch(remindersProvider(v.id).future);
    final activeReminders = reminders.where((r) => r.active).toList();
    final history = await ref.watch(odometerHistoryProvider(v.id).future);
    final avgPerDay = ReminderMath.averageDistancePerDay(history);
    final current = history.isEmpty
        ? null
        : history.map((p) => p.odometer).reduce((a, b) => a > b ? a : b);

    if (activeReminders.isNotEmpty) {
      final logged = await ref.watch(lastLoggedByTypeProvider(v.id).future);
      final services = await ref.watch(
        catalogProvider(CatalogKind.serviceType).future,
      );
      final expenses = await ref.watch(
        catalogProvider(CatalogKind.expenseType).future,
      );
      final typeNames = {
        for (final c in [...services, ...expenses]) c.id: c.name,
      };
      for (final r in activeReminders) {
        final due = ReminderMath.evaluate(
          schedule: scheduleOf(r),
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
          avgDistancePerDay: avgPerDay,
          distanceAhead: settings.reminderDistanceAhead,
          daysAhead: settings.reminderDaysAhead,
        );
        final texts = describeDue(due, fmt, v.distanceUnit);
        reminderInputs.add(
          ReminderNotificationInput(
            reminderId: r.id,
            vehicleName: v.name,
            title: typeNames[r.typeId] ?? 'Reminder',
            due: due,
            dueText: texts.dueText,
            remainingText: texts.remainingText,
            avgDistancePerDay: avgPerDay,
          ),
        );
      }
    }

    if (settings.refuelingNotifications) {
      final refuels = await ref.watch(refuelPointsProvider(v.id).future);
      final due = ReminderMath.evaluateNextRefueling(
        refuels: refuels,
        now: now,
        currentOdometer: current,
      );
      if (due != null) {
        final texts = describeDue(due, fmt, v.distanceUnit);
        refuelInputs.add(
          RefuelingNotificationInput(
            vehicleId: v.id,
            vehicleName: v.name,
            due: due,
            dueText: texts.dueText,
            remainingText: texts.remainingText,
          ),
        );
      }
    }
  }

  return NotificationPlanner.plan(
    now: now,
    vehicles: [for (final v in active) ActiveVehicle(id: v.id, name: v.name)],
    reminders: reminderInputs,
    refuelings: refuelInputs,
    settings: NotificationSettings(
      reminderDistanceAhead: settings.reminderDistanceAhead,
      reminderDaysAhead: settings.reminderDaysAhead,
      notificationHour: settings.notificationHour,
      notificationMinute: settings.notificationMinute,
      refuelingNotifications: settings.refuelingNotifications,
      tirePressureNotifications: settings.tirePressureNotifications,
    ),
  );
});

/// Keeps the OS's scheduled notifications in sync with [notificationPlanProvider].
///
/// This is the mobile equivalent of a service worker's `pushsubscriptionchange`
/// handler: whenever the underlying data could change what should notify the
/// user, it recomputes the plan and re-registers it with the OS
/// (`cancelAll` + `schedule`, so stale notifications never linger).
class NotificationController {
  NotificationController(this._ref) {
    _ref.listen<AsyncValue<List<PlannedNotification>>>(
      notificationPlanProvider,
      (previous, next) => _onPlanChanged(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  Timer? _debounceTimer;
  bool _permissionRequested = false;

  /// The reschedule work most recently kicked off — exposed so tests can
  /// `await` it instead of guessing how long a debounce takes.
  @visibleForTesting
  Future<void>? lastApply;

  void _onPlanChanged(AsyncValue<List<PlannedNotification>> next) {
    // Still loading or errored: leave whatever was already scheduled alone
    // rather than clearing it based on incomplete data.
    final list = next.value;
    if (list == null) return;

    _debounceTimer?.cancel();
    final delay = _ref.read(notificationDebounceProvider);
    if (delay == Duration.zero) {
      lastApply = _apply(list);
      return;
    }
    _debounceTimer = Timer(delay, () => lastApply = _apply(list));
  }

  Future<void> _apply(List<PlannedNotification> list) async {
    final scheduler = _ref.read(notificationSchedulerProvider);
    // Ask once we actually have something to notify about — never at app
    // launch with an empty reminders list.
    if (list.isNotEmpty && !_permissionRequested) {
      _permissionRequested = true;
      await scheduler.requestPermission();
    }
    await scheduler.cancelAll();
    await scheduler.schedule(list, vibrate: _ref.read(settingsProvider).vibrate);
  }

  /// Forces an immediate recompute + reschedule, bypassing the debounce.
  /// Called on app start and when the app resumes from the background,
  /// since time has passed and the plan (built for "today") may be stale.
  void reschedule() => _onPlanChanged(_ref.read(notificationPlanProvider));

  void dispose() => _debounceTimer?.cancel();
}

/// Not auto-dispose: created once and kept alive for the life of the app (or
/// the test's `ProviderContainer`), like a singleton service.
final notificationControllerProvider = Provider<NotificationController>((
  ref,
) {
  final controller = NotificationController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
