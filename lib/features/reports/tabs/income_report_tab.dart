import 'package:flutter/material.dart';

import '../../../core/theme/record_module.dart';
import 'module_report_placeholder.dart';

/// Reports → INCOME. TODO(reports-income): build the real tab per
/// docs/SPEC.md → Reports with `ReportTabScaffold` + the report widgets
/// (`GeneralReportTab` is a complete example).
class IncomeReportTab extends StatelessWidget {
  const IncomeReportTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const ModuleReportPlaceholder(module: RecordModule.income);
}
