import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart' as csv;

import '../../core/db/tables.dart';
import '../export/csv_writer.dart';
import '../export/export_columns.dart';

/// Parsing half of CSV import: turns the bytes of a MotoLog CSV export (one
/// `.csv`, or the `.zip` of one CSV per record type) back into plain record
/// objects — the exact inverse of `export_rows.dart` + `csv_writer.dart`.
/// Pure Dart (no Flutter, no database), so every rule here is unit-tested;
/// `csv_import_service.dart` does the matching and the database writes.
///
/// File format decisions (all mirror the exporter):
/// - Tables are recognized by their header row (`export_columns.dart`),
///   matched case-insensitively and in any column order; extra columns are
///   ignored, and so is `Currency` (amounts are stored as typed).
/// - Expense, Service and Income share one layout, so their type comes from
///   the file name (`Expense.csv` inside the zip, `…-expense.csv` for a
///   single export); a lone CSV without it needs the user to pick
///   ([CsvImportBatch.needsEntryKind]).
/// - Multi-row records: consecutive rows whose record columns are identical
///   form one refueling (one row per fuel line) or one expense/service/
///   income (one row per typed item) — exactly how the exporter flattens
///   them.
/// - Dates `yyyy-MM-dd`, times `HH:mm` (seconds accepted, blank = 00:00);
///   numbers with a dot decimal and no grouping, parsed with
///   `double.parse` and never rounded; booleans `Yes`/`No`; enums by name.
/// - Checklists are recognized but not imported: the export only keeps
///   their counts and problem items, not every answer.
/// - A record with any bad cell is skipped as a whole (never half-imported)
///   and every problem is reported with its line — the spreadsheet row
///   number, header = line 1.

/// A problem in the file: which file, which spreadsheet line, what's wrong.
class ImportIssue {
  const ImportIssue(this.file, this.line, this.message);

  final String file;

  /// 1-based spreadsheet row (the header row is line 1).
  final int line;
  final String message;

  @override
  String toString() => '$file line $line: $message';
}

/// One fuel line of an [ImportedRefueling].
class ImportedFuelLine {
  const ImportedFuelLine({
    required this.fuel,
    required this.tank,
    required this.pricePerUnit,
    required this.volume,
    required this.total,
  });

  final String fuel;
  final int tank;
  final double pricePerUnit;
  final double volume;
  final double total;
}

class ImportedRefueling {
  const ImportedRefueling({
    required this.line,
    required this.vehicleName,
    required this.date,
    required this.odometer,
    required this.lines,
    required this.fullTank,
    required this.missedPrevious,
    required this.gasStation,
    required this.paymentMethod,
    required this.reason,
    required this.driver,
    required this.discount,
    required this.totalCost,
    required this.notes,
  });

  /// First spreadsheet line of the record.
  final int line;
  final String? vehicleName;
  final DateTime date;
  final double odometer;
  final List<ImportedFuelLine> lines;
  final bool fullTank;
  final bool missedPrevious;
  final String? gasStation;
  final String? paymentMethod;
  final String? reason;
  final String? driver;
  final double? discount;
  final double totalCost;
  final String? notes;
}

class ImportedEntryItem {
  const ImportedEntryItem(this.type, this.amount, {this.partNumber});

  final String type;
  final double amount;

  /// Service items only: the replaced part's number or brand.
  final String? partNumber;
}

/// One expense / service / income row of the `entries` table (for an
/// installment plan: one installment, exactly as exported).
class ImportedEntry {
  const ImportedEntry({
    required this.line,
    required this.kind,
    required this.vehicleName,
    required this.date,
    required this.odometer,
    required this.title,
    required this.items,
    required this.place,
    required this.paymentMethod,
    required this.reason,
    required this.driver,
    required this.discount,
    required this.installmentNo,
    required this.installmentCount,
    required this.totalCost,
    required this.notes,
  });

  final int line;
  final EntryKind kind;
  final String? vehicleName;
  final DateTime date;
  final double? odometer;
  final String? title;
  final List<ImportedEntryItem> items;
  final String? place;
  final String? paymentMethod;
  final String? reason;
  final String? driver;
  final double? discount;
  final int installmentNo;
  final int installmentCount;
  final double totalCost;
  final String? notes;
}

