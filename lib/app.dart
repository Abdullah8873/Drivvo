import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget — the equivalent of `<App />` wrapped in the router provider.
/// Stateful so the router is created once per app instance (like a
/// `useMemo(() => createBrowserRouter(...), [])`).
class MotoLogApp extends StatefulWidget {
  const MotoLogApp({super.key});

  @override
  State<MotoLogApp> createState() => _MotoLogAppState();
}

class _MotoLogAppState extends State<MotoLogApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MotoLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // TODO(milestone-2): read from settings (light / dark / system).
      themeMode: ThemeMode.light,
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
