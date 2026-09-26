import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../calc/notification_plan.dart';
import '../router/app_router.dart';
import 'notification_scheduler.dart';

/// The Android notification channel every MotoLog notification is posted
/// on. Android groups notifications by channel and lets the user mute a
/// channel independently of the app, so we use one channel for all of them
/// (reminders, next refueling, tire pressure) — like a single Web Push
/// "topic".
const _channelId = 'reminders';
const _channelName = 'Reminders';
const _channelDescription =
    'Upcoming services, expenses, the next predicted refueling and tire '
    'pressure checks.';

/// Real OS notifications via `flutter_local_notifications`. Not used on the
/// web build (see [NoopNotificationScheduler]) — everywhere else this is
/// what `main.dart` wires up to [notificationSchedulerProvider].
class LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      final here = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(here.identifier));
    } catch (_) {
      // Some emulators/desktops can't report a timezone; falling back to
      // whatever `timezone` defaults to (UTC) still lets notifications
      // fire, just not necessarily at the exact wall-clock minute until a
      // real device reports its zone.
    }

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'MotoLog',
          appUserModelId: 'com.abdullah8873.motolog',
          guid: '1b1f7f0e-5a63-4b7a-9c8e-6d9f2c1a3e4b',
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.defaultImportance,
          ),
        );
  }

  /// Opens the Reminders tab — every MotoLog notification's payload is
  /// [notificationTapRoute]. [activeRouter] is whichever `GoRouter` the
  /// running app instance created (there's only ever one in a real app).
  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      activeRouter?.go(payload);
    }
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    // Desktop platforms don't gate showing notifications behind a runtime
    // permission prompt.
    return true;
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(
    List<PlannedNotification> notifications, {
    required bool vibrate,
  }) async {
    await init();
    for (final n in notifications) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.payload,
        scheduledDate: tz.TZDateTime.from(n.fireAt, tz.local),
        notificationDetails: _details(vibrate: vibrate),
        // Inexact: fine for reminders that are only ever "due around" a
        // day, and it needs no exact-alarm permission (SCHEDULE_EXACT_ALARM)
        // on Android 12+.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    await init();
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: _details(vibrate: true),
    );
  }

  NotificationDetails _details({required bool vibrate}) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      enableVibration: vibrate,
    ),
    iOS: const DarwinNotificationDetails(),
  );
}
