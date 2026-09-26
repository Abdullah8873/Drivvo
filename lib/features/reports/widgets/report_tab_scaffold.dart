import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/record_module.dart';
import '../../../core/widgets/max_width_body.dart';
import '../../../core/widgets/motion.dart';
import '../report_providers.dart';
import '../report_scope.dart';
import 'chart_style.dart';
import 'report_period_card.dart';

/// Builds a report tab's content from the resolved [ReportScope].
typedef ReportTabBuilder = List<Widget> Function(
  BuildContext context,
  WidgetRef ref,
  ReportScope scope,
);

/// The frame every report tab shares (≈ a layout component): handles
/// loading / errors / "no vehicle", shows the [ReportPeriodCard] on top,
/// an empty state when the period has no records of this tab, and
/// otherwise lays out whatever [builder] returns in a padded, spaced list.
///
/// A new tab is just:
/// ```dart
/// class ExpenseReportTab extends StatelessWidget {
///   const ExpenseReportTab({super.key});
///   @override
///   Widget build(BuildContext context) => ReportTabScaffold(
///     modules: const {RecordModule.expense},
///     builder: (context, ref, scope) {
///       final fmt = ref.watch(formattersProvider);
///       final records = scope.recordsOf(const {RecordModule.expense});
///       return [StatGrid(children: [...]), ReportSection(...)];
///     },
///   );
/// }
/// ```
class ReportTabScaffold extends ConsumerWidget {
  const ReportTabScaffold({
    super.key,
    required this.builder,
    this.modules,
    this.emptyMessage = 'No records in this period',
  });

  /// Which records this tab counts (period card + empty state);
  /// null = every module (General).
  final Set<RecordModule>? modules;

  final ReportTabBuilder builder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeAsync = ref.watch(reportScopeProvider);
    return ColoredBox(
      color: ChartStyle.of(context).page,
      child: scopeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (scope) {
          if (scope == null) {
            return ReportEmptyState(
              icon: Icons.two_wheeler,
              message: 'No vehicle yet',
              action: FilledButton(
                onPressed: () => context.push('/vehicles/new'),
                child: const Text('Add your first vehicle'),
              ),
            );
          }
          final records = modules == null
              ? scope.records
              : scope.recordsOf(modules!);
          final children = records.isEmpty
              ? [
                  ReportEmptyState(
                    icon: Icons.insert_chart_outlined,
                    message: emptyMessage,
                    hint: 'Tap the period above to change it',
                  ),
                ]
              : builder(context, ref, scope);
          return MaxWidthBody(
            maxWidth: 840,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                FadeSlideIn(
                  child: ReportPeriodCard(
                    count: records.length,
                    span: scope.span,
                  ),
                ),
                for (final (i, child) in children.indexed) ...[
                  const SizedBox(height: 12),
                  FadeSlideIn(index: i + 1, child: child),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Centered icon + message (+ optional hint / action) for empty reports.
class ReportEmptyState extends StatelessWidget {
  const ReportEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
