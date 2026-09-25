import '../../core/theme/record_module.dart';

/// Output file format on the Export screen.
enum ExportFormat { csv, excel, pdf }

extension ExportFormatLabel on ExportFormat {
  String get label => switch (this) {
    ExportFormat.csv => 'CSV',
    ExportFormat.excel => 'Excel',
    ExportFormat.pdf => 'PDF',
  };

  String get fileExtension => switch (this) {
    ExportFormat.csv => 'csv', // .zip instead when several types are picked
    ExportFormat.excel => 'xlsx',
    ExportFormat.pdf => 'pdf',
  };
}

/// Record types the Export screen offers, in the order they're listed and
/// exported.
const exportableModules = [
  RecordModule.refueling,
  RecordModule.expense,
  RecordModule.service,
  RecordModule.income,
  RecordModule.route,
  RecordModule.reading,
  RecordModule.checklist,
  RecordModule.reminder,
];

/// A custom from-to date range for the "period" export option. Both ends
/// are inclusive calendar days.
class ExportPeriod {
  const ExportPeriod({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

/// Everything picked on the Export screen, handed to `ExportService`.
class ExportOptions {
  const ExportOptions({
    required this.vehicleIds,
    required this.vehicleLabel,
    required this.period,
    required this.modules,
    required this.format,
  });

  /// The vehicle(s) to include. Empty means "no vehicle selected" (the
  /// screen disables EXPORT in that case).
  final List<String> vehicleIds;

  /// Human-readable vehicle scope for the PDF header and the file name
  /// (e.g. a vehicle's name, or "All vehicles").
  final String vehicleLabel;

  /// Null means "All time".
  final ExportPeriod? period;

  final Set<RecordModule> modules;
  final ExportFormat format;
}
