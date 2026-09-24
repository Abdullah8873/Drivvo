import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/calc/notification_plan.dart';
import 'package:motolog/core/calc/reminder_math.dart';

/// Distance-only [ReminderDue] as if evaluated "now", with [dueOdometer]
/// still [remainingDistance] away.
ReminderDue _distanceDue({
  required double remainingDistance,
  required double dueOdometer,
  required num distanceAhead,
}) => ReminderMath.evaluate(
  schedule: ReminderSchedule(
    repeat: false,
    byDistance: true,
    dueOdometer: dueOdometer,
  ),
  baseline: (date: DateTime(2026, 1, 1), odometer: 0),
  now: DateTime(2026, 9, 1),
  currentOdometer: dueOdometer - remainingDistance,
  distanceAhead: distanceAhead,
  daysAhead: 30,
);

/// Date-only [ReminderDue], evaluated at [now].
ReminderDue _dateDue({
  required DateTime now,
  required DateTime dueDate,
  required int daysAhead,
}) => ReminderMath.evaluate(
  schedule: ReminderSchedule(repeat: false, byDate: true, dueDate: dueDate),
  baseline: (date: DateTime(2026, 1, 1), odometer: null),
  now: now,
  distanceAhead: 500,
  daysAhead: daysAhead,
);

ReminderNotificationInput _reminder({
  required String id,
  required ReminderDue due,
  double? avgDistancePerDay,
  String vehicleName = 'Honda CD70',
  String title = 'Oil Change',
}) => ReminderNotificationInput(
  reminderId: id,
  vehicleName: vehicleName,
  title: title,
  due: due,
  dueText: 'due-text',
  remainingText: 'remaining-text',
  avgDistancePerDay: avgDistancePerDay,
);

const _settings = NotificationSettings(
  reminderDistanceAhead: 500,
  reminderDaysAhead: 30,
  notificationHour: 10,
  notificationMinute: 30,
  refuelingNotifications: true,
  tirePressureNotifications: true,
);

