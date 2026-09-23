import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/main_tab_app_bar.dart';
import 'tabs/expense_report_tab.dart';
import 'tabs/general_report_tab.dart';
import 'tabs/income_report_tab.dart';
import 'tabs/reading_report_tab.dart';
import 'tabs/refueling_report_tab.dart';
import 'tabs/route_report_tab.dart';
import 'tabs/service_report_tab.dart';

/// Reports tab: scrollable tabs (General, Refueling, Expense, …). Each tab
/// lives in its own file under `tabs/` and is built on `ReportTabScaffold`
/// (period card + stat cards + charts); the selected period is shared by
/// every tab via `reportPeriodProvider`.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _tabs = <(String, Widget)>[
    ('GENERAL', GeneralReportTab()),
    ('REFUELING', RefuelingReportTab()),
    ('EXPENSE', ExpenseReportTab()),
    ('INCOME', IncomeReportTab()),
    ('SERVICE', ServiceReportTab()),
    ('ROUTE', RouteReportTab()),
    ('READING', ReadingReportTab()),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: MainTabAppBar(
          actions: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share),
              // TODO(reports-share): share the current tab as an image/PDF.
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: ColoredBox(
              color: scheme.surface,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
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
        body: TabBarView(children: [for (final (_, tab) in _tabs) tab]),
      ),
    );
  }
}
