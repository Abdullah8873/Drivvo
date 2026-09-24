import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cloud/cloud_config.dart';
import 'core/db/app_database.dart';
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
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const MotoLogApp(),
    ),
  );
}
