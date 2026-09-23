import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../report_period.dart';
import 'chart_style.dart';

/// One series of a [MonthlyBarChart]: amounts per month (keyed by the
/// month's first day, e.g. `monthOf(date)`).
class BarSeries {
  const BarSeries({
    required this.label,
    required this.color,
    required this.values,
    this.stack = 0,
  });

  final String label;
  final Color color;
  final Map<DateTime, double> values;

  /// Series with the same [stack] are stacked into one bar; different
  /// stacks stand side by side in each month (e.g. costs vs income).
  final int stack;
}

/// Monthly column chart ("2025-06 … 2026-09" along the bottom), stacked per
/// [BarSeries.stack], with a legend (2+ series) and a tap tooltip listing
/// the month's values. Scrolls sideways when there are many months,
/// starting at the most recent one.
///
/// ```dart
/// MonthlyBarChart(
///   months: report.months,                 // optional, else derived
///   formatValue: fmt.money,
///   series: [
///     BarSeries(label: 'Expense', color: RecordModule.expense.color,
///         values: byMonth),
///   ],
/// )
/// ```
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.series,
    required this.formatValue,
    this.months,
    this.height = 220,
  });

  final List<BarSeries> series;

  /// Formats a value for the tooltip (e.g. `fmt.money`).
  final String Function(double value) formatValue;

  /// X-axis months (first days). Defaults to every month from the first to
  /// the last month that has a value.
  final List<DateTime>? months;

  final double height;

  static final _monthLabel = DateFormat('yyyy-MM');

  List<DateTime> _months() {
    if (months != null) return months!;
    final keys = [
      for (final s in series)
        for (final e in s.values.entries)
          if (e.value != 0) e.key,
    ]..sort();
    return keys.isEmpty ? const [] : monthsBetween(keys.first, keys.last);
  }

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    final months = _months();
    final hasData = series.any((s) => s.values.values.any((v) => v != 0));
    if (months.isEmpty || !hasData) return const ChartEmpty();

    final stacks = {for (final s in series) s.stack}.toList()..sort();
    final rodWidth = stacks.length == 1 ? 16.0 : 10.0;
    const rodGap = 3.0;
    final groupWidth = stacks.length * rodWidth + (stacks.length - 1) * rodGap;
    // Enough room for the "2025-06" label under each month.
    final slotWidth = math.max(groupWidth + 20, 48.0);

    var maxY = 0.0;
    final groups = <BarChartGroupData>[];
    for (final (i, month) in months.indexed) {
      final rods = <BarChartRodData>[];
      for (final stack in stacks) {
        final items = <BarChartRodStackItem>[];
        var top = 0.0;
        for (final s in series.where((s) => s.stack == stack)) {
          final v = s.values[month] ?? 0;
          if (v <= 0) continue;
          items.add(
            BarChartRodStackItem(
              top,
              top + v,
              s.color,
              // A thin surface-colored edge = the gap between segments.
              borderSide: BorderSide(color: style.surface, width: 1),
            ),
          );
          top += v;
        }
        maxY = math.max(maxY, top);
        rods.add(
          BarChartRodData(
            toY: top,
            width: rodWidth,
            color: items.isEmpty ? Colors.transparent : items.first.color,
            rodStackItems: items.length > 1 ? items : const [],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        );
      }
      groups.add(BarChartGroupData(x: i, barsSpace: rodGap, barRods: rods));
    }

    final interval = ChartStyle.niceInterval(maxY);
    final chartMaxY = (maxY / interval).ceil() * interval;

    final top = chartMaxY == 0 ? interval : chartMaxY;
    const axisWidth = 40.0;
    const labelHeight = 24.0;
    final leftAxis = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: axisWidth,
        interval: interval,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(ChartStyle.compact(value), style: style.axis),
        ),
      ),
    );

    // [withAxis] false = the scrolling part of a wide chart; its y-axis is
    // drawn by [axisOnly] beside it so the ticks stay visible while the
    // months scroll.
    BarChart chart({bool withAxis = true}) => BarChart(
      BarChartData(
        maxY: top,
        alignment: BarChartAlignment.spaceAround,
        barGroups: groups,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: style.gridLine,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: style.grid)),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: withAxis ? leftAxis : const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: labelHeight,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_monthLabel.format(months[i]), style: style.axis),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => style.tooltipBackground,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 200,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = months[group.x];
              final stack = stacks[rodIndex];
              final lines = [
                for (final s in series.where((s) => s.stack == stack))
                  if ((s.values[month] ?? 0) != 0)
                    '${s.label}: ${formatValue(s.values[month]!)}',
              ];
              if (lines.isEmpty) return null;
              return BarTooltipItem(
                '${_monthLabel.format(month)}\n',
                style.tooltipTitle,
                textAlign: TextAlign.start,
                children: [
                  TextSpan(text: lines.join('\n'), style: style.tooltipBody),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Just the y-axis ticks, same scale and label band as [chart].
    final axisOnly = BarChart(
      BarChartData(
        maxY: top,
        barGroups: const [],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: leftAxis,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: labelHeight,
              getTitlesWidget: (_, _) => const SizedBox(),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final needed = months.length * slotWidth;
              if (axisWidth + needed <= constraints.maxWidth) return chart();
              return Row(
                children: [
                  SizedBox(width: axisWidth + 2, child: axisOnly),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // open on the latest months
                      child: SizedBox(
                        width: needed,
                        child: chart(withAxis: false),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 12),
          ChartLegend(
            items: [
              for (final s in series)
                if (s.values.values.any((v) => v != 0))
                  (label: s.label, color: s.color),
            ],
          ),
        ],
      ],
    );
  }
}
