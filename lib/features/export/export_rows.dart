import 'package:intl/intl.dart';

import '../../core/calc/checklist_math.dart';
import '../../core/db/app_database.dart';
import '../../core/theme/record_module.dart';
import 'export_data.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');
final _timeFmt = DateFormat('HH:mm');

/// Number exactly as stored, no rounding — `double.toString()` prints the
/// shortest decimal that reads back to the same value, so `293.03` and
/// `5.125` come out verbatim instead of through a fixed-decimals formatter
/// that could round them (the same reason the app avoids
/// `toStringAsFixed` when it must not alter a typed number). A whole-number
/// double (every odometer/count column is stored as `REAL`) drops its
/// redundant `.0` — that's not rounding, `9999` and `9999.0` are the exact
/// same value, just written the way someone would have typed it.
String _num(num? v) {
  if (v == null) return '';
  if (v is double && v.isFinite && v == v.roundToDouble()) {
    return v.toInt().toString();
  }
  return v.toString();
}

String _yesNo(bool v) => v ? 'Yes' : 'No';
String _text(String? v) => v ?? '';

/// One exported table: a title, header row and data rows, plus the
/// summary numbers the PDF's totals section shows for this record type.
/// Every cell is already a display string (CSV/Excel/PDF writers just lay
/// these out — they do no formatting of their own).
class ExportSection {
  const ExportSection({
    required this.module,
    required this.title,
    required this.headers,
    required this.rows,
    required this.recordCount,
    required this.moneyTotal,
  });

  final RecordModule module;
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  /// Number of source records (not export rows — a refueling with 2 fuel
  /// lines is 1 record but 2 rows).
  final int recordCount;

  /// Sum of this type's money amounts (0 for Reading/Reminder).
  final double moneyTotal;
}

/// Builds one [ExportSection] per module in [modules] that has data
/// selected, in the fixed order the Export screen lists them. Pure: no
/// database access, no Flutter — takes already-loaded [ExportData] plus the
/// [currencyCode] to stamp on money-bearing rows (numeric cells never carry
/// a currency symbol, see the module doc comment on why a column instead).
List<ExportSection> buildExportSections(
  ExportData data,
  Set<RecordModule> modules,
  String currencyCode,
) {
  return [
    if (modules.contains(RecordModule.refueling))
      _buildRefuelingSection(data, currencyCode),
    if (modules.contains(RecordModule.expense))
      _buildEntrySection(data, EntryKind.expense, currencyCode),
    if (modules.contains(RecordModule.service))
      _buildEntrySection(data, EntryKind.service, currencyCode),
    if (modules.contains(RecordModule.income))
      _buildEntrySection(data, EntryKind.income, currencyCode),
    if (modules.contains(RecordModule.route))
      _buildRouteSection(data, currencyCode),
    if (modules.contains(RecordModule.reading)) _buildReadingSection(data),
    if (modules.contains(RecordModule.checklist)) _buildChecklistSection(data),
    if (modules.contains(RecordModule.reminder)) _buildReminderSection(data),
  ];
}

ExportSection _buildChecklistSection(ExportData data) {
  final checklists = [...data.checklists]
    ..sort((a, b) => a.date.compareTo(b.date));
  final rows = [
    for (final c in checklists)
      () {
        final answers = [
          for (final a in data.checklistAnswers)
            if (a.checklistId == c.id) a,
        ];
        final counts = ChecklistCounts.of(answers.map((a) => a.status));
        final problems = [
          for (final a in answers)
            if (a.status == ChecklistStatus.problem)
              a.note == null || a.note!.trim().isEmpty
                  ? a.label
                  : '${a.label}: ${a.note}',
        ];
        return [
          data.vehicleNames[c.vehicleId] ?? '',
          _dateFmt.format(c.date),
          _timeFmt.format(c.date),
          _num(c.odometer),
          c.title,
          '${counts.ok}',
          '${counts.problem}',
          problems.join('; '),
          _text(c.driver),
          _text(c.notes),
        ];
      }(),
  ];
  return ExportSection(
    module: RecordModule.checklist,
    title: 'Checklists',
    headers: const [
      'Vehicle',
      'Date',
      'Time',
      'Odometer',
      'Form',
      'OK',
      'Problems',
      'Problem Items',
      'Driver',
      'Notes',
    ],
    rows: rows,
    recordCount: checklists.length,
    moneyTotal: 0,
  );
}