class ImportedRoute {
  const ImportedRoute({
    required this.line,
    required this.vehicleName,
    required this.mode,
    required this.origin,
    required this.startDate,
    required this.startOdometer,
    required this.destination,
    required this.endDate,
    required this.endOdometer,
    required this.valuePerDistance,
    required this.total,
    required this.cargoType,
    required this.contractor,
    required this.cargoUnit,
    required this.cargoAmount,
    required this.cargoWeight,
    required this.cargoVolume,
    required this.freightValue,
    required this.installments,
    required this.driver,
    required this.reason,
    required this.notes,
  });

  final int line;
  final String? vehicleName;
  final RouteMode mode;
  final String? origin;
  final DateTime startDate;
  final double startOdometer;
  final String? destination;
  final DateTime? endDate;
  final double? endOdometer;
  final double? valuePerDistance;
  final double? total;
  final String? cargoType;
  final String? contractor;
  final String? cargoUnit;
  final double? cargoAmount;
  final double? cargoWeight;
  final double? cargoVolume;
  final double? freightValue;
  final int installments;
  final String? driver;
  final String? reason;
  final String? notes;
}

class ImportedReading {
  const ImportedReading({
    required this.line,
    required this.vehicleName,
    required this.date,
    required this.odometer,
    required this.driver,
    required this.notes,
  });

  final int line;
  final String? vehicleName;
  final DateTime date;
  final double odometer;
  final String? driver;
  final String? notes;
}

class ImportedReminder {
  const ImportedReminder({
    required this.line,
    required this.vehicleName,
    required this.target,
    required this.type,
    required this.repeat,
    required this.byDistance,
    required this.dueOdometer,
    required this.everyDistance,
    required this.byDate,
    required this.dueDate,
    required this.everyAmount,
    required this.everyUnit,
    required this.lastDoneOdometer,
    required this.lastDoneDate,
    required this.active,
    required this.notes,
  });

  final int line;
  final String? vehicleName;
  final ReminderTarget target;
  final String type;
  final bool repeat;
  final bool byDistance;
  final double? dueOdometer;
  final double? everyDistance;
  final bool byDate;
  final DateTime? dueDate;
  final int? everyAmount;
  final PeriodUnit? everyUnit;
  final double? lastDoneOdometer;
  final DateTime? lastDoneDate;
  final bool active;
  final String? notes;
}

/// Everything read from one picked file.
class CsvImportBatch {
  CsvImportBatch();

  final refuelings = <ImportedRefueling>[];
  final entries = <ImportedEntry>[];
  final routes = <ImportedRoute>[];
  final readings = <ImportedReading>[];
  final reminders = <ImportedReminder>[];

  /// Rows that couldn't be read — each one listed, never silently dropped.
  final issues = <ImportIssue>[];

  /// Things worth telling the user that aren't errors (e.g. checklists
  /// skipped by design).
  final notices = <String>[];

  /// Data rows that were skipped because of [issues].
  int errorRowCount = 0;

  /// True when the file is a lone Expense/Service/Income table whose name
  /// doesn't say which — the entries are parsed as [entryKindUsed] and the
  /// UI should let the user choose.
  bool needsEntryKind = false;

  /// The kind given to entries of an undetermined table.
  EntryKind entryKindUsed = EntryKind.expense;

  int get recordCount =>
      refuelings.length +
      entries.length +
      routes.length +
      readings.length +
      reminders.length;

  int entryCount(EntryKind kind) => entries.where((e) => e.kind == kind).length;

  /// Every distinct vehicle name in the file (blank names excluded).
  Set<String> get vehicleNames => {
    for (final n in [
      ...refuelings.map((r) => r.vehicleName),
      ...entries.map((r) => r.vehicleName),
      ...routes.map((r) => r.vehicleName),
      ...readings.map((r) => r.vehicleName),
      ...reminders.map((r) => r.vehicleName),
    ])
      ?n,
  };
}

/// Largest file (a .csv, or a .zip) the import accepts, and the largest
/// CSV inside a .zip. A real export of years of records is a few MB; the
/// cap keeps a wrong pick (a video, a disk image) from being read into
/// memory — the UI checks it before reading the file.
const maxImportFileBytes = 20 * 1024 * 1024;

/// Zip-bomb guards: at most this many entries, and this many bytes once
/// unpacked (checked against the sizes the .zip declares before anything
/// is inflated, then against what inflating actually produced).
const _maxZipEntries = 100;
const _maxUnzippedBytes = 50 * 1024 * 1024;

const _tooLarge =
    'The file is too large to import (a MotoLog export is a few MB at most).';

