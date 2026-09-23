import 'package:flutter/material.dart';

import '../../../core/theme/record_module.dart';
import 'module_report_placeholder.dart';

/// Reports → SERVICE. TODO(reports-service): build the real tab per
/// docs/SPEC.md → Reports with `ReportTabScaffold` + the report widgets
/// (`GeneralReportTab` is a complete example).
class ServiceReportTab extends StatelessWidget {
  const ServiceReportTab({super.key});

  @override
  Widget build(BuildContext context) =>
      const ModuleReportPlaceholder(module: RecordModule.service);
}
