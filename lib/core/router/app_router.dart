import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/reset_password_screen.dart';
import '../../features/account/sign_in_screen.dart';
import '../../features/account/sign_up_screen.dart';
import '../../features/achievements/achievements_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/flex/flex_screen.dart';
import '../../features/forms/entry_form_screen.dart';
import '../../features/forms/placeholder_form_screen.dart';
import '../../features/forms/reading_form_screen.dart';
import '../../features/forms/refueling_form_screen.dart';
import '../../features/forms/route_form_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/record_detail_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/reminders/reminder_form_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sync/sync_screen.dart';
import '../../features/vehicles/vehicle_form_screen.dart';
import '../../features/vehicles/vehicles_screen.dart';
import '../db/tables.dart';
import '../theme/record_module.dart';
import '../widgets/main_shell.dart';

/// App routes. The four tabs live in a StatefulShellRoute (each tab keeps its
/// own navigation stack); everything else is pushed on top, full screen.
/// A function (not a global) so every app instance — and every test — gets a
/// fresh navigation state.
///
/// Route map (use `context.push(...)`):
/// ```text
///   /add/<module>            new record form (module = RecordModule.name)
///   /edit/<module>/<id>      edit a record
///   /record/<module>/<id>    record detail view
///   /vehicles, /vehicles/new, /vehicles/<id>
///   /settings, /catalog/<CatalogKind.name>, /sync
///   /account, /account/sign-in, /account/sign-up, /account/reset-password
///   /flex                     Flex calculator (More → Flex calculator)
///   /achievements             Achievements (More → Achievements)
/// ```
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
      builder: (context, state) =>
          _form(_module(state.pathParameters['module']!), null),
    ),
    GoRoute(
      path: '/edit/:module/:id',
      builder: (context, state) => _form(
        _module(state.pathParameters['module']!),
        state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/record/:module/:id',
      builder: (context, state) => RecordDetailScreen(
        module: _module(state.pathParameters['module']!),
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
    GoRoute(
      path: '/vehicles/new',
      builder: (_, _) => const VehicleFormScreen(),
    ),
    GoRoute(
      path: '/vehicles/:id',
      builder: (_, state) => VehicleFormScreen(id: state.pathParameters['id']),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
    GoRoute(path: '/account/sign-in', builder: (_, _) => const SignInScreen()),
    GoRoute(path: '/account/sign-up', builder: (_, _) => const SignUpScreen()),
    GoRoute(
      path: '/account/reset-password',
      builder: (_, _) => const ResetPasswordScreen(),
    ),
    GoRoute(path: '/sync', builder: (_, _) => const SyncScreen()),
    GoRoute(path: '/flex', builder: (_, _) => const FlexCalculatorScreen()),
    GoRoute(
      path: '/achievements',
      builder: (_, _) => const AchievementsScreen(),
    ),
    GoRoute(
      path: '/catalog/:kind',
      builder: (_, state) => CatalogScreen(
        kind: CatalogKind.values.byName(state.pathParameters['kind']!),
      ),
    ),
  ],
);

RecordModule _module(String name) => RecordModule.values.byName(name);

Widget _form(RecordModule module, String? id) => switch (module) {
  RecordModule.refueling => RefuelingFormScreen(id: id),
  RecordModule.expense => EntryFormScreen(kind: EntryKind.expense, id: id),
  RecordModule.service => EntryFormScreen(kind: EntryKind.service, id: id),
  RecordModule.income => EntryFormScreen(kind: EntryKind.income, id: id),
  RecordModule.route => RouteFormScreen(id: id),
  RecordModule.reading => ReadingFormScreen(id: id),
  RecordModule.reminder => ReminderFormScreen(id: id),
  RecordModule.checklist => PlaceholderFormScreen(module: module),
};
