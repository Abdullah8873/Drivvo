import '../calc/notification_plan.dart';

/// Talks to the OS notification system. Roughly the mobile equivalent of a
/// Web Push service worker: `init` is like registering the service worker
/// and its notification permission, `schedule` is like telling it which
/// pushes to expect, and `showNow` is like firing one immediately for
/// testing.
///
/// There are two implementations: [LocalNotificationScheduler] (real OS
/// notifications, via `flutter_local_notifications`) and a no-op used on the
/// web build (the plugin doesn't support web scheduling) and in tests (so
/// widget tests never touch a platform channel or leave a timer running).
abstract class NotificationScheduler {
  /// Sets up the plugin (notification channel, timezone database). Safe to
  /// call more than once. Every other method calls this itself, so callers
  /// don't strictly need to — it's exposed so the app can warm it up early.
  Future<void> init();

  /// Asks the OS for permission to show notifications (Android 13+, iOS).
  /// Returns whether permission was granted. Call this the first time the
  /// user creates a reminder, not unconditionally at app launch.
  Future<bool> requestPermission();

  /// Cancels every pending scheduled notification.
  Future<void> cancelAll();

  /// Schedules every notification in [notifications], replacing any pending
  /// one with the same id. [vibrate] mirrors the "Vibrate when notifying"
  /// setting (passed in rather than read here, so this layer doesn't need
  /// to know about `AppSettings`).
  Future<void> schedule(
    List<PlannedNotification> notifications, {
    required bool vibrate,
  });

  /// Shows a notification immediately — used by the "Send test
  /// notification" row in Settings so the owner can verify delivery works
  /// on their phone.
  Future<void> showNow({required String title, required String body});
}
