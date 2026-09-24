import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../../routes/route_math.dart';
import '../module_reports.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → ROUTE: "Value" (total; by day / by km), "Distance" (total;
/// daily average) and "Time" (total; average per route) cards, then a
/// monthly bar chart of distance. Open routes (no final odometer) are
/// excluded from distance and time, same as `RouteMath`. All numbers come
/// from `buildRouteReport`.
class RouteReportTab extends StatelessWidget {
  const RouteReportTab({super.key});

  static const _module = RecordModule.route;

  @override
  Widget build(BuildContext context) {
    return ReportTabScaffold(
      modules: const {_module},
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final unit = scope.vehicle.distanceUnit;
        final unitLabel = Formatters.distanceUnitLabel(unit);
        final report = buildRouteReport(
          records: scope.recordsOf(const {_module}),
          days: scope.days,
        );
        final totals = report.totals;

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-value-route'),
                title: 'Value',
                icon: Icons.payments,
                color: _module.color,
                value: fmt.money(totals.value),
                subValues: [
                  (
                    label: 'By day',
                    value: report.valuePerDay == null
                        ? StatCard.dash
                        : fmt.money(report.valuePerDay!),
                  ),
                  (
                    label: 'By $unitLabel',
                    value: totals.valuePerDistance == null
                        ? StatCard.dash
                        : fmt.unitPrice(totals.valuePerDistance!, unitLabel),
                  ),
                ],
              ),
              StatCard(
                key: const Key('stat-distance-route'),
                title: 'Distance',
                icon: _module.icon,
                color: _module.color,
                value: totals.distance > 0
                    ? fmt.distance(totals.distance, unit)
                    : StatCard.dash,
                subValues: [
                  (
                    label: 'Daily average',
                    value: report.days > 0 && totals.distance > 0
                        ? fmt.distance(totals.distance / report.days, unit)
                        : StatCard.dash,
                  ),
                ],
              ),
              StatCard(
                key: const Key('stat-time-route'),
                title: 'Time',
                icon: Icons.schedule,
                color: _module.color,
                value: totals.minutes > 0
                    ? RouteMath.formatDuration(totals.minutes)
                    : StatCard.dash,
                subValues: [
                  (
                    label: 'Average per route',
                    value: report.averageMinutes == null
                        ? StatCard.dash
                        : RouteMath.formatDuration(
                            report.averageMinutes!.round(),
                          ),
                  ),
                ],
              ),
            ],
          ),
          ReportSection(
            title: 'Monthly distance chart',
            icon: Icons.bar_chart,
            color: _module.color,
            child: MonthlyBarChart(
              formatValue: (v) => fmt.distance(v, unit),
              series: [
                BarSeries(
                  label: _module.label,
                  color: _module.color,
                  values: report.monthlyDistance,
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
