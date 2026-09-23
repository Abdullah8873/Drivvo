import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/main_tab_app_bar.dart';

/// Reports tab: scrollable tabs (General, Refueling, Expense, …), each with a
/// period filter and stat cards + charts. Built out in milestone 5.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _tabs = [
    ('GENERAL', null),
    ('REFUELING', RecordModule.refueling),
    ('EXPENSE', RecordModule.expense),
    ('INCOME', RecordModule.income),
    ('SERVICE', RecordModule.service),
    ('ROUTE', RecordModule.route),
    ('READING', RecordModule.reading),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: MainTabAppBar(
          actions: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AppTheme.primary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [for (final (label, _) in _tabs) Tab(text: label)],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            for (final (label, module) in _tabs)
              Center(
                child: Text(
                  '$label report',
                  style: TextStyle(color: module?.color ?? AppTheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
