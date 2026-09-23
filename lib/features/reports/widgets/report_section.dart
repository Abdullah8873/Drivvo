import 'package:flutter/material.dart';

import 'chart_style.dart';
import 'stat_card.dart';

/// A full-width report card with a colored icon header, e.g.
/// "[▦] Expenses and income chart", wrapping a chart or list.
///
/// ```dart
/// ReportSection(
///   title: 'Cost comparison chart',
///   icon: Icons.pie_chart,
///   color: AppTheme.primary,
///   child: DonutChart(...),
/// )
/// ```
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;

  /// Header tile color (module color, or `AppTheme.primary` on General).
  final Color color;

  /// Optional muted line under the title (e.g. "Per month").
  final String? subtitle;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: ChartStyle.of(context).surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ModuleIconTile(icon: icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
