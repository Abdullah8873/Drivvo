import 'package:flutter/material.dart';

import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../module_reports.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → READING: a "Distance" card (total; daily average / days
/// between readings) and, with 2+ readings, a monthly bar chart of the
/// distance driven between them. All numbers come from `buildReadingReport`.
class ReadingReportTab extends StatelessWidget {
  const ReadingReportTab({super.key});

  static const _module = RecordModule.reading;

  @override
  Widget build(BuildContext context) {
    return ReportTabScaffold(
      modules: const {_module},
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final unit = scope.vehicle.distanceUnit;
        final report = buildReadingReport(
          records: scope.recordsOf(const {_module}),
        );
        final stats = report.stats;

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-distance-reading'),
                title: 'Distance',
                icon: _module.icon,
                color: _module.color,
                value: stats.count > 0
                    ? fmt.distance(stats.distance, unit)
                    : StatCard.dash,
                subValues: [
                  (
                    label: 'Daily average',
                    value: stats.dailyAverage == null
                        ? StatCard.dash
                        : fmt.distance(stats.dailyAverage!, unit),
                  ),
                  (
                    label: 'Days between readings',
                    value: stats.averageDaysBetween == null
                        ? StatCard.dash
                        : '${stats.averageDaysBetween!.toStringAsFixed(1)} Days',
                  ),
                ],
              ),
            ],
          ),
          if (stats.count >= 2)
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
