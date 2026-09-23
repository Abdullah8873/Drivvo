import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared look for every report chart, derived from the theme so charts
/// follow dark mode (the "design tokens" of the charts). Data marks carry
/// the module colors; everything else here is recessive chrome.
class ChartStyle {
  ChartStyle.of(BuildContext context)
    : _scheme = Theme.of(context).colorScheme,
      _text = Theme.of(context).textTheme,
      _dark = Theme.of(context).brightness == Brightness.dark;

  final ColorScheme _scheme;
  final TextTheme _text;
  final bool _dark;

  /// Background of a report tab (cards sit on it).
  Color get page => _dark ? _scheme.surface : _scheme.surfaceContainer;

  /// Card / chart background — also used for the 2px gaps and dot rings
  /// that separate touching marks. Lighter than [page] in both themes.
  Color get surface =>
      _dark ? _scheme.surfaceContainerHigh : _scheme.surfaceContainerLowest;

  /// Hairline gridlines and the baseline.
  Color get grid => _scheme.outlineVariant.withValues(alpha: 0.6);

  /// Neutral line / reference color (e.g. a line whose dots carry color).
  Color get neutral => _scheme.outline;

  /// Axis tick labels.
  TextStyle get axis => (_text.labelSmall ?? const TextStyle()).copyWith(
    color: _scheme.onSurfaceVariant,
    fontSize: 10,
  );

  Color get tooltipBackground => _scheme.inverseSurface;

  TextStyle get tooltipTitle => TextStyle(
    color: _scheme.onInverseSurface,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  TextStyle get tooltipBody =>
      TextStyle(color: _scheme.onInverseSurface, fontSize: 11);

  /// Solid hairline gridline.
  FlLine gridLine(double _) => FlLine(color: grid, strokeWidth: 1);

  /// "Nice" y-axis step for a chart whose values go up to [max]
  /// (1/2/5 × 10ⁿ, about four lines).
  static double niceInterval(double max, {int lines = 4}) {
    if (max <= 0) return 1;
    final raw = max / lines;
    var magnitude = 1.0;
    while (magnitude * 10 <= raw) {
      magnitude *= 10;
    }
    while (magnitude > raw) {
      magnitude /= 10;
    }
    for (final step in const [1, 2, 5, 10]) {
      if (magnitude * step >= raw) return magnitude * step;
    }
    return magnitude * 10;
  }

  /// "1.2K", "35K", "1.5M" for axis ticks.
  static String compact(double value) =>
      NumberFormat.compact(locale: 'en').format(value);
}

/// One legend entry: a color key + label.
typedef LegendItem = ({String label, Color color});

/// Wrap of color dots + labels under a chart. Always shown for two or more
/// series so identity never relies on color alone; labels use text colors,
/// only the dot carries the series color.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: style),
            ],
          ),
      ],
    );
  }
}

/// Muted "nothing to chart" line used inside report sections.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty({super.key, this.message = 'No data for this period'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
