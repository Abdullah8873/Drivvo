import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/tables.dart';

/// "More options" tab: settings, catalogs (fuel, types, places…) and tools.
/// Same grouping as Drivvo, minus the paid "plans" banner.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  /// (icon, label, route or null = not built yet)
  static final _sections = <List<(IconData, String, String?)>>[
    [
      (Icons.person, 'My account', '/account'),
      (Icons.cloud_sync, 'Synchronize data', '/sync'),
      (Icons.storage, 'Storage', null),
      (Icons.swap_horiz, 'Transfer', null),
    ],
    [
      (Icons.directions_car, 'Vehicles', '/vehicles'),
      (Icons.group, 'Users', null),
      (Icons.manage_accounts, 'Profiles', null),
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
      (Icons.description, 'Forms', null),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More options')),
      body: ListView(
        children: [
          for (final (i, section) in _sections.indexed) ...[
            if (i > 0) const Divider(),
            for (final (icon, label, route) in section)
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
