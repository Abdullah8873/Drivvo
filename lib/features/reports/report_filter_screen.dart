import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/module_form_scaffold.dart';
import '../../core/widgets/select_list_screen.dart';
import 'report_period.dart';
import 'report_providers.dart';

/// Reports "Filter" screen: a Period field (opens a select list of
/// `ReportPeriodKind`s; "Custom" opens a date-range picker), then
/// APPLY FILTER / CLEAR FILTERS. Edits a local draft (≈ form state) and
/// only writes `reportPeriodProvider` on apply, so backing out changes
/// nothing.
class ReportFilterScreen extends ConsumerStatefulWidget {
  const ReportFilterScreen({super.key});

  @override
  ConsumerState<ReportFilterScreen> createState() => _ReportFilterScreenState();
}

class _ReportFilterScreenState extends ConsumerState<ReportFilterScreen> {
  late ReportPeriod _draft = ref.read(reportPeriodProvider);

  Future<void> _pickPeriod() async {
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: 'Period',
          items: [for (final k in ReportPeriodKind.values) k.label],
          selected: _draft.label,
        ),
      ),
    );
    final label = picked?.firstOrNull;
    if (label == null || !mounted) return;
    final kind = ReportPeriodKind.values.firstWhere((k) => k.label == label);
    if (kind == ReportPeriodKind.custom) {
      await _pickCustomRange();
    } else {
      setState(() => _draft = ReportPeriod(kind));
    }
  }

  Future<void> _pickCustomRange() async {
    final now = ref.read(reportNowProvider)();
    final current = _draft.rangeAt(now);
    final initial = _draft.kind == ReportPeriodKind.custom
        ? DateTimeRange(start: _draft.customFrom!, end: _draft.customTo!)
        : current.from == null
        ? null
        : DateTimeRange(
            start: current.from!,
            end: DateTime(
              current.to!.year,
              current.to!.month,
              current.to!.day - 1,
            ),
          );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: initial,
    );
    if (range == null || !mounted) return;
    setState(() => _draft = ReportPeriod.custom(range.start, range.end));
  }

  void _apply() {
    ref.read(reportPeriodProvider.notifier).select(_draft);
    Navigator.of(context).pop();
  }

  void _clear() {
    ref.read(reportPeriodProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(formattersProvider);
    final range = _draft.rangeAt(ref.watch(reportNowProvider)());
    final isCustom = _draft.kind == ReportPeriodKind.custom;
    String? helper;
    if (range.from != null && range.to != null) {
      final last = DateTime(range.to!.year, range.to!.month, range.to!.day - 1);
      helper = '${fmt.date(range.from!)} - ${fmt.date(last)}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Filter')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
        children: [
          FieldRow(
            icon: Icons.date_range,
            helper: isCustom ? null : helper,
            child: PickerField(
              key: const Key('report-period-field'),
              label: 'Period',
              value: _draft.label,
              onTap: _pickPeriod,
            ),
          ),
          if (isCustom)
            FieldRow(
              icon: Icons.event,
              child: Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: 'Start date',
                      value: fmt.date(_draft.customFrom!),
                      onTap: _pickCustomRange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PickerField(
                      label: 'End date',
                      value: fmt.date(_draft.customTo!),
                      onTap: _pickCustomRange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: _apply,
                child: const Text('APPLY FILTER'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _clear,
                child: const Text('CLEAR FILTERS'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
