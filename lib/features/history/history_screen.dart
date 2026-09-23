import 'package:flutter/material.dart';

import '../../core/widgets/main_tab_app_bar.dart';

/// Home tab: timeline of every record for the selected vehicle.
/// Milestone 4 fills this with monthly summary cards and expandable rows.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainTabAppBar(
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.download),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: const _EmptyState(
        icon: Icons.format_list_bulleted,
        message: 'Tap + to add your first record',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 96, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