/// One row per fuel line (a refueling with a second fuel/tank produces two
/// rows sharing the same date/odometer/total-cost) — that's the clearest
/// flat layout for a spreadsheet, matching how Drivvo's own UI lists each
/// fuel line separately.
ExportSection _buildRefuelingSection(ExportData data, String currencyCode) {
  final refuelings = [...data.refuelings]
    ..sort((a, b) => a.date.compareTo(b.date));
  final fuelsByRefueling = <String, List<RefuelingFuel>>{};
  for (final f in data.refuelingFuels) {
    (fuelsByRefueling[f.refuelingId] ??= []).add(f);
  }

  final rows = <List<String>>[];
  for (final r in refuelings) {
    final lines = fuelsByRefueling[r.id] ?? const [];
    final ordered = [...lines]..sort((a, b) => a.tank.compareTo(b.tank));
    if (ordered.isEmpty) {
      rows.add([
        data.vehicleNames[r.vehicleId] ?? '',
        _dateFmt.format(r.date),
        _timeFmt.format(r.date),
        _num(r.odometer),
        '',
        '',
        '',
        '',
        '',
        _yesNo(r.fullTank),
        _yesNo(r.missedPrevious),
        _text(data.catalogNames[r.gasStationId]),
        _text(data.catalogNames[r.paymentMethodId]),
        _text(data.catalogNames[r.reasonId]),
        _text(r.driver),
        _num(r.discount),
        _num(r.totalCost),
        currencyCode,
        _text(r.notes),
      ]);
      continue;
    }
    for (final f in ordered) {
      rows.add([
        data.vehicleNames[r.vehicleId] ?? '',
        _dateFmt.format(r.date),
        _timeFmt.format(r.date),
        _num(r.odometer),
        _text(data.catalogNames[f.fuelId]),
        f.tank.toString(),
        _num(f.pricePerUnit),
        _num(f.volume),
        _num(f.total),
        _yesNo(r.fullTank),
        _yesNo(r.missedPrevious),
        _text(data.catalogNames[r.gasStationId]),
        _text(data.catalogNames[r.paymentMethodId]),
        _text(data.catalogNames[r.reasonId]),
        _text(r.driver),
        _num(r.discount),
        _num(r.totalCost),
        currencyCode,
        _text(r.notes),
      ]);
    }
  }

  return ExportSection(
    module: RecordModule.refueling,
    title: 'Refueling',
    headers: const [
      'Vehicle',
      'Date',
      'Time',
      'Odometer',
      'Fuel',
      'Tank',
      'Price/Unit',
      'Volume',
      'Line Total',
      'Full Tank',
      'Missed Previous',
      'Gas Station',
      'Payment Method',
      'Reason',
      'Driver',
      'Discount',
      'Total Cost',
      'Currency',
      'Notes',
    ],
    rows: rows,
    recordCount: refuelings.length,
    moneyTotal: refuelings.fold(0.0, (s, r) => s + r.totalCost),
  );
}

/// One row per typed item (an expense/service with 2 line items produces 2
/// rows sharing the entry's date/odometer/total). Expense, Service and
/// Income share the same `entries`/`entry_items` tables (discriminated by
/// [kind]) and so share this builder and column layout — a few columns
/// (place/payment method/discount) are usually blank for Income, which
/// Drivvo's own Income form doesn't ask for, but keeping one shared shape
/// keeps the three sheets consistent and the builder simple.
ExportSection _buildEntrySection(
  ExportData data,
  EntryKind kind,
  String currencyCode,
) {
  final entries = [...data.entries.where((e) => e.kind == kind)]
    ..sort((a, b) => a.date.compareTo(b.date));
  final itemsByEntry = <String, List<EntryItem>>{};
  for (final i in data.entryItems) {
    (itemsByEntry[i.entryId] ??= []).add(i);
  }

  final rows = <List<String>>[];
  for (final e in entries) {
    final items = itemsByEntry[e.id] ?? const [];
    if (items.isEmpty) {
      rows.add(_entryRow(data, e, null, currencyCode));
      continue;
    }
    for (final item in items) {
      rows.add(_entryRow(data, e, item, currencyCode));
    }
  }

  final (module, title) = switch (kind) {
    EntryKind.expense => (RecordModule.expense, 'Expense'),
    EntryKind.service => (RecordModule.service, 'Service'),
    EntryKind.income => (RecordModule.income, 'Income'),
  };
  return ExportSection(
    module: module,
    title: title,
    headers: const [
      'Vehicle',
      'Date',
      'Time',
      'Odometer',
      'Title',
      'Type',
      'Item Amount',
      'Place',
      'Payment Method',
      'Reason',
      'Driver',
      'Discount',
      'Installment No',
      'Installment Count',
      'Total Cost',
      'Currency',
      'Notes',
    ],
    rows: rows,
    recordCount: entries.length,
    moneyTotal: entries.fold(0.0, (s, e) => s + e.totalCost),
  );
}

