import 'package:flutter/material.dart';

import '../../../core/theme/record_module.dart';
import 'module_report_placeholder.dart';

/// Reports → READING. TODO(reports-reading): build the real tab per
/// docs/SPEC.md → Reports with `ReportTabScaffold` + the report widgets
/// (`GeneralReportTab` is a complete example).
class ReadingReportTab extends StatelessWidget {
  const ReadingReportTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const ModuleReportPlaceholder(module: RecordModule.reading);
}