/// Reads a picked file (bytes, so it works on the web too). [fileName]
/// decides whether an Expense/Service/Income table is which; pass
/// [entryKind] to override that for a single CSV (the UI's choice).
CsvImportBatch parseImportFile(
  List<int> bytes, {
  required String fileName,
  EntryKind? entryKind,
}) {
  final batch = CsvImportBatch();
  if (bytes.length > maxImportFileBytes) {
    batch.issues.add(ImportIssue(fileName, 1, _tooLarge));
    return batch;
  }
  if (_isZip(bytes)) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      batch.issues.add(ImportIssue(fileName, 1, 'The .zip file is damaged.'));
      return batch;
    }
    if (archive.files.length > _maxZipEntries) {
      batch.issues.add(
        ImportIssue(fileName, 1, 'The .zip has too many files in it.'),
      );
      return batch;
    }
    var found = false;
    var unzipped = 0;
    for (final file in archive.files) {
      final name = file.name.split('/').last;
      if (!file.isFile ||
          file.name.startsWith('__MACOSX') ||
          !name.toLowerCase().endsWith('.csv')) {
        continue;
      }
      found = true;
      // Declared size first (nothing inflated yet), then the real one.
      if (file.size > maxImportFileBytes ||
          unzipped + file.size > _maxUnzippedBytes) {
        batch.issues.add(ImportIssue(fileName, 1, _tooLarge));
        return batch;
      }
      final List<int> content;
      try {
        content = List<int>.from(file.content as List<int>);
      } catch (_) {
        batch.issues.add(ImportIssue(fileName, 1, 'The .zip file is damaged.'));
        return batch;
      }
      unzipped += content.length;
      if (content.length > maxImportFileBytes || unzipped > _maxUnzippedBytes) {
        batch.issues.add(ImportIssue(fileName, 1, _tooLarge));
        return batch;
      }
      _parseTable(batch, content, name, _entryKindFromName(name));
    }
    if (!found) {
      batch.issues.add(
        ImportIssue(fileName, 1, 'The .zip has no .csv files in it.'),
      );
    }
    return batch;
  }
  _parseTable(
    batch,
    bytes,
    fileName,
    entryKind ?? _entryKindFromName(fileName),
    singleFile: true,
  );
  return batch;
}

bool _isZip(List<int> b) =>
    b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 3 && b[3] == 4;

EntryKind? _entryKindFromName(String name) {
  final n = name.toLowerCase();
  if (n.contains('expense')) return EntryKind.expense;
  if (n.contains('service')) return EntryKind.service;
  if (n.contains('income')) return EntryKind.income;
  return null;
}

String _norm(String s) => s.trim().toLowerCase();

/// Decoder: comma/semicolon auto-detected (a spreadsheet re-save may use
/// `;`), BOM stripped, blank lines kept so row indexes stay line numbers.
final _decoder = csv.Csv(skipEmptyLines: false);

void _parseTable(
  CsvImportBatch batch,
  List<int> bytes,
  String file,
  EntryKind? entryKind, {
  bool singleFile = false,
}) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final List<List<String>> rows;
  try {
    rows = [
      for (final r in _decoder.decode(text))
        [for (final c in r) csvUnescapeCell('${c ?? ''}')],
    ];
  } catch (e) {
    batch.issues.add(ImportIssue(file, 1, 'Could not read the CSV ($e).'));
    return;
  }
  if (rows.isEmpty || rows.first.every((c) => c.trim().isEmpty)) {
    batch.issues.add(ImportIssue(file, 1, 'The file is empty.'));
    return;
  }

  final header = {for (final (i, h) in rows.first.indexed) _norm(h): i};
  // Currency and Part Number are optional so an export from before either
  // column existed still imports.
  bool has(List<String> headers) => headers
      .where((h) => h != 'Currency' && h != 'Part Number')
      .every((h) => header.containsKey(_norm(h)));

  final table = _Table(file, header, rows);
  if (has(refuelingExportHeaders)) {
    batch.refuelings.addAll(
      _parseGroups(batch, table, _refuelingLineColumns, _refueling),
    );
  } else if (has(entryExportHeaders)) {
    var kind = entryKind;
    if (kind == null) {
      kind = EntryKind.expense;
      if (singleFile) batch.needsEntryKind = true;
    }
    batch.entryKindUsed = kind;
    final k = kind;
    batch.entries.addAll(
      _parseGroups(batch, table, _entryLineColumns, (g) => _entry(g, k)),
    );
  } else if (has(routeExportHeaders)) {
    batch.routes.addAll(_parseRows(batch, table, _route));
  } else if (has(reminderExportHeaders)) {
    batch.reminders.addAll(_parseRows(batch, table, _reminder));
  } else if (has(checklistExportHeaders)) {
    final count = table.dataRows.length;
    if (count > 0) {
      batch.notices.add(
        '$file: $count checklist${count == 1 ? '' : 's'} not imported — '
        'the export keeps only their counts, not every answer.',
      );
    }
  } else if (has(readingExportHeaders)) {
    batch.readings.addAll(_parseRows(batch, table, _reading));
  } else {
    batch.issues.add(
      ImportIssue(
        file,
        1,
        'Not a MotoLog export — the column headers don\'t match any record '
        'type.',
      ),
    );
  }
}

