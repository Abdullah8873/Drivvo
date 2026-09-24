import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_controller.dart';
import 'core/theme/app_theme.dart';

/// Root widget — the equivalent of `<App />` wrapped in the router provider.
/// Stateful so the router is created once per app instance (like a
/// `useMemo(() => createBrowserRouter(...), [])`).
class MotoLogApp extends ConsumerStatefulWidget {
  const MotoLogApp({super.key});

  @override
  ConsumerState<MotoLogApp> createState() => _MotoLogAppState();
}

class _MotoLogAppState extends ConsumerState<MotoLogApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the background sync alive for the app's lifetime (it is inert
    // without a cloud config or while signed out).
    ref.listen(syncControllerProvider, (_, _) {});
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'MotoLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
