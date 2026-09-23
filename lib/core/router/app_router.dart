import 'package:go_router/go_router.dart';

import '../../features/forms/placeholder_form_screen.dart';
import '../../features/forms/refueling_form_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../theme/record_module.dart';
import '../widgets/main_shell.dart';

/// App routes. The four tabs live in a StatefulShellRoute (each tab keeps its
/// own navigation stack); forms are pushed on top, full screen.
/// A function (not a global) so every app instance — and every test — gets a
/// fresh navigation state.
GoRouter createRouter() => GoRouter(
  initialLocation: '/history',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reminders',
              builder: (_, _) => const RemindersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add/:module',
      builder: (context, state) {
        final module = RecordModule.values.byName(
          state.pathParameters['module']!,
        );
        return switch (module) {
          RecordModule.refueling => const RefuelingFormScreen(),
          _ => PlaceholderFormScreen(module: module),
        };
      },
    ),
  ],
);
