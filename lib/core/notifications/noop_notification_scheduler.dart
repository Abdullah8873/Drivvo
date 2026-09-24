import '../calc/notification_plan.dart';
import 'notification_scheduler.dart';

/// Does nothing. Used on the web build (`flutter_local_notifications`
/// doesn't support scheduling on web) and as the default in every test, so
/// widget tests never touch a platform channel or schedule a real timer
/// (which would fail with "A Timer is still pending" once the test ends).
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(
    List<PlannedNotification> notifications, {
    required bool vibrate,
  }) async {}

  @override
  Future<void> showNow({required String title, required String body}) async {}
}
