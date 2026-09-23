import 'package:flutter/material.dart';

/// "More options" tab: settings, catalogs (fuel, types, places…) and tools.
/// Same grouping as Drivvo, minus the paid "plans" banner.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _sections = <List<(IconData, String)>>[
    [
      (Icons.person, 'My account'),
      (Icons.cloud_sync, 'Synchronize data'),
      (Icons.storage, 'Storage'),
      (Icons.swap_horiz, 'Transfer'),
    ],
    [
      (Icons.directions_car, 'Vehicles'),
      (Icons.group, 'Users'),
      (Icons.manage_accounts, 'Profiles'),
    ],
    [
      (Icons.local_gas_station, 'Fuel'),
      (Icons.ev_station, 'Gas stations'),
      (Icons.place, 'Places'),
      (Icons.build, 'Types of service'),
      (Icons.receipt_long, 'Types of expense'),
      (Icons.trending_up, 'Types of income'),
      (Icons.work, 'Reasons'),
      (Icons.payments, 'Payment methods'),
      (Icons.description, 'Forms'),
    ],
    [(Icons.map, 'My places'), (Icons.calculate, 'Flex calculator')],
    [
      (Icons.emoji_events, 'Achievements'),
      (Icons.settings, 'Settings'),
      (Icons.translate, 'Translation'),
    ],
    [(Icons.info_outline, 'About')],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More options')),
      body: ListView(
        children: [
          for (final (i, section) in _sections.indexed) ...[
            if (i > 0) const Divider(),
            for (final (icon, label) in section)
              ListTile(
                leading: Icon(icon, color: Colors.grey.shade700),
                title: Text(label),
                onTap: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label — coming soon'))),
              ),
          ],
        ],
      ),
    );
  }
}
