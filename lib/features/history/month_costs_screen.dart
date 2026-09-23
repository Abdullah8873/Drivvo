import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import 'history_calc.dart';
import 'history_providers.dart';

/// Opened by tapping a month card: that month's cost-comparison donut
/// (refueling / expense / service) with a legend. Watches the month live
/// (≈ a `useQuery(['month', vehicleId, month])`), so edits and deletes made
/// while it's open show up immediately.
class MonthCostsScreen extends ConsumerWidget {
  const MonthCostsScreen({
    super.key,
    required this.vehicleId,
    required this.month,
  });

  final String vehicleId;

  /// Any day of the month to show.
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      monthSummaryProvider((vehicleId: vehicleId, month: monthOf(month))),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy').format(monthOf(month))),
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (summary) => _MonthCosts(summary: summary),
      ),
    );
  }
}

class _MonthCosts extends ConsumerWidget {
  const _MonthCosts({required this.summary});

  /// Null once every record of the month is gone.
  final MonthSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final theme = Theme.of(context);
    final costs =
        (summary?.costByModule.entries.toList() ?? [])
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final total = summary?.spent ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Cost comparison', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        if (costs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No costs this month')),
          )
        else ...[
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 64,
                    sectionsSpace: 2,
                    sections: [
                      for (final e in costs)
                        PieChartSectionData(
                          value: e.value,
                          color: e.key.color,
                          radius: 36,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: theme.textTheme.labelMedium),
                    Text(fmt.money(total), style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final e in costs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 8, backgroundColor: e.key.color),
              title: Text(e.key.label),
              subtitle: Text('${(e.value / total * 100).toStringAsFixed(1)}%'),
              trailing: Text(fmt.money(e.value)),
            ),
        ],
      ],
    );
  }
}