/// A decoded table with header lookup.
class _Table {
  _Table(this.file, this.header, List<List<String>> rows) {
    for (final (i, r) in rows.indexed.skip(1)) {
      if (r.every((c) => c.trim().isEmpty)) continue;
      dataRows.add(_Row(this, i + 1, r));
    }
  }

  final String file;
  final Map<String, int> header;
  final dataRows = <_Row>[];
}

class _Row {
  _Row(this.table, this.line, this.cells);

  final _Table table;
  final int line;
  final List<String> cells;

  /// Raw cell under [column] ('' when the row is short).
  String operator [](String column) {
    final i = table.header[_norm(column)];
    if (i == null || i >= cells.length) return '';
    return cells[i];
  }

  /// Identity of the record this row belongs to: every column except
  /// [lineColumns].
  String recordKey(Set<String> lineColumns) => [
    for (final e in table.header.entries)
      if (!lineColumns.contains(e.key))
        e.value < cells.length ? cells[e.value] : '',
  ].join('\u0000');

  bool hasAny(Set<String> columns) =>
      columns.any((c) => this[c].trim().isNotEmpty);
}

/// A bad cell; the message names the column.
class _CellError implements Exception {
  _CellError(this.message);

  final String message;
}

/// One record per row; a bad row is reported and skipped.
List<T> _parseRows<T>(
  CsvImportBatch batch,
  _Table table,
  T Function(_Row row) build,
) {
  final out = <T>[];
  for (final row in table.dataRows) {
    try {
      out.add(build(row));
    } on _CellError catch (e) {
      batch.issues.add(ImportIssue(table.file, row.line, e.message));
      batch.errorRowCount++;
    }
  }
  return out;
}

/// Multi-row records: consecutive rows with identical record columns (all
/// but [lineColumns]) that each carry a line form one record. Every row is
/// checked on its own first so each bad line is reported; a record with any
/// bad row is skipped whole.
List<T> _parseGroups<T>(
  CsvImportBatch batch,
  _Table table,
  Set<String> lineColumns,
  T Function(List<_Row> group) build,
) {
  final normalized = {for (final c in lineColumns) _norm(c)};
  final groups = <List<_Row>>[];
  String? lastKey;
  for (final row in table.dataRows) {
    final key = row.recordKey(normalized);
    final continues =
        groups.isNotEmpty &&
        key == lastKey &&
        groups.last.last.hasAny(lineColumns) &&
        row.hasAny(lineColumns);
    if (continues) {
      groups.last.add(row);
    } else {
      groups.add([row]);
    }
    lastKey = key;
  }

  final out = <T>[];
  for (final group in groups) {
    final errors = <ImportIssue>[];
    for (final row in group) {
      try {
        build([row]);
      } on _CellError catch (e) {
        errors.add(ImportIssue(table.file, row.line, e.message));
      }
    }
    if (errors.isNotEmpty) {
      batch.issues.addAll(errors);
      batch.errorRowCount += group.length;
      continue;
    }
    out.add(build(group));
  }
  return out;
}

const _refuelingLineColumns = {
  'Fuel',
  'Tank',
  'Price/Unit',
  'Volume',
  'Line Total',
};

const _entryLineColumns = {'Type', 'Item Amount', 'Part Number'};

