import 'reminder_math.dart';

/// Route pushed when a MotoLog notification is tapped (payload for
/// go_router — see `lib/core/router/app_router.dart`).
const notificationTapRoute = '/reminders';

/// How many days ahead a "check the tires" notification repeats.
const tirePressureCadenceDays = 15;

/// A vehicle eligible for notifications (active, not soft-deleted). Only the
/// fields the planner needs — callers build this from `Vehicle` rows.
class ActiveVehicle {
  const ActiveVehicle({required this.id, required this.name});

  final String id;
  final String name;
}

/// One reminder's evaluated due-state, ready for [NotificationPlanner.plan].
///
/// [due] must come from [ReminderMath.evaluate] using the *same*
/// `distanceAhead`/`daysAhead` passed as [NotificationSettings] to `plan` —
/// that's what makes the planner's "day it enters the warn window" line up
/// with what the Reminders tab already shows as "soon". [dueText] and
/// [remainingText] are the same strings the Reminders tab shows (built with
/// `describeDue`/`Formatters`, which need Flutter — that's why they're
/// passed in as plain strings instead of computed here).
class ReminderNotificationInput {
  const ReminderNotificationInput({
    required this.reminderId,
    required this.vehicleName,
    required this.title,
    required this.due,
    required this.dueText,
    required this.remainingText,
    this.avgDistancePerDay,
  });

  final String reminderId;
  final String vehicleName;

  /// The service/expense type name, e.g. "Oil Change".
  final String title;
  final ReminderDue due;

  /// e.g. "56600 km · 01 oct".
  final String dueText;

  /// e.g. "in 150 km · in 8 days" or "overdue by 1 day".
  final String remainingText;

  /// Needed to predict when a distance trigger will enter the warn window;
  /// null when there isn't enough history (see [ReminderMath.averageDistancePerDay]).
  final double? avgDistancePerDay;
}

/// The "next refueling" prediction for one vehicle, ready for the planner.
/// [due] comes from [ReminderMath.evaluateNextRefueling].
class RefuelingNotificationInput {
  const RefuelingNotificationInput({
    required this.vehicleId,
    required this.vehicleName,
    required this.due,
    required this.dueText,
    required this.remainingText,
  });

  final String vehicleId;
  final String vehicleName;
  final ReminderDue due;
  final String dueText;
  final String remainingText;
}

/// The subset of `AppSettings` the planner reacts to. Kept as its own class
/// (instead of importing `AppSettings`) so this file stays free of Flutter
/// imports, like the rest of `core/calc`.
class NotificationSettings {
  const NotificationSettings({
    required this.reminderDistanceAhead,
    required this.reminderDaysAhead,
    required this.notificationHour,
    required this.notificationMinute,
    required this.refuelingNotifications,
    required this.tirePressureNotifications,
  });

  final num reminderDistanceAhead;
  final int reminderDaysAhead;
  final int notificationHour;
  final int notificationMinute;
  final bool refuelingNotifications;
  final bool tirePressureNotifications;
}

/// What kind of notification a [PlannedNotification] is — mirrors the three
/// rules in [NotificationPlanner.plan].
enum PlannedNotificationKind { reminder, nextRefueling, tirePressure }

/// One notification [NotificationPlanner.plan] decided to schedule. The
/// notification scheduler (`core/notifications/`) turns these into actual
/// OS-level scheduled notifications.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.payload,
    this.reminderId,
    this.vehicleId,
  });

  /// Stable, deterministic notification id (see [stableNotificationId]) —
  /// the same reminder/vehicle always maps to the same id, so rescheduling
  /// replaces the old pending notification instead of duplicating it.
  final int id;
  final PlannedNotificationKind kind;
  final String title;
  final String body;
  final DateTime fireAt;

  /// Deep-link payload the scheduler attaches to the OS notification.
  final String payload;

  /// The source reminder id, for [PlannedNotificationKind.reminder].
  final String? reminderId;

  /// The vehicle id, for [PlannedNotificationKind.nextRefueling] and
  /// [PlannedNotificationKind.tirePressure].
  final String? vehicleId;

  @override
  String toString() =>
      'PlannedNotification($kind, id: $id, fireAt: $fireAt, title: $title)';
}

/// FNV-1a 32-bit hash, kept positive and within the 31-bit range every
/// notification plugin accepts as an id. Deterministic across runs (unlike
/// Dart's `String.hashCode`, which isn't guaranteed stable), so the same
/// [key] always produces the same notification id.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// The first `day`-at-`hour:minute` moment that isn't before [now], stepping
/// forward by [stepDays] at a time (1 for a one-off reminder/refuel
/// notification — "already passed today, try tomorrow"; 15 for the
/// tire-pressure cadence, so a missed slot rolls to the next 15-day mark
/// instead of the next day).
DateTime _nextOccurrence(
  DateTime day,
  int hour,
  int minute,
  DateTime now,
  int stepDays,
) {
  var d = day;
  DateTime fire() => DateTime(d.year, d.month, d.day, hour, minute);
  var f = fire();
  while (f.isBefore(now)) {
    d = _addDays(d, stepDays);
    f = fire();
  }
  return f;
}

/// The next day on the fixed 15-day tire-pressure grid, anchored to the Unix
/// epoch so it doesn't drift every time the plan is recomputed (the plan is
/// rebuilt on every reminder/vehicle/settings change and app resume — an
/// anchor relative to "today" would reset the cycle each time).
DateTime _nextTirePressureDay(DateTime today) {
  final epoch = DateTime(1970, 1, 1);
  final daysSinceEpoch = ReminderMath.daysBetween(epoch, today);
  final remainder = daysSinceEpoch % tirePressureCadenceDays;
  final untilNext = remainder == 0 ? 0 : tirePressureCadenceDays - remainder;
  return _addDays(today, untilNext);
}

