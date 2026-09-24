import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/cloud/auth_state.dart';
import 'core/notifications/notification_providers.dart';
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

class _MotoLogAppState extends ConsumerState<MotoLogApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = createRouter();

  /// App-wide SnackBar host, for messages raised outside any screen (like
  /// a failed email link) — similar to a top-level toast container.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

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
    // Keeps the background sync alive for the app's lifetime (it is inert
    // without a cloud config or while signed out).
    ref.listen(syncControllerProvider, (_, _) {});
    // Opening a password-reset email link puts Supabase in a recovery
    // session and fires this event — route straight to "Set new password"
    // wherever the user currently is, the same way a service worker's
    // notification tap navigates outside the normal widget tree.
    ref.listen(passwordRecoveryEventProvider, (_, next) {
      next.whenData((_) => _router.push('/account/new-password'));
    });
    // An emailed link that couldn't sign the user in (expired, reused, or
    // opened in another browser) — say so instead of failing silently.
    ref.listen(authLinkErrorProvider, (_, next) {
      next.whenData(
        (message) => _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 12),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        ),
      );
    });
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'MotoLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      scaffoldMessengerKey: _messengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