ImportedRefueling _refueling(List<_Row> group) {
  final first = group.first;
  return ImportedRefueling(
    line: first.line,
    vehicleName: _name(first['Vehicle']),
    date: _dateTime(first, 'Date', 'Time'),
    odometer: _requiredNum(first, 'Odometer'),
    lines: [
      for (final row in group)
        if (row.hasAny(_refuelingLineColumns)) _fuelLine(row),
    ],
    fullTank: _bool(first, 'Full Tank', defaultValue: true),
    missedPrevious: _bool(first, 'Missed Previous', defaultValue: false),
    gasStation: _name(first['Gas Station']),
    paymentMethod: _name(first['Payment Method']),
    reason: _name(first['Reason']),
    driver: _text(first['Driver']),
    discount: _num(first, 'Discount'),
    totalCost: _requiredNum(first, 'Total Cost'),
    notes: _text(first['Notes']),
  );
}

ImportedFuelLine _fuelLine(_Row row) {
  final fuel = _name(row['Fuel']);
  if (fuel == null) throw _CellError('Fuel is missing.');
  final tank = _int(row, 'Tank') ?? 1;
  if (tank != 1 && tank != 2) throw _CellError('Tank must be 1 or 2.');
  return ImportedFuelLine(
    fuel: fuel,
    tank: tank,
    pricePerUnit: _requiredNum(row, 'Price/Unit'),
    volume: _requiredNum(row, 'Volume'),
    total: _requiredNum(row, 'Line Total'),
  );
}

ImportedEntry _entry(List<_Row> group, EntryKind kind) {
  final first = group.first;
  final count = _int(first, 'Installment Count') ?? 1;
  final number = _int(first, 'Installment No') ?? 1;
  if (count < 1) throw _CellError('Installment Count must be 1 or more.');
  if (number < 1 || number > count) {
    throw _CellError('Installment No must be between 1 and $count.');
  }
  return ImportedEntry(
    line: first.line,
    kind: kind,
    vehicleName: _name(first['Vehicle']),
    date: _dateTime(first, 'Date', 'Time'),
    odometer: _num(first, 'Odometer'),
    title: _text(first['Title']),
    items: [
      for (final row in group)
        if (row.hasAny(_entryLineColumns)) _entryItem(row),
    ],
    place: _name(first['Place']),
    paymentMethod: _name(first['Payment Method']),
    reason: _name(first['Reason']),
    driver: _text(first['Driver']),
    discount: _num(first, 'Discount'),
    installmentNo: number,
    installmentCount: count,
    totalCost: _requiredNum(first, 'Total Cost'),
    notes: _text(first['Notes']),
  );
}

ImportedEntryItem _entryItem(_Row row) {
  final type = _name(row['Type']);
  if (type == null) throw _CellError('Type is missing.');
  return ImportedEntryItem(
    type,
    _requiredNum(row, 'Item Amount'),
    partNumber: _text(row['Part Number']),
  );
}

ImportedRoute _route(_Row row) {
  final endDate = row['End Date'].trim().isEmpty
      ? null
      : _dateTime(row, 'End Date', 'End Time');
  if (endDate == null && row['End Time'].trim().isNotEmpty) {
    throw _CellError('End Time is filled in but End Date is empty.');
  }
  return ImportedRoute(
    line: row.line,
    vehicleName: _name(row['Vehicle']),
    mode: _enum(row, 'Mode', RouteMode.values) ?? RouteMode.trip,
    origin: _text(row['Origin']),
    startDate: _dateTime(row, 'Start Date', 'Start Time'),
    startOdometer: _requiredNum(row, 'Start Odometer'),
    destination: _text(row['Destination']),
    endDate: endDate,
    endOdometer: _num(row, 'End Odometer'),
    valuePerDistance: _num(row, 'Value/Distance'),
    total: _num(row, 'Total'),
    cargoType: _text(row['Cargo Type']),
    contractor: _text(row['Contractor']),
    cargoUnit: _text(row['Cargo Unit']),
    cargoAmount: _num(row, 'Cargo Amount'),
    cargoWeight: _num(row, 'Cargo Weight'),
    cargoVolume: _num(row, 'Cargo Volume'),
    freightValue: _num(row, 'Freight Value'),
    installments: _int(row, 'Installments') ?? 1,
    driver: _text(row['Driver']),
    reason: _name(row['Reason']),
    notes: _text(row['Notes']),
  );
}

ImportedReading _reading(_Row row) => ImportedReading(
  line: row.line,
  vehicleName: _name(row['Vehicle']),
  date: _dateTime(row, 'Date', 'Time'),
  odometer: _requiredNum(row, 'Odometer'),
  driver: _text(row['Driver']),
  notes: _text(row['Notes']),
);

