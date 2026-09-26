import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../module_reports.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → READING: a "Distance" card (total; daily average / days
/// between readings) and a monthly bar chart of the distance driven
/// between readings. Distance is measured from the last reading before the
/// period and averaged over the period's days, like the General tab. All
/// numbers come from `buildReadingReport`.
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
        final unitLabel = Formatters.distanceUnitLabel(unit);
        final report = buildReadingReport(
          timeline: scope.timeline,
          range: scope.range,
          days: scope.days,
        );

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-distance-reading'),
                title: 'Distance',
                icon: _module.icon,
                color: _module.color,
                value: report.distance > 0
                    ? fmt.distance(report.distance, unit)
                    : StatCard.dash,
                subValues: [
                  (
                    label: 'Daily average',
                    value: report.dailyAverage == null
                        ? StatCard.dash
                        : '${fmt.number(report.dailyAverage!, decimals: 1)} '
                              '$unitLabel',
                  ),
                  (
                    label: 'Days between readings',
                    value: report.averageDaysBetween == null
                        ? StatCard.dash
                        : '${fmt.number(report.averageDaysBetween!, decimals: 1)}'
                              ' Days',
                  ),
                ],
              ),
            ],
          ),
          if (report.monthlyDistance.isNotEmpty)
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
