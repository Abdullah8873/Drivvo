import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/notifications/notification_providers.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget — the equivalent of `<App />` wrapped in the router provider.
/// Stateful so the router is created once per app instance (like a
/// `useMemo(() => createBrowserRouter(...), [])`).
class MotoLogApp extends ConsumerStatefulWidget {
  const MotoLogApp({super.key});

  @override
  ConsumerState<MotoLogApp> createState() => _MotoLogAppState();
}

class _MotoLogAppState extends ConsumerState<MotoLogApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Starts NotificationController listening (see notification_providers.dart)
    // and gives it a first chance to reschedule for "today" — like a service
    // worker checking its push subscription is still current on page load.
    ref.read(notificationControllerProvider).reschedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Time has passed since the plan was last built for "today" — a
      // reminder may have become due, or its warn window may have opened,
      // while the app was in the background.
      ref.read(notificationControllerProvider).reschedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
