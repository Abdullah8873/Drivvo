import 'package:flutter/material.dart';

import 'chart_style.dart';

/// A small labelled figure inside a [StatCard] ("By day · PKR12").
typedef StatValue = ({String label, String value});

/// A report figure card, Drivvo style:
///
/// ```text
/// [■] Cost
/// Total
/// PKR23,510          ← big, in [color]
/// By day    By km
/// PKR89     PKR4.120/km
/// ↓ Lower PKR300   ↑ Larger PKR5,000   (optional)
/// ```
///
/// ```dart
/// StatCard(
///   title: 'Cost',
///   icon: RecordModule.expense.icon,
///   color: RecordModule.expense.color,
///   value: fmt.money(report.cost),
///   subValues: [(label: 'By day', value: fmt.money(perDay))],
/// )
/// ```
/// Pass `'—'` (see [StatCard.dash]) for figures that can't be computed.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    this.valueLabel = 'Total',
    this.subValues = const [],
    this.lower,
    this.higher,
  });

  /// Placeholder for a figure that can't be computed (no days / distance).
  static const dash = '—';

  final String title;
  final IconData icon;

  /// Module (or teal primary) color: the icon tile and the big value.
  final Color color;

  /// The headline figure, already formatted.
  final String value;

  /// Small label above [value] ("Total", "Average"…).
  final String valueLabel;

  /// Up to ~2 secondary figures shown side by side under the value.
  final List<StatValue> subValues;

  /// Optional "Lower" / "Larger" row (lowest / highest value).
  final String? lower;
  final String? higher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);
    final smallValue = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final dense = _StatGridDensity.of(context);
    return Card(
      color: ChartStyle.of(context).surface,
      child: Padding(
        padding: EdgeInsets.all(dense ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ModuleIconTile(icon: icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(valueLabel, style: labelStyle),
            _Fit(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (subValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, s) in subValues.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label, style: labelStyle),
                          _Fit(child: Text(s.value, style: smallValue)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (lower != null || higher != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (lower != null)
                    Expanded(
                      child: _Extreme(
                        icon: Icons.arrow_downward,
                        label: 'Lower',
                        value: lower!,
                      ),
                    ),
                  if (higher != null)
                    Expanded(
                      child: _Extreme(
                        icon: Icons.arrow_upward,
                        label: 'Larger',
                        value: higher!,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded square with a white module icon (card and section headers).
class ModuleIconTile extends StatelessWidget {
  const ModuleIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: size * 0.6, color: Colors.white),
    );
  }
}

class _Extreme extends StatelessWidget {
  const _Extreme({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              _Fit(child: Text(value, style: theme.textTheme.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shrinks long figures to fit a half-width card instead of clipping them.
class _Fit extends StatelessWidget {
  const _Fit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

/// Tells the [StatCard]s inside a narrow [StatGrid] to use tighter padding
/// (an InheritedWidget ≈ a React context provider). The grid can't let each
/// card measure itself with a `LayoutBuilder`: rows use `IntrinsicHeight`
/// for equal heights, and `LayoutBuilder` has no intrinsic size.
class _StatGridDensity extends InheritedWidget {
  const _StatGridDensity({required this.dense, required super.child});

  final bool dense;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StatGridDensity>()?.dense ??
      false;

  @override
  bool updateShouldNotify(_StatGridDensity old) => old.dense != dense;
}

/// Lays [children] (usually [StatCard]s) out two per row with equal
/// heights — also on narrow phones (Drivvo keeps a 2×2 grid at 320px):
/// below [_denseWidth] the spacing and card padding shrink and long
/// figures scale down instead of the grid collapsing to one column.
///
/// ```dart
/// StatGrid(children: [balanceCard, distanceCard, costCard, incomeCard])
/// ```
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  /// Grid widths below this get the dense layout (a 360px phone's grid is
  /// ~336px wide; a 320px one's ~296px).
  static const _denseWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One column only on absurdly narrow widths (split-screen etc.).
        final columns = constraints.maxWidth < 200 ? 1 : 2;
        final dense = constraints.maxWidth < _denseWidth;
        final spacing = dense ? 8.0 : this.spacing;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i + c < children.length
                          ? children[i + c]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return _StatGridDensity(
          dense: dense,
          child: Column(children: rows),
        );
      },
    );
  }
}
