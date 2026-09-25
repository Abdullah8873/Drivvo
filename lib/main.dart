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
import 'core/web/persistent_storage.dart';

/// Entry point — like index.tsx calling createRoot(...).render(`<App />`).
/// We open the local database and load settings first, then hand both to
/// Riverpod's ProviderScope (the app-wide store/context provider).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: ask the browser not to evict the IndexedDB database under disk
  // pressure. Fire-and-forget (not awaited); a no-op on native.
  requestPersistentStorage();
  // Opening the database (+ migrations, first-launch seeding) and reading
  // the settings don't depend on the cloud, so they start first and run
  // while Supabase restores its session — like `Promise.all` instead of
  // two awaits in a row. On native, drift opens SQLite on a background
  // isolate, so this really overlaps.
  final db = AppDatabase.defaults();
  final settingsLoading = loadSettings(db);
  // Cloud is optional: without env/cloud.json this is a no-op and the app
  // is offline-only.
  await initCloud(const CloudConfig.fromEnvironment());
  final settings = await settingsLoading;
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