List<String> _entryRow(
  ExportData data,
  Entry e,
  EntryItem? item,
  String currencyCode,
) => [
  data.vehicleNames[e.vehicleId] ?? '',
  _dateFmt.format(e.date),
  _timeFmt.format(e.date),
  _num(e.odometer),
  _text(e.title),
  item == null ? '' : _text(data.catalogNames[item.typeId]),
  item == null ? '' : _num(item.amount),
  _text(data.catalogNames[e.placeId]),
  _text(data.catalogNames[e.paymentMethodId]),
  _text(data.catalogNames[e.reasonId]),
  _text(e.driver),
  _num(e.discount),
  e.installmentNo.toString(),
  e.installmentCount.toString(),
  _num(e.totalCost),
  currencyCode,
  _text(e.notes),
];

ExportSection _buildRouteSection(ExportData data, String currencyCode) {
  final routes = [...data.routes]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final rows = [
    for (final r in routes)
      [
        data.vehicleNames[r.vehicleId] ?? '',
        r.mode.name,
        _text(r.origin),
        _dateFmt.format(r.startDate),
        _timeFmt.format(r.startDate),
        _num(r.startOdometer),
        _text(r.destination),
        r.endDate == null ? '' : _dateFmt.format(r.endDate!),
        r.endDate == null ? '' : _timeFmt.format(r.endDate!),
        _num(r.endOdometer),
        _num(r.valuePerDistance),
        _num(r.total),
        _text(r.cargoType),
        _text(r.contractor),
        _text(r.cargoUnit),
        _num(r.cargoAmount),
        _num(r.cargoWeight),
        _num(r.cargoVolume),
        _num(r.freightValue),
        r.installments.toString(),
        _text(r.driver),
        _text(data.catalogNames[r.reasonId]),
        currencyCode,
        _text(r.notes),
      ],
  ];
  return ExportSection(
    module: RecordModule.route,
    title: 'Route',
    headers: const [
      'Vehicle',
      'Mode',
      'Origin',
      'Start Date',
      'Start Time',
      'Start Odometer',
      'Destination',
      'End Date',
      'End Time',
      'End Odometer',
      'Value/Distance',
      'Total',
      'Cargo Type',
      'Contractor',
      'Cargo Unit',
      'Cargo Amount',
      'Cargo Weight',
      'Cargo Volume',
      'Freight Value',
      'Installments',
      'Driver',
      'Reason',
      'Currency',
      'Notes',
    ],
    rows: rows,
    recordCount: routes.length,
    moneyTotal: routes.fold(
      0.0,
      (s, r) =>
          s +
          (r.mode == RouteMode.freight
              ? (r.freightValue ?? 0)
              : (r.total ?? 0)),
    ),
  );
}

ExportSection _buildReadingSection(ExportData data) {
  final readings = [...data.readings]..sort((a, b) => a.date.compareTo(b.date));
  final rows = [
    for (final r in readings)
      [
        data.vehicleNames[r.vehicleId] ?? '',
        _dateFmt.format(r.date),
        _timeFmt.format(r.date),
        _num(r.odometer),
        _text(r.driver),
        _text(r.notes),
      ],
  ];
  return ExportSection(
    module: RecordModule.reading,
    title: 'Reading',
    headers: const ['Vehicle', 'Date', 'Time', 'Odometer', 'Driver', 'Notes'],
    rows: rows,
    recordCount: readings.length,
    moneyTotal: 0,
  );
}

ExportSection _buildReminderSection(ExportData data) {
  final reminders = [...data.reminders]
    ..sort((a, b) {
      final an = data.vehicleNames[a.vehicleId] ?? '';
      final bn = data.vehicleNames[b.vehicleId] ?? '';
      final byVehicle = an.compareTo(bn);
      if (byVehicle != 0) return byVehicle;
      return (a.dueDate ?? a.createdAt).compareTo(b.dueDate ?? b.createdAt);
    });
  final rows = [
    for (final r in reminders)
      [
        data.vehicleNames[r.vehicleId] ?? '',
        r.target.name,
        _text(data.catalogNames[r.typeId]),
        _yesNo(r.repeat),
        _yesNo(r.byDistance),
        _num(r.dueOdometer),
        _num(r.everyDistance),
        _yesNo(r.byDate),
        r.dueDate == null ? '' : _dateFmt.format(r.dueDate!),
        r.everyAmount?.toString() ?? '',
        r.everyUnit?.name ?? '',
        _num(r.lastDoneOdometer),
        r.lastDoneDate == null ? '' : _dateFmt.format(r.lastDoneDate!),
        _yesNo(r.active),
        _text(r.notes),
      ],
  ];
  return ExportSection(
    module: RecordModule.reminder,
    title: 'Reminders',
    headers: const [
      'Vehicle',
      'Target',
      'Type',
      'Repeat',
      'By Distance',
      'Due Odometer',
      'Every Distance',
      'By Date',
      'Due Date',
      'Every Amount',
      'Every Unit',
      'Last Done Odometer',
      'Last Done Date',
      'Active',
      'Notes',
    ],
    rows: rows,
    recordCount: reminders.length,
    moneyTotal: 0,
  );
}
