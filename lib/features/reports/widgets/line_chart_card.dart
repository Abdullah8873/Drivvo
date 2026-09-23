import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_style.dart';

/// One point of a [LineChartCard]. [x] is any number (an odometer, or a
/// date via [LinePoint.date]); [color] overrides the line color for this
/// point's dot (e.g. per record type on the odometer chart).
class LinePoint {
  const LinePoint({required this.x, required this.y, this.color});

  /// A point whose x is a date (see [dateToX] / [xToDate]).
  LinePoint.date(DateTime date, this.y, {this.color}) : x = dateToX(date);

  final double x;
  final double y;
  final Color? color;

  /// Dates on the x axis are stored as fractional days since the epoch.
  static double dateToX(DateTime d) =>
      d.millisecondsSinceEpoch / Duration.millisecondsPerDay;

  static DateTime xToDate(double x) => DateTime.fromMillisecondsSinceEpoch(
    (x * Duration.millisecondsPerDay).round(),
  );
}

/// Line chart with a dot on every point (2px line, dots ringed in the card
/// color so they stay legible where they overlap), an optional dashed
/// average line with a label, an optional legend, and a tap tooltip.
/// The y axis fits the data (it doesn't force zero — odometers start high).
///
/// ```dart
/// LineChartCard(
///   points: [for (final p in pts) LinePoint.date(p.date, p.odometer)],
///   color: RecordModule.refueling.color,
///   formatX: (x) => fmt.date(LinePoint.xToDate(x)),
///   formatY: (y) => fmt.distance(y, unit),
///   average: avgEfficiency,            // optional dashed line
///   averageLabel: 'Average',
/// )
/// ```
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.points,
    required this.color,
    required this.formatX,
    required this.formatY,
    this.formatAxisX,
    this.average,
    this.averageLabel = 'Average',
    this.legend = const [],
    this.height = 220,
  });

  final List<LinePoint> points;

  /// Line color, and the dot color of points without their own.
  final Color color;

  /// Tooltip formatters.
  final String Function(double x) formatX;
  final String Function(double y) formatY;

  /// Bottom-axis tick labels (defaults to [formatX]; pass something short
  /// like `MM/yy` for dates).
  final String Function(double x)? formatAxisX;

  /// Y value of the dashed reference line, if any.
  final double? average;
  final String averageLabel;

  /// Shown under the chart when not empty (e.g. which dot color is which).
  final List<LegendItem> legend;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const ChartEmpty();
    final style = ChartStyle.of(context);
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));

    var minX = sorted.first.x;
    var maxX = sorted.last.x;
    if (maxX == minX) {
      minX -= 1;
      maxX += 1;
    }
    final ys = [for (final p in sorted) p.y, ?average];
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = maxY == minY ? (maxY.abs() * 0.1 + 1) : (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;
    final yInterval = ChartStyle.niceInterval(maxY - minY);
    final xInterval = (maxX - minX) / 3;
    final axisX = formatAxisX ?? formatX;

    final chart = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: [for (final p in sorted) FlSpot(p.x, p.y)],
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: sorted[index].color ?? color,
                strokeWidth: 2,
                strokeColor: style.surface,
              ),
            ),
          ),
        ],
        extraLinesData: average == null
            ? null
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: average!,
                    color: style.neutral,
                    strokeWidth: 1,
                    dashArray: const [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: style.axis,
                      labelResolver: (line) =>
                          '$averageLabel: ${formatY(line.y)}',
                    ),
                  ),
                ],
              ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: style.gridLine,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: style.grid)),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              minIncluded: false,
              maxIncluded: false,
              interval: yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(ChartStyle.compact(value), style: style.axis),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval > 0 ? xInterval : null,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(axisX(value), style: style.axis),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => style.tooltipBackground,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 200,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${formatY(s.y)}\n',
                  style.tooltipTitle,
                  children: [
                    TextSpan(text: formatX(s.x), style: style.tooltipBody),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: chart,
          ),
        ),
        if (legend.isNotEmpty) ...[
          const SizedBox(height: 12),
          ChartLegend(items: legend),
        ],
      ],
    );
  }
}
