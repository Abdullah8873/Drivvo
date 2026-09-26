import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/new_password_screen.dart';
import '../../features/account/reset_password_screen.dart';
import '../../features/account/sign_in_screen.dart';
import '../../features/account/sign_up_screen.dart';
import '../../features/achievements/achievements_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/flex/flex_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/forms/entry_form_screen.dart';
import '../../features/attachments/storage_screen.dart';
import '../../features/checklists/checklist_forms_screen.dart';
import '../../features/forms/checklist_form_screen.dart';
import '../../features/forms/reading_form_screen.dart';
import '../../features/forms/refueling_form_screen.dart';
import '../../features/forms/route_form_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/record_detail_screen.dart';
import '../../features/more/about_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/more/translation_screen.dart';
import '../../features/places/places_screen.dart';
import '../../features/reminders/reminder_form_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sharing/member_form_screen.dart';
import '../../features/sharing/profile_editor_screen.dart';
import '../../features/sharing/profiles_screen.dart';
import '../../features/sharing/reports_gate.dart';
import '../../features/sharing/transfer_screen.dart';
import '../../features/sharing/users_screen.dart';
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
///   /account, /account/sign-in, /account/sign-up, /account/reset-password,
///   /account/new-password (only reached from a password-recovery link)
///   /flex                     Flex calculator (More → Flex calculator)
///   /achievements             Achievements (More → Achievements)
///   /storage                  Attachment usage (More → Storage)
///   /forms                    Checklist templates (More → Forms)
///   /places                   My places list/map (More → My places)
///   /about                    App info + licenses (More → About)
///   /translation              Language (More → Translation)
///   /users, /users/new, /users/<id>          More → Users (sharing)
///   /profiles, /profiles/new, /profiles/<id> More → Profiles
///   /transfer                 More → Transfer
/// ```
///
/// [activeRouter] tracks the most recently created router. A tapped OS
/// notification arrives outside the widget tree (no `BuildContext` to call
/// `context.push` on), so the notification scheduler navigates through this
/// instead — the same trick a web app uses when a service worker's
/// `notificationclick` handler calls `clients.openWindow` rather than
/// reaching into a specific page's router. Each test creates its own
/// router, harmlessly overwriting this; tests never dispatch notification
/// taps.
GoRouter? activeRouter;

GoRouter createRouter() {
  final router = _buildRouter();
  activeRouter = router;
  return router;
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/history',
  // A mistyped or stale web URL gets a themed screen instead of go_router's
  // bare debug page.
  errorPageBuilder: (context, state) =>
      _materialPage(state, const _NotFoundScreen()),
  routes: [
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, shell) =>
          _materialPage(state, MainShell(navigationShell: shell)),
      branches: [
        StatefulShellBranch(
          routes: [
            _page(path: '/history', builder: (_, _) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            _page(
              path: '/reports',
              builder: (_, _) => const ReportsGate(child: ReportsScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            _page(
              path: '/reminders',
              builder: (_, _) => const RemindersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [_page(path: '/more', builder: (_, _) => const MoreScreen())],
        ),
      ],
    ),
    _page(
      path: '/add/:module',
      builder: (context, state) =>
          _form(_module(state.pathParameters['module']!), null),
    ),
    _page(
      path: '/edit/:module/:id',
      builder: (context, state) => _form(
        _module(state.pathParameters['module']!),
        state.pathParameters['id'],
      ),
    ),
    _page(
      path: '/record/:module/:id',
      builder: (context, state) => RecordDetailScreen(
        module: _module(state.pathParameters['module']!),
        id: state.pathParameters['id']!,
      ),
    ),
    _page(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
    _page(path: '/vehicles/new', builder: (_, _) => const VehicleFormScreen()),
    _page(
      path: '/vehicles/:id',
      builder: (_, state) => VehicleFormScreen(id: state.pathParameters['id']),
    ),
    _page(path: '/settings', builder: (_, _) => const SettingsScreen()),
    _page(path: '/account', builder: (_, _) => const AccountScreen()),
    _page(path: '/account/sign-in', builder: (_, _) => const SignInScreen()),
    _page(path: '/account/sign-up', builder: (_, _) => const SignUpScreen()),
    _page(
      path: '/account/reset-password',
      builder: (_, _) => const ResetPasswordScreen(),
    ),
    _page(
      path: '/account/new-password',
      builder: (_, _) => const NewPasswordScreen(),
    ),
    _page(path: '/sync', builder: (_, _) => const SyncScreen()),
    _page(path: '/places', builder: (_, _) => const MyPlacesScreen()),
    _page(path: '/flex', builder: (_, _) => const FlexCalculatorScreen()),
    _page(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
    _page(path: '/export', builder: (_, _) => const ExportScreen()),
    _page(path: '/storage', builder: (_, _) => const StorageScreen()),
    _page(path: '/forms', builder: (_, _) => const ChecklistFormsScreen()),
    _page(path: '/about', builder: (_, _) => const AboutScreen()),
    _page(path: '/translation', builder: (_, _) => const TranslationScreen()),
    _page(path: '/users', builder: (_, _) => const UsersScreen()),
    _page(path: '/users/new', builder: (_, _) => const MemberFormScreen()),
    _page(
      path: '/users/:id',
      builder: (_, state) => MemberFormScreen(id: state.pathParameters['id']),
    ),
    _page(path: '/profiles', builder: (_, _) => const ProfilesScreen()),
    _page(
      path: '/profiles/new',
      builder: (_, _) => const ProfileEditorScreen(),
    ),
    _page(
      path: '/profiles/:id',
      builder: (_, state) =>
          ProfileEditorScreen(id: state.pathParameters['id']),
    ),
    _page(path: '/transfer', builder: (_, _) => const TransferScreen()),
    _page(
      path: '/catalog/:kind',
      builder: (_, state) => CatalogScreen(
        kind: CatalogKind.values.byName(state.pathParameters['kind']!),
      ),
    ),
  ],
);

/// A route whose page is Flutter's own [MaterialPage], so pushed screens
/// get the theme's page transition (`appPageTransitionsTheme` in
/// `core/widgets/motion.dart`). A plain `GoRoute(builder: …)` can't be used:
/// go_router 18 detects the app type through `package:material_ui`'s
/// `MaterialApp`, which isn't the `package:flutter` one this app uses, so it
/// fell back to `NoTransitionPage` and screens appeared with no transition
/// at all.
GoRoute _page({required String path, required GoRouterWidgetBuilder builder}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) =>
          _materialPage(state, builder(context, state)),
    );

Page<void> _materialPage(GoRouterState state, Widget child) =>
    MaterialPage<void>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: state.extra,
      restorationId: state.pageKey.value,
      child: child,
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
  RecordModule.checklist => ChecklistFormScreen(id: id),
};

/// Shown for a URL that matches no route (web address bar, old bookmark).
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text("This page doesn't exist.", textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/history'),
              child: const Text('GO TO HISTORY'),
            ),
          ],
        ),
      ),
    ),
  );
}
