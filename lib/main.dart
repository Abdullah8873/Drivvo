import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cloud/cloud_config.dart';
import 'core/db/app_database.dart';
import 'core/notifications/local_notification_scheduler.dart';
import 'core/notifications/noop_notification_scheduler.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_scheduler.dart';
import 'core/providers.dart';

/// Entry point — like index.tsx calling createRoot(...).render(`<App />`).
/// We open the local database and load settings first, then hand both to
/// Riverpod's ProviderScope (the app-wide store/context provider).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cloud is optional: without env/cloud.json this is a no-op and the app
  // is offline-only.
  await initCloud(const CloudConfig.fromEnvironment());
  final db = AppDatabase.defaults();
  final settings = await loadSettings(db);
  // flutter_local_notifications doesn't support scheduling on web, so the
  // web build stays on the no-op scheduler (like a site with no service
  // worker registered) — everywhere else uses real OS notifications.
  final NotificationScheduler scheduler = kIsWeb
      ? const NoopNotificationScheduler()
      : LocalNotificationScheduler();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        notificationDebounceProvider.overrideWithValue(
          productionNotificationDebounce,
        ),
      ],
      child: const MotoLogApp(),
    ),
  );
}