void main() {
  group('reminder warn window', () {
    test('date-based: fires when it enters the warn window, not before', () {
      final now = DateTime(2026, 9, 1, 8);
      // 34 days out; daysAhead is 30, so the warn window opens on day 5.
      final due = _dateDue(
        now: now,
        dueDate: DateTime(2026, 10, 5),
        daysAhead: 30,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan, hasLength(1));
      expect(plan.single.fireAt, DateTime(2026, 9, 5, 10, 30));
      expect(plan.single.kind, PlannedNotificationKind.reminder);
      expect(plan.single.reminderId, 'r1');
    });

    test('distance-based: predicts the warn day from average km/day', () {
      final now = DateTime(2026, 9, 1, 8);
      // 1000 km left, 500 km warn threshold, 100 km/day average → 5 days.
      final due = _distanceDue(
        remainingDistance: 1000,
        dueOdometer: 60000,
        distanceAhead: 500,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due, avgDistancePerDay: 100)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan, hasLength(1));
      expect(plan.single.fireAt, DateTime(2026, 9, 6, 10, 30));
    });

    test('no distance history and no date trigger: nothing to schedule', () {
      final now = DateTime(2026, 9, 1, 8);
      final due = _distanceDue(
        remainingDistance: 1000,
        dueOdometer: 60000,
        distanceAhead: 500,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due, avgDistancePerDay: null)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan, isEmpty);
    });

    test('overdue reminder fires at the next occurrence — today, if the '
        'notification time has not passed yet', () {
      final now = DateTime(2026, 9, 1, 8); // before 10:30
      final due = _dateDue(
        now: now,
        dueDate: DateTime(2026, 8, 20),
        daysAhead: 30,
      );
      expect(due.status, ReminderStatus.overdue);
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 1, 10, 30));
    });

    test('already past the notification time today: rolls to tomorrow', () {
      final now = DateTime(2026, 9, 1, 11); // after 10:30
      final due = _dateDue(
        now: now,
        dueDate: DateTime(2026, 8, 20),
        daysAhead: 30,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 2, 10, 30));
    });

    test('distance and date triggers both set: earliest wins', () {
      final now = DateTime(2026, 9, 1, 8);
      // Distance warn day: +5 days. Date warn day: +2 days (dueDate 32 days
      // out, daysAhead 30). The date trigger should win.
      final due = ReminderMath.evaluate(
        schedule: ReminderSchedule(
          repeat: false,
          byDistance: true,
          dueOdometer: 60000,
          byDate: true,
          dueDate: DateTime(2026, 10, 3),
        ),
        baseline: (date: DateTime(2026, 1, 1), odometer: 0),
        now: now,
        currentOdometer: 59000,
        avgDistancePerDay: 100,
        distanceAhead: 500,
        daysAhead: 30,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due, avgDistancePerDay: 100)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 3, 10, 30));
    });
  });

  group('next refueling', () {
    test('fires on the predicted date, only when the toggle is on', () {
      final now = DateTime(2026, 9, 1, 8);
      // A predicted refuel date, built directly (bypassing
      // evaluateNextRefueling to keep this test focused on the planner, not
      // the prediction math).
      final refuelDue = ReminderDue(
        dueDate: DateTime(2026, 9, 10),
        status: ReminderStatus.ok,
      );
      final input = RefuelingNotificationInput(
        vehicleId: 'v1',
        vehicleName: 'Honda CD70',
        due: refuelDue,
        dueText: 'due',
        remainingText: 'remaining',
      );

      final on = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: const [],
        refuelings: [input],
        settings: _settings,
      );
      expect(on, hasLength(1));
      expect(on.single.kind, PlannedNotificationKind.nextRefueling);
      expect(on.single.fireAt, DateTime(2026, 9, 10, 10, 30));
      expect(on.single.vehicleId, 'v1');

      final off = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: const [],
        refuelings: [input],
        settings: const NotificationSettings(
          reminderDistanceAhead: 500,
          reminderDaysAhead: 30,
          notificationHour: 10,
          notificationMinute: 30,
          refuelingNotifications: false,
          tirePressureNotifications: true,
        ),
      );
      expect(off, isEmpty);
    });
  });

  group('tire pressure', () {
    test('schedules one check per vehicle on the 15-day grid', () {
      final now = DateTime(2026, 9, 1, 8);
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
        reminders: const [],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan, hasLength(1));
      expect(plan.single.kind, PlannedNotificationKind.tirePressure);
      expect(plan.single.body, 'Check the tire pressure of Honda CD70');

      // The grid is anchored to a fixed epoch (not "today"), so recomputing
      // the plan a day later lands on the same day unless that day was
      // itself the boundary — verify against the same epoch formula rather
      // than assuming which side of the boundary `now` falls on.
      final epoch = DateTime(1970, 1, 1);
      final daysSinceEpoch = ReminderMath.daysBetween(
        epoch,
        DateTime(2026, 9, 1),
      );
      final remainder = daysSinceEpoch % 15;
      final untilNext = remainder == 0 ? 0 : 15 - remainder;
      final expectedDay = DateTime(2026, 9, 1 + untilNext);
      expect(
        plan.single.fireAt,
        DateTime(expectedDay.year, expectedDay.month, expectedDay.day, 10, 30),
      );
    });

    test(
      'a missed grid day rolls forward by a full 15-day cycle, not a day',
      () {
        // Find a date that's exactly on the grid, then ask again once the
        // notification time on that same day has already passed.
        final epoch = DateTime(1970, 1, 1);
        var probe = DateTime(2026, 9, 1);
        while (ReminderMath.daysBetween(epoch, probe) % 15 != 0) {
          probe = probe.add(const Duration(days: 1));
        }
        final onGridEarly = DateTime(probe.year, probe.month, probe.day, 8);
        final onGridLate = DateTime(probe.year, probe.month, probe.day, 11);

        final firesToday = NotificationPlanner.plan(
          now: onGridEarly,
          vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
          reminders: const [],
          refuelings: const [],
          settings: _settings,
        ).single.fireAt;
        expect(
          firesToday,
          DateTime(probe.year, probe.month, probe.day, 10, 30),
        );

        final rolledOver = NotificationPlanner.plan(
          now: onGridLate,
          vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
          reminders: const [],
          refuelings: const [],
          settings: _settings,
        ).single.fireAt;
        expect(rolledOver, firesToday.add(const Duration(days: 15)));
      },
    );

    test('toggle off: no tire-pressure notifications', () {
      final now = DateTime(2026, 9, 1, 8);
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
        reminders: const [],
        refuelings: const [],
        settings: const NotificationSettings(
          reminderDistanceAhead: 500,
          reminderDaysAhead: 30,
          notificationHour: 10,
          notificationMinute: 30,
          refuelingNotifications: true,
          tirePressureNotifications: false,
        ),
      );
      expect(plan, isEmpty);
    });
  });

  test('both toggles off with nothing else pending: empty plan', () {
    final now = DateTime(2026, 9, 1, 8);
    final refuelDue = ReminderDue(
      dueDate: DateTime(2026, 9, 5),
      status: ReminderStatus.ok,
    );
    final plan = NotificationPlanner.plan(
      now: now,
      vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
      reminders: const [],
      refuelings: [
        RefuelingNotificationInput(
          vehicleId: 'v1',
          vehicleName: 'Honda CD70',
          due: refuelDue,
          dueText: 'due',
          remainingText: 'remaining',
        ),
      ],
      settings: const NotificationSettings(
        reminderDistanceAhead: 500,
        reminderDaysAhead: 30,
        notificationHour: 10,
        notificationMinute: 30,
        refuelingNotifications: false,
        tirePressureNotifications: false,
      ),
    );
    expect(plan, isEmpty);
  });

  group('stable ids', () {
    test('the same reminder/vehicle always maps to the same id', () {
      final now = DateTime(2026, 9, 1, 8);
      final due = _dateDue(
        now: now,
        dueDate: DateTime(2026, 8, 20),
        daysAhead: 30,
      );
      final planA = NotificationPlanner.plan(
        now: now,
        vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      final planB = NotificationPlanner.plan(
        now: now,
        vehicles: const [ActiveVehicle(id: 'v1', name: 'Honda CD70')],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      final reminderIdA = planA.firstWhere((n) => n.reminderId == 'r1').id;
      final reminderIdB = planB.firstWhere((n) => n.reminderId == 'r1').id;
      expect(reminderIdA, reminderIdB);

      final tireIdA = planA
          .firstWhere(
            (n) =>
                n.vehicleId == 'v1' &&
                n.kind == PlannedNotificationKind.tirePressure,
          )
          .id;
      // Different key namespace (reminder vs tire) must not collide.
      expect(tireIdA, isNot(reminderIdA));
    });
  });

  group('horizon and cap', () {
    test('drops anything further out than the horizon', () {
      final now = DateTime(2026, 9, 1, 8);
      // Warn day is due-30days = now+170 days, well past the 60-day horizon.
      final due = _dateDue(
        now: now,
        dueDate: DateTime(2027, 3, 20),
        daysAhead: 30,
      );
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: [_reminder(id: 'r1', due: due)],
        refuelings: const [],
        settings: _settings,
      );
      expect(plan, isEmpty);
    });

    test('caps the total and keeps the soonest', () {
      final now = DateTime(2026, 9, 1, 8);
      final reminders = [
        for (var i = 0; i < 3; i++)
          _reminder(
            id: 'r$i',
            due: _dateDue(
              now: now,
              dueDate: DateTime(2026, 9, 1 + i),
              daysAhead: 30,
            ),
          ),
      ];
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: reminders,
        refuelings: const [],
        settings: _settings,
        maxNotifications: 2,
      );
      expect(plan, hasLength(2));
      expect(plan.map((n) => n.reminderId), ['r0', 'r1']);
    });

    test('never returns more than the default max', () {
      final now = DateTime(2026, 9, 1, 8);
      final reminders = [
        for (var i = 0; i < 60; i++)
          _reminder(
            id: 'r$i',
            due: _dateDue(
              now: now,
              dueDate: DateTime(2026, 8, 20),
              daysAhead: 30,
            ),
          ),
      ];
      final plan = NotificationPlanner.plan(
        now: now,
        vehicles: const [],
        reminders: reminders,
        refuelings: const [],
        settings: _settings,
      );
      expect(plan.length, NotificationPlanner.defaultMaxNotifications);
    });
  });
}
