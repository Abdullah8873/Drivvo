import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../module_reports.dart';
import '../widgets/donut_chart.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → SERVICE: the "Cost" card (total; by day / by km), the monthly
/// services chart and a donut of the top service types. All numbers come
/// from `buildModuleMoneyReport`.
class ServiceReportTab extends StatelessWidget {
  const ServiceReportTab({super.key});

  static const _module = RecordModule.service;

  @override
  Widget build(BuildContext context) {
    return ReportTabScaffold(
      modules: const {_module},
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final unit = scope.vehicle.distanceUnit;
        final unitLabel = Formatters.distanceUnitLabel(unit);
        final report = buildModuleMoneyReport(
          records: scope.recordsOf(const {_module}),
          timeline: scope.timeline,
          range: scope.range,
          days: scope.days,
        );

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-cost-service'),
                title: 'Cost',
                icon: _module.icon,
                color: _module.color,
                value: fmt.money(report.total),
                subValues: [
                  (
                    label: 'By day',
                    value: report.perDay == null
                        ? StatCard.dash
                        : fmt.money(report.perDay!),
                  ),
                  (
                    label: 'By $unitLabel',
                    value: report.perDistance == null
                        ? StatCard.dash
                        : fmt.unitPrice(report.perDistance!, unitLabel),
                  ),
                ],
              ),
            ],
          ),
          ReportSection(
            title: 'Monthly services chart',
            icon: Icons.bar_chart,
            color: _module.color,
            child: MonthlyBarChart(
              formatValue: fmt.money,
              series: [
                BarSeries(
                  label: _module.label,
                  color: _module.color,
                  values: report.monthly,
                ),
              ],
            ),
          ),
          ReportSection(
            title: 'Services chart',
            icon: Icons.pie_chart,
            color: _module.color,
            child: DonutChart(
              formatValue: fmt.money,
              slices: [
                for (final t in report.typeBreakdown)
                  DonutSlice(label: t.name, value: t.amount, color: t.color),
              ],
            ),
          ),
        ];
      },
    );
  }
}