ImportedReminder _reminder(_Row row) {
  final target = _enum(row, 'Target', ReminderTarget.values);
  if (target == null) throw _CellError('Target is missing.');
  final type = _name(row['Type']);
  if (type == null) throw _CellError('Type is missing.');
  return ImportedReminder(
    line: row.line,
    vehicleName: _name(row['Vehicle']),
    target: target,
    type: type,
    repeat: _bool(row, 'Repeat', defaultValue: false),
    byDistance: _bool(row, 'By Distance', defaultValue: true),
    dueOdometer: _num(row, 'Due Odometer'),
    everyDistance: _num(row, 'Every Distance'),
    byDate: _bool(row, 'By Date', defaultValue: false),
    dueDate: _date(row, 'Due Date'),
    everyAmount: _int(row, 'Every Amount'),
    everyUnit: _enum(row, 'Every Unit', PeriodUnit.values),
    lastDoneOdometer: _num(row, 'Last Done Odometer'),
    lastDoneDate: _date(row, 'Last Done Date'),
    active: _bool(row, 'Active', defaultValue: true),
    notes: _text(row['Notes']),
  );
}

// ---------------------------------------------------------------------------
// Cell parsers — strict, so a mangled cell is reported instead of guessed
// ---------------------------------------------------------------------------

/// Free text exactly as written; blank = null.
String? _text(String s) => s.isEmpty ? null : s;

/// A catalog / vehicle name: trimmed; blank = null.
String? _name(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

final _numPattern = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');
final _intPattern = RegExp(r'^[+-]?\d+$');
final _datePattern = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
final _timePattern = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');

/// Exactly the typed number (`double.parse` of the text, never rounded);
/// blank = null.
double? _num(_Row row, String column) {
  final s = row[column].trim();
  if (s.isEmpty) return null;
  if (!_numPattern.hasMatch(s)) {
    throw _CellError(
      '$column "$s" is not a number (use a dot for decimals, no '
      'thousands separators).',
    );
  }
  return double.parse(s);
}

double _requiredNum(_Row row, String column) =>
    _num(row, column) ?? (throw _CellError('$column is missing.'));

int? _int(_Row row, String column) {
  final s = row[column].trim();
  if (s.isEmpty) return null;
  if (!_intPattern.hasMatch(s)) {
    throw _CellError('$column "$s" is not a whole number.');
  }
  return int.parse(s);
}

bool _bool(_Row row, String column, {required bool defaultValue}) {
  final s = _norm(row[column]);
  if (s.isEmpty) return defaultValue;
  if (const {'yes', 'y', 'true', '1'}.contains(s)) return true;
  if (const {'no', 'n', 'false', '0'}.contains(s)) return false;
  throw _CellError('$column "${row[column].trim()}" must be Yes or No.');
}

T? _enum<T extends Enum>(_Row row, String column, List<T> values) {
  final s = _norm(row[column]);
  if (s.isEmpty) return null;
  for (final v in values) {
    if (v.name.toLowerCase() == s) return v;
  }
  throw _CellError(
    '$column "${row[column].trim()}" must be one of '
    '${values.map((v) => v.name).join(', ')}.',
  );
}

DateTime? _date(_Row row, String column) {
  final s = row[column].trim();
  if (s.isEmpty) return null;
  final m = _datePattern.firstMatch(s);
  if (m != null) {
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    if (date.year == y && date.month == mo && date.day == d) return date;
  }
  throw _CellError('$column "$s" is not a date like 2024-01-31.');
}

/// [dateColumn] (required) plus [timeColumn] (blank = midnight), as local
/// time — the exporter writes local time too.
DateTime _dateTime(_Row row, String dateColumn, String timeColumn) {
  final date = _date(row, dateColumn);
  if (date == null) throw _CellError('$dateColumn is missing.');
  final s = row[timeColumn].trim();
  if (s.isEmpty) return date;
  final m = _timePattern.firstMatch(s);
  final h = m == null ? -1 : int.parse(m[1]!);
  final min = m == null ? -1 : int.parse(m[2]!);
  final sec = m?[3] == null ? 0 : int.parse(m![3]!);
  if (m == null || h > 23 || min > 59 || sec > 59) {
    throw _CellError('$timeColumn "$s" is not a time like 14:05.');
  }
  return DateTime(date.year, date.month, date.day, h, min, sec);
}
