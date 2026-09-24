import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/notification_plan.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/notifications/notification_providers.dart';
import 'package:motolog/core/notifications/notification_scheduler.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/reminders/reminder_providers.dart';
import 'package:motolog/features/reminders/reminder_queries.dart';

import 'helpers.dart';

/// Records every call instead of talking to a platform channel — the
/// no-op scheduler can't be asserted against, so tests that need to know
/// *what* was scheduled use this instead.
class FakeNotificationScheduler implements NotificationScheduler {
  int cancelAllCalls = 0;
  bool permissionRequested = false;
  bool showNowCalled = false;
  List<PlannedNotification> scheduled = const [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> schedule(
    List<PlannedNotification> notifications, {
    required bool vibrate,
  }) async {
    scheduled = notifications;
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    showNowCalled = true;
  }
}

Future<String> _oilChangeTypeId(AppDatabase db) async =>
    (await db.getCatalog(CatalogKind.serviceType))
        .firstWhere((c) => c.name == 'Oil Change')
        .id;

void main() {
  group('notificationPlanProvider', () {
    test('ignores inactive vehicles and soft-deleted reminders', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final now = DateTime(2026, 9, 24, 9);

      final activeVehicle = await addTestVehicle(db, name: 'Honda CD70');
      final inactiveVehicle = await db
          .into(db.vehicles)
          .insertReturning(
            VehiclesCompanion.insert(
              name: 'Retired Bike',
              type: VehicleType.motorcycle,
              active: const Value(false),
            ),
          );

      final oil = await _oilChangeTypeId(db);
      // Overdue — inside every warn window — on the active vehicle: kept.
      final keptReminderId = await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: activeVehicle,
          target: ReminderTarget.service,
          typeId: oil,
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2026, 9, 1)),
        ),
      );
      // Same due date, but soft-deleted: dropped.
      final deletedReminderId = await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: activeVehicle,
          target: ReminderTarget.service,
          typeId: oil,
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2026, 9, 1)),
        ),
      );
      await db.softDeleteReminder(deletedReminderId);
      // Same due date, but on the inactive vehicle: dropped.
      await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: inactiveVehicle.id,
          target: ReminderTarget.service,
          typeId: oil,
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2026, 9, 1)),
        ),
      );

      final container = ProviderContainer.test(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderClockProvider.overrideWithValue(() => now),
        ],
      );
      container.listen(notificationPlanProvider, (_, _) {});
      final plan = await container.read(notificationPlanProvider.future);

      final reminderNotifications = plan.where(
        (n) => n.kind == PlannedNotificationKind.reminder,
      );
      expect(reminderNotifications.map((n) => n.reminderId), [keptReminderId]);

      // Only the active vehicle gets a tire-pressure check (default on).
      final tireNotifications = plan.where(
        (n) => n.kind == PlannedNotificationKind.tirePressure,
      );
      expect(tireNotifications.map((n) => n.vehicleId), [activeVehicle]);
    });
  });

  group('NotificationController', () {
    test('adding a reminder triggers a reschedule containing it', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final now = DateTime(2026, 9, 24, 9);
      final scheduler = FakeNotificationScheduler();

      final container = ProviderContainer.test(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderClockProvider.overrideWithValue(() => now),
          notificationSchedulerProvider.overrideWithValue(scheduler),
          notificationDebounceProvider.overrideWithValue(Duration.zero),
        ],
      );

      final vehicleId = await addTestVehicle(db, name: 'Honda CD70');
      // A plain listener keeps the provider alive so `.future` below
      // resolves — the same pattern `reminder_feature_test.dart` uses
      // before every `container.read(someProvider.future)`.
      container.listen(notificationPlanProvider, (_, _) {});
      // Start the controller listening *before* the reminder exists, so the
      // test proves it reacts to the change rather than just reading an
      // already-populated plan once.
      final controller = container.read(notificationControllerProvider);
      await container.read(notificationPlanProvider.future);
      await controller.lastApply;
      expect(
        scheduler.scheduled.where(
          (n) => n.kind == PlannedNotificationKind.reminder,
        ),
        isEmpty,
      );

      // A listener that resolves once the plan contains a reminder
      // notification — avoids guessing how long the DB's stream takes to
      // emit the new row.
      final sawReminder = Completer<void>();
      container.listen(notificationPlanProvider, (previous, next) {
        final list = next.value;
        if (list != null &&
            list.any((n) => n.kind == PlannedNotificationKind.reminder) &&
            !sawReminder.isCompleted) {
          sawReminder.complete();
        }
      });

      final oil = await _oilChangeTypeId(db);
      final reminderId = await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vehicleId,
          target: ReminderTarget.service,
          typeId: oil,
          byDistance: const Value(false),
          byDate: const Value(true),
          dueDate: Value(DateTime(2026, 9, 1)), // overdue
        ),
      );

      await sawReminder.future.timeout(const Duration(seconds: 5));
      await controller.lastApply;

      expect(
        scheduler.scheduled.any((n) => n.reminderId == reminderId),
        isTrue,
      );
      expect(scheduler.permissionRequested, isTrue);
      expect(scheduler.cancelAllCalls, greaterThanOrEqualTo(2));
    });
  });
}
