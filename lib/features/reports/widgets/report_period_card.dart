import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../report_filter_screen.dart';
import '../report_period.dart';
import '../report_providers.dart';
import 'chart_style.dart';

/// The rounded card at the top of every report tab:
/// "📅 17 entries (2025-06-11 - 2026-09-17)" plus the period name. Tapping
/// it opens the [ReportFilterScreen]. `ReportTabScaffold` adds it for you.
class ReportPeriodCard extends ConsumerWidget {
  const ReportPeriodCard({super.key, required this.count, this.span});

  /// Records the tab counts in the period.
  final int count;

  /// Days covered (null = nothing to cover).
  final DateSpan? span;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final period = ref.watch(reportPeriodProvider);
    final theme = Theme.of(context);
    final entries = count == 1 ? '1 entry' : '$count entries';
    final s = span;
    final range = s == null
        ? ''
        : ' (${fmt.date(s.start)} - ${fmt.date(s.end)})';

    return Card(
      color: ChartStyle.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('report-period-card'),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const ReportFilterScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$entries$range',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      period.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
