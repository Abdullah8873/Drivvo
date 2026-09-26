import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/record_module.dart';
import '../general_report.dart';
import '../widgets/donut_chart.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → GENERAL: balance, distance, cost and income cards, then the
/// "Expenses and income" monthly bars, the cost-comparison donut and the
/// odometer line. All numbers come from `buildGeneralReport`.
class GeneralReportTab extends StatelessWidget {
  const GeneralReportTab({super.key});

  /// Costs are stacked in one bar per month; income stands beside them
  /// (stacking income on top of costs would add money in to money out).
  static const _costModules = [
    RecordModule.refueling,
    RecordModule.expense,
    RecordModule.service,
  ];

  @override
  Widget build(BuildContext context) {
    return ReportTabScaffold(
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final unit = scope.vehicle.distanceUnit;
        final unitLabel = Formatters.distanceUnitLabel(unit);
        final report = buildGeneralReport(
          timeline: scope.timeline,
          range: scope.range,
          days: scope.days,
        );

        String money(double? v) => v == null ? StatCard.dash : fmt.money(v);
        String perDistance(double? v) =>
            v == null ? StatCard.dash : fmt.unitPrice(v, unitLabel);
        List<StatValue> dayAndDistance(double? perDay, double? perDist) => [
          (label: 'By day', value: money(perDay)),
          (label: 'By $unitLabel', value: perDistance(perDist)),
        ];

        final modulesWithOdometer = {
          for (final p in report.odometerPoints) p.module,
        };

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-balance'),
                title: 'Balance',
                icon: Icons.account_balance_wallet,
                color: AppTheme.primary,
                value: fmt.money(report.balance),
                subValues: dayAndDistance(
                  report.balancePerDay,
                  report.balancePerDistance,
                ),
              ),
              StatCard(
                key: const Key('stat-distance'),
                title: 'Distance',
                icon: Icons.route,
                color: RecordModule.route.color,
                value: report.distance > 0
                    ? fmt.distance(report.distance, unit)
                    : StatCard.dash,
                subValues: [
                  (
                    label: 'Daily average',
                    value: report.dailyDistance == null
                        ? StatCard.dash
                        : '${report.dailyDistance!.toStringAsFixed(1)} '
                              '$unitLabel',
                  ),
                ],
              ),
              StatCard(
                key: const Key('stat-cost'),
                title: 'Cost',
                icon: Icons.payments,
                color: RecordModule.expense.color,
                value: fmt.money(report.cost),
                subValues: dayAndDistance(
                  report.costPerDay,
                  report.costPerDistance,
                ),
              ),
              StatCard(
                key: const Key('stat-income'),
                title: 'Income',
                icon: RecordModule.income.icon,
                color: RecordModule.income.color,
                value: fmt.money(report.income),
                subValues: dayAndDistance(
                  report.incomePerDay,
                  report.incomePerDistance,
                ),
              ),
            ],
          ),
          ReportSection(
            title: 'Expenses and income chart',
            icon: Icons.bar_chart,
            color: AppTheme.primary,
            subtitle: 'Per month · costs stacked, income beside',
            child: MonthlyBarChart(
              months: report.months,
              formatValue: fmt.money,
              series: [
                for (final m in _costModules)
                  BarSeries(
                    label: m.label,
                    color: m.color,
                    values: report.monthly[m] ?? const {},
                  ),
                BarSeries(
                  label: RecordModule.income.label,
                  color: RecordModule.income.color,
                  values: report.monthly[RecordModule.income] ?? const {},
                  stack: 1,
                ),
              ],
            ),
          ),
          ReportSection(
            title: 'Cost comparison chart',
            icon: Icons.pie_chart,
            color: AppTheme.primary,
            child: DonutChart(
              formatValue: fmt.money,
              slices: [
                for (final e in report.costByModule.entries)
                  DonutSlice(
                    label: e.key.label,
                    value: e.value,
                    color: e.key.color,
                  ),
              ],
            ),
          ),
          ReportSection(
            title: 'Odometer chart',
            icon: Icons.speed,
            color: AppTheme.primary,
            child: LineChartCard(
              color: Theme.of(context).colorScheme.outline,
              points: [
                for (final p in report.odometerPoints)
                  LinePoint.date(p.date, p.odometer, color: p.module.color),
              ],
              formatX: (x) => fmt.date(LinePoint.xToDate(x)),
              dateAxis: true,
              formatY: (y) => fmt.distance(y, unit),
              legend: [
                for (final m in RecordModule.values)
                  if (modulesWithOdometer.contains(m))
                    (label: m.label, color: m.color),
              ],
            ),
          ),
        ];
      },
    );
  }
}