/// The day a reminder first enters the "warn" window (soon/overdue), from
/// `now`'s point of view — the earlier of the distance and date triggers,
/// whichever fires first. Null when the reminder has no trigger the planner
/// can predict (no distance history, no date trigger).
DateTime? _warnDay(
  ReminderDue due,
  double? avgDistancePerDay,
  DateTime today,
  NotificationSettings settings,
) {
  final candidates = <DateTime>[];

  final remainingDistance = due.remainingDistance;
  if (due.dueOdometer != null && remainingDistance != null) {
    if (remainingDistance <= settings.reminderDistanceAhead) {
      // Already inside the window (or overdue) as of `now`.
      candidates.add(today);
    } else if (avgDistancePerDay != null && avgDistancePerDay > 0) {
      final daysNeeded =
          ((remainingDistance - settings.reminderDistanceAhead) /
                  avgDistancePerDay)
              .ceil();
      candidates.add(_addDays(today, daysNeeded));
    }
  }

  final remainingDays = due.remainingDays;
  final dueDate = due.dueDate;
  if (dueDate != null && remainingDays != null) {
    if (remainingDays <= settings.reminderDaysAhead) {
      candidates.add(today);
    } else {
      candidates.add(_addDays(_dateOnly(dueDate), -settings.reminderDaysAhead));
    }
  }

  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Turns reminders, the next-refueling prediction and settings into the flat
/// list of notifications to schedule. Pure — no Flutter, no database, no
/// clock of its own (the caller passes `now`) — so it's fully unit-testable
/// and the scheduler (`core/notifications/`) stays a thin adapter around it.
///
/// Think of this like computing the payload for a Web Push subscription:
/// the same "what should fire, and when" decision, just aimed at
/// `flutter_local_notifications` instead of a service worker.
class NotificationPlanner {
  NotificationPlanner._();

  /// Only notifications firing within this many days of `now` are kept —
  /// there is no point scheduling further out than that, and the OS/plugins
  /// cap how many pending notifications they'll hold anyway.
  static const defaultHorizonDays = 60;

  /// iOS keeps only the last 64 notifications scheduled; stay comfortably
  /// under that (and under Android's per-app caps) regardless of platform.
  static const defaultMaxNotifications = 50;

  static List<PlannedNotification> plan({
    required DateTime now,
    required List<ActiveVehicle> vehicles,
    required List<ReminderNotificationInput> reminders,
    required List<RefuelingNotificationInput> refuelings,
    required NotificationSettings settings,
    int horizonDays = defaultHorizonDays,
    int maxNotifications = defaultMaxNotifications,
  }) {
    final today = _dateOnly(now);
    final results = <PlannedNotification>[];

    for (final input in reminders) {
      final warnDay = _warnDay(
        input.due,
        input.avgDistancePerDay,
        today,
        settings,
      );
      if (warnDay == null) continue;
      final targetDay = _laterOf(warnDay, today);
      final fireAt = _nextOccurrence(
        targetDay,
        settings.notificationHour,
        settings.notificationMinute,
        now,
        1,
      );
      final overdue = input.due.status == ReminderStatus.overdue;
      results.add(
        PlannedNotification(
          id: stableNotificationId('reminder:${input.reminderId}'),
          kind: PlannedNotificationKind.reminder,
          title: overdue ? '${input.title} overdue' : '${input.title} due',
          body: '${input.vehicleName} · ${input.remainingText} · ${input.dueText}',
          fireAt: fireAt,
          payload: notificationTapRoute,
          reminderId: input.reminderId,
        ),
      );
    }

    if (settings.refuelingNotifications) {
      for (final input in refuelings) {
        final dueDate = input.due.dueDate;
        if (dueDate == null) continue;
        final targetDay = _laterOf(_dateOnly(dueDate), today);
        final fireAt = _nextOccurrence(
          targetDay,
          settings.notificationHour,
          settings.notificationMinute,
          now,
          1,
        );
        results.add(
          PlannedNotification(
            id: stableNotificationId('refuel:${input.vehicleId}'),
            kind: PlannedNotificationKind.nextRefueling,
            title: 'Next refueling',
            body:
                '${input.vehicleName} · ${input.remainingText} · ${input.dueText}',
            fireAt: fireAt,
            payload: notificationTapRoute,
            vehicleId: input.vehicleId,
          ),
        );
      }
    }

    if (settings.tirePressureNotifications) {
      for (final vehicle in vehicles) {
        final targetDay = _nextTirePressureDay(today);
        final fireAt = _nextOccurrence(
          targetDay,
          settings.notificationHour,
          settings.notificationMinute,
          now,
          tirePressureCadenceDays,
        );
        results.add(
          PlannedNotification(
            id: stableNotificationId('tire:${vehicle.id}'),
            kind: PlannedNotificationKind.tirePressure,
            title: 'Tire pressure',
            body: 'Check the tire pressure of ${vehicle.name}',
            fireAt: fireAt,
            payload: notificationTapRoute,
            vehicleId: vehicle.id,
          ),
        );
      }
    }

    final horizonEnd = now.add(Duration(days: horizonDays));
    final withinHorizon = results.where((n) => !n.fireAt.isAfter(horizonEnd))
        .toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return withinHorizon.take(maxNotifications).toList();
  }
}
