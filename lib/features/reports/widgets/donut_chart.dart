import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_style.dart';

/// One slice of a [DonutChart].
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Part-to-whole donut with the total in the middle and a legend table
/// underneath ("● Service - PKR23,510 ........ 42.1%"), which doubles as
/// the chart's readable table view. Slices are sorted largest first;
/// zero/negative slices are dropped. Keep it to ≤ 6 slices (fold the tail
/// into "Other" before passing them in).
///
/// ```dart
/// DonutChart(
///   formatValue: fmt.money,
///   slices: [
///     for (final e in report.costByModule.entries)
///       DonutSlice(label: e.key.label, value: e.value, color: e.key.color),
///   ],
/// )
/// ```
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.formatValue,
    this.centerLabel = 'Total',
    this.size = 200,
  });

  final List<DonutSlice> slices;
  final String Function(double value) formatValue;
  final String centerLabel;

  /// Diameter of the ring.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = slices.where((s) => s.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (visible.isEmpty) return const ChartEmpty();
    final total = visible.fold(0.0, (s, e) => s + e.value);
    final ring = size * 0.16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  centerSpaceRadius: size / 2 - ring,
                  // Surface-colored gap between slices (only with 2+).
                  sectionsSpace: visible.length > 1 ? 2 : 0,
                  sections: [
                    for (final s in visible)
                      PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: ring,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ring + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatValue(total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${s.label} - ${formatValue(s.value)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${(s.value / total * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
