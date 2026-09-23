import 'package:flutter/material.dart';

import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../../history/history_calc.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Temporary content for a module tab that hasn't been built yet: the
/// period card, a total card and monthly bars for [module]'s records.
/// Doubles as a minimal example of `ReportTabScaffold` + the report
/// widgets — replace the tab file's body with the real report.
class ModuleReportPlaceholder extends StatelessWidget {
  const ModuleReportPlaceholder({super.key, required this.module});

  final RecordModule module;

  @override
  Widget build(BuildContext context) {
    final isReading = module == RecordModule.reading;
    return ReportTabScaffold(
      modules: {module},
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final records = scope.recordsOf({module});
        final total = records.fold(0.0, (s, r) => s + r.amount);
        final byMonth = <DateTime, double>{};
        for (final r in records) {
          final m = monthOf(r.date);
          byMonth[m] = (byMonth[m] ?? 0) + r.amount;
        }
        return [
          StatGrid(
            children: [
              StatCard(
                title: module.label,
                icon: module.icon,
                color: module.color,
                valueLabel: isReading ? 'Records' : 'Total',
                value: isReading ? '${records.length}' : fmt.money(total),
                subValues: [
                  if (!isReading) ...[
                    (label: 'Records', value: '${records.length}'),
                    (
                      label: 'By day',
                      value: scope.days > 0
                          ? fmt.money(total / scope.days)
                          : StatCard.dash,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (!isReading)
            ReportSection(
              title: '${module.label} chart',
              icon: Icons.bar_chart,
              color: module.color,
              subtitle: 'Full ${module.label.toLowerCase()} report coming soon',
              child: MonthlyBarChart(
                formatValue: fmt.money,
                series: [
                  BarSeries(
                    label: module.label,
                    color: module.color,
                    values: byMonth,
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}
