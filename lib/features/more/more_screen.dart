import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/access_profile.dart';
import '../../core/calc/member_access.dart';
import '../../core/db/tables.dart';
import '../../core/sharing/active_account.dart';

/// "More options" tab: settings, catalogs (fuel, types, places…) and tools.
/// Same grouping as Drivvo, minus the paid "plans" banner.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// (icon, label, route or null = not built yet)
  static final _sections = <List<(IconData, String, String?)>>[
    [
      (Icons.person, 'My account', '/account'),
      (Icons.cloud_sync, 'Synchronize data', '/sync'),
      (Icons.storage, 'Storage', '/storage'),
      (Icons.swap_horiz, 'Transfer', '/transfer'),
    ],
    [
      (Icons.directions_car, 'Vehicles', '/vehicles'),
      (Icons.group, 'Users', '/users'),
      (Icons.manage_accounts, 'Profiles', '/profiles'),
    ],
    [
      (Icons.local_gas_station, 'Fuel', _catalog(CatalogKind.fuel)),
      (Icons.ev_station, 'Gas stations', _catalog(CatalogKind.gasStation)),
      (Icons.place, 'Places', _catalog(CatalogKind.place)),
      (Icons.build, 'Types of service', _catalog(CatalogKind.serviceType)),
      (
        Icons.receipt_long,
        'Types of expense',
        _catalog(CatalogKind.expenseType),
      ),
      (Icons.trending_up, 'Types of income', _catalog(CatalogKind.incomeType)),
      (Icons.work, 'Reasons', _catalog(CatalogKind.reason)),
      (Icons.payments, 'Payment methods', _catalog(CatalogKind.paymentMethod)),
      (Icons.description, 'Forms', '/forms'),
    ],
    [
      (Icons.map, 'My places', '/places'),
      (Icons.calculate, 'Flex calculator', '/flex'),
    ],
    [
      (Icons.emoji_events, 'Achievements', '/achievements'),
      (Icons.settings, 'Settings', '/settings'),
      (Icons.translate, 'Translation', null),
      (Icons.contact_support, 'Contact', null),
    ],
    [(Icons.info_outline, 'About', null), (Icons.share, 'Share app', null)],
  ];

  static String _catalog(CatalogKind kind) => '/catalog/${kind.name}';

  /// Whether the active profile may open [route] (in a shared account a
  /// driver doesn't see Vehicles, Users, Profiles, Forms, …; Transfer
  /// only works on the user's own vehicles). Unrestricted routes: true.
  static bool _visible(String? route, MemberAccess access) {
    if (access.isOwner || route == null) return true;
    if (route == '/transfer') return false;
    final area = switch (route) {
      '/vehicles' => AccessArea.vehicles,
      '/users' => AccessArea.users,
      '/profiles' => AccessArea.profiles,
      '/forms' => AccessArea.forms,
      '/places' => AccessArea.place,
      _ when route.startsWith('/catalog/') => AccessArea.values.byName(
        route.substring('/catalog/'.length),
      ),
      _ => null,
    };
    return area == null || access.can(area, AccessAction.view);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(currentAccessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('More options')),
      body: ListView(
        children: [
          for (final (i, section) in _sections.indexed) ...[
            if (i > 0) const Divider(),
            for (final (icon, label, route) in section)
              if (_visible(route, access))
                ListTile(
                  leading: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(label),
                  onTap: () => route != null
                      ? context.push(route)
                      : ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$label — coming soon')),
                        ),
                ),
          ],
        ],
      ),
    );
  }
}
