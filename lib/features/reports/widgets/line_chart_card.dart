import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/calc/date_axis.dart';

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

/// One line of a multi-series [LineChartCard] (e.g. one per fuel), drawn in
/// [color]. [formatY] labels this series' tooltips in its own unit (km/L vs
/// km/kg); null = the chart's `formatY`.
class LineSeries {
  const LineSeries({required this.points, required this.color, this.formatY});

  final List<LinePoint> points;
  final Color color;
  final String Function(double y)? formatY;
}

/// Line chart with a dot on every point (2px line, dots ringed in the card
/// color so they stay legible where they overlap), an optional dashed
/// average line with a label, an optional legend, and a tap tooltip.
/// The y axis fits the data (it doesn't force zero — odometers start high).
///
/// One line: pass [points]. Several independent lines (one per fuel, so
/// the chart never zig-zags between fuels): pass [series] instead.
///
/// Date x axes ([dateAxis]) get calendar-aligned ticks from
/// [DateAxisTicks] (month starts "2025-06", or days for short ranges)
/// instead of evenly spaced ones that match no record.
///
/// ```dart
/// LineChartCard(
///   points: [for (final p in pts) LinePoint.date(p.date, p.odometer)],
///   dateAxis: true,
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
    this.points = const [],
    this.series = const [],
    required this.color,
    required this.formatX,
    required this.formatY,
    this.formatAxisX,
    this.dateAxis = false,
    this.average,
    this.averageLabel = 'Average',
    this.legend = const [],
    this.height = 220,
  });

  /// The single line's points (ignored when [series] is not empty).
  final List<LinePoint> points;

  /// Several lines, each with its own color / tooltip unit.
  final List<LineSeries> series;

  /// Line color, and the dot color of points without their own.
  final Color color;

  /// Tooltip formatters.
  final String Function(double x) formatX;
  final String Function(double y) formatY;

  /// Bottom-axis tick labels (defaults to [formatX]; pass something short
  /// like `MM/yy` for dates).
  final String Function(double x)? formatAxisX;

  /// The x values are dates ([LinePoint.date]): label the axis with
  /// calendar-aligned ticks ([DateAxisTicks]); [formatAxisX] is unused.
  final bool dateAxis;

  /// Y value of the dashed reference line, if any (labelled with
  /// [formatY]).
  final double? average;
  final String averageLabel;

  /// Shown under the chart when not empty (e.g. which dot color is which).
  final List<LegendItem> legend;

  final double height;

  /// Minimum room (px) kept between the plot edges and an inner x label,
  /// so the edge labels never collide with their neighbours.
  static const _edgeLabelGap = 40.0;

  /// Width of the y-axis label band left of the plot.
  static const _leftAxis = 44.0;

  /// Height of the x-axis label band under the plot.
  static const _bottomAxis = 24.0;

  /// Room one date label gets ("2025-06-11" at 10 px is ~56 px wide).
  static const _dateLabelSlot = 72.0;

  /// Tick spacing needed per label kind, so labels never touch.
  static const _monthTickSpacing = 60.0;
  static const _dayTickSpacing = 78.0;

  /// True when [min]..[max] is only floating-point noise (prices computed as
  /// cost / volume give 293.03 and 293.03000000000003). Treating such a range
  /// as real yields an axis step smaller than a `double` can add to the
  /// values, and fl_chart's tick loop then never advances — the app freezes.
  static bool _isFlat(double min, double max) =>
      (max - min).abs() <= 1e-9 * (1 + max.abs());

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final s
          in series.isNotEmpty
              ? series
              : [LineSeries(points: points, color: color)])
        if (s.points.isNotEmpty)
          LineSeries(
            points: [...s.points]..sort((a, b) => a.x.compareTo(b.x)),
            color: s.color,
            formatY: s.formatY,
          ),
    ];
    if (lines.isEmpty) return const ChartEmpty();
    final style = ChartStyle.of(context);
    final all = [for (final l in lines) ...l.points];

    var minX = all.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    var maxX = all.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    if (_isFlat(minX, maxX)) {
      minX -= 1;
      maxX += 1;
    }
    final ys = [for (final p in all) p.y, ?average];
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = _isFlat(minY, maxY)
        ? (maxY.abs() * 0.1 + 1)
        : (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;
    final yInterval = ChartStyle.niceInterval(maxY - minY);
    final xInterval = (maxX - minX) / 3;
    final axisX = formatAxisX ?? formatX;

    double toPx(double x, double plotWidth) =>
        (x - minX) / (maxX - minX) * plotWidth;

    DateAxisTicks dateTicks(double plotWidth) => DateAxisTicks.compute(
      LinePoint.xToDate(minX),
      LinePoint.xToDate(maxX),
      maxMonthTicks: (plotWidth / _monthTickSpacing).floor(),
      maxDayTicks: (plotWidth / _dayTickSpacing).floor(),
    );

    Widget chart(double plotWidth, DateAxisTicks? ticks) => LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          for (final l in lines)
            LineChartBarData(
              spots: [for (final p in l.points) FlSpot(p.x, p.y)],
              color: l.color,
              barWidth: 2,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: l.points[index].color ?? l.color,
                      strokeWidth: 2,
                      strokeColor: style.surface,
                    ),
              ),
            ),
        ],
        extraLinesData: ExtraLinesData(
          // Faint guides at the date ticks, so each label reads as a line.
          verticalLines: [
            for (final d in ticks?.ticks ?? const <DateTime>[])
              VerticalLine(
                x: LinePoint.dateToX(d),
                color: style.grid,
                strokeWidth: 1,
              ),
          ],
          horizontalLines: [
            if (average != null)
              HorizontalLine(
                y: average!,
                color: style.neutral,
                strokeWidth: 1,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: style.axis,
                  labelResolver: (line) => '$averageLabel: ${formatY(line.y)}',
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
              reservedSize: _leftAxis,
              minIncluded: false,
              maxIncluded: false,
              interval: yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  ChartStyle.compact(value, step: yInterval),
                  style: style.axis,
                ),
              ),
            ),
          ),
          // Date axes draw their own labels under the chart (see below).
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: ticks == null,
              reservedSize: _bottomAxis,
              // The forced min/max labels land right next to the first /
              // last interval label and overlap it; inner labels only.
              minIncluded: false,
              maxIncluded: false,
              interval: xInterval > 0 ? xInterval : null,
              getTitlesWidget: (value, meta) {
                final px = toPx(value, plotWidth);
                if (px < _edgeLabelGap || px > plotWidth - _edgeLabelGap) {
                  return const SizedBox();
                }
                // Points close together (two refuels on one day) give ticks
                // with the same text ("24 sep", "24 sep"); show it once.
                // Compare with the previous tick only if it is itself shown
                // (not the unlabeled min edge or inside the edge gap).
                final label = axisX(value);
                final i = ((value - minX) / xInterval).round();
                final previous = minX + (i - 1) * xInterval;
                final previousPx =
                    (previous - minX) / (maxX - minX) * plotWidth;
                if (i >= 2 &&
                    previousPx >= _edgeLabelGap &&
                    axisX(previous) == label) {
                  return const SizedBox();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(label, style: style.axis),
                );
              },
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
                  '${(lines[s.barIndex].formatY ?? formatY)(s.y)}\n',
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
            child: LayoutBuilder(
              // Plot width = card width minus the reserved y-axis band.
              builder: (context, constraints) {
                final plotWidth = constraints.maxWidth - _leftAxis;
                if (!dateAxis) return chart(plotWidth, null);
                final ticks = dateTicks(plotWidth);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: chart(plotWidth, ticks)),
                    SizedBox(
                      height: _bottomAxis,
                      child: Stack(
                        children: [
                          for (final d in ticks.ticks)
                            Positioned(
                              // Centered on its tick, kept inside the card.
                              left:
                                  (_leftAxis +
                                          toPx(
                                            LinePoint.dateToX(d),
                                            plotWidth,
                                          ) -
                                          _dateLabelSlot / 2)
                                      .clamp(
                                        0.0,
                                        math.max(
                                          0.0,
                                          constraints.maxWidth - _dateLabelSlot,
                                        ),
                                      ),
                              top: 6,
                              width: _dateLabelSlot,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  ticks.label(d),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: style.axis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
