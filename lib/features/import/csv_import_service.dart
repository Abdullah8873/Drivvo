import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../readings/reading_queries.dart';
import '../reminders/reminder_queries.dart';
import '../routes/route_queries.dart';
import 'csv_import.dart';

/// What an import would do, shown before the user confirms.
class CsvImportPreview {
  const CsvImportPreview({
    required this.batch,
    required this.newCounts,
    required this.duplicateCount,
    required this.issues,
    required this.vehicleNotes,
    required this.newCatalogItems,
  });

  final CsvImportBatch batch;

  /// Records that would be added, by plural label ("refuelings" → 132), in
  /// display order. Duplicates and rows with errors are not counted.
  final Map<String, int> newCounts;

  /// Records already in the database (same type, vehicle, date/time,
  /// odometer and total) that would be skipped.
  final int duplicateCount;

  /// Parse problems plus records with no vehicle to go to.
  final List<ImportIssue> issues;

  /// How file vehicle names map to this device's vehicles, when not 1:1.
  final List<String> vehicleNotes;

  /// Catalog entries that don't exist yet and would be created, e.g.
  /// `Fuel "E85"`.
  final List<String> newCatalogItems;

  int get newCount => newCounts.values.fold(0, (s, n) => s + n);

  /// Rows skipped because of [issues] (a record's rows all count).
  int get errorRowCount =>
      batch.errorRowCount + issues.length - batch.issues.length;

  /// "132 refuelings, 40 expenses" (or "nothing new").
  String get countsLabel {
    final parts = [
      for (final e in newCounts.entries)
        if (e.value > 0)
          '${e.value} ${e.value == 1 ? _singular(e.key) : e.key}',
    ];
    return parts.isEmpty ? 'nothing new' : parts.join(', ');
  }
}

/// Outcome of [CsvImportService.run], for the SnackBar.
class CsvImportResult {
  const CsvImportResult({
    required this.importedCount,
    required this.duplicateCount,
    required this.errorRowCount,
  });

  final int importedCount;
  final int duplicateCount;
  final int errorRowCount;

  String get message {
    final parts = [
      'Imported $importedCount record${importedCount == 1 ? '' : 's'}',
      if (duplicateCount > 0)
        'skipped $duplicateCount duplicate${duplicateCount == 1 ? '' : 's'}',
      if (errorRowCount > 0)
        '$errorRowCount row${errorRowCount == 1 ? '' : 's'} with errors '
            'left out',
    ];
    return '${parts.join(', ')}.';
  }
}

String _singular(String plural) =>
    plural.endsWith('s') ? plural.substring(0, plural.length - 1) : plural;

/// Writing half of CSV import: matches a parsed [CsvImportBatch] against
/// this device's data and adds the new records.
///
/// - Vehicle: a row goes to the vehicle whose name matches its `Vehicle`
///   cell (case-insensitive); an unknown or blank name goes to the vehicle
///   selected in the app ([CsvImportPreview.vehicleNotes] says so). Moving
///   a spreadsheet to a new phone therefore "just works" with one vehicle,
///   and a multi-vehicle export lands on the right vehicles by name.
/// - Catalog names (fuels, types, stations, places, payment methods,
///   reasons) match live catalog items case-insensitively; unknown names
///   become new custom items (a new fuel takes the tank kind of the tank it
///   was put in).
/// - Duplicates — a record of the same type, vehicle, date/time (to the
///   minute, the export's precision), odometer and total already stored —
///   are skipped, so importing the same file twice adds nothing. Counted
///   per occurrence: two identical rows in a file vs one stored adds one.
/// - Everything is written in ONE transaction: an error rolls back the
///   whole import (like `BEGIN … ROLLBACK`).
///
/// Rows are inserted directly (drift companions), not through the forms'
/// `saveRefueling`/`saveEntry`: those recompute the total from the lines
/// and re-split installment plans, and an import must store every number
/// exactly as it is in the file — including each installment's own share.
/// Routes, readings and reminders go through their normal save calls,
/// which store the companion as given. The sync outbox triggers still see
/// every insert, so imported records sync like typed ones.
class CsvImportService {
  const CsvImportService();

  Future<CsvImportPreview> preview(
    AppDatabase db,
    CsvImportBatch batch, {
    required String? currentVehicleId,
  }) async {
    final plan = await _Plan.build(db, batch, currentVehicleId);
    return plan.toPreview();
  }

  Future<CsvImportResult> run(
    AppDatabase db,
    CsvImportBatch batch, {
    required String? currentVehicleId,
  }) {
    return db.transaction(() async {
      final plan = await _Plan.build(db, batch, currentVehicleId);
      final imported = await plan.write(db);
      final preview = plan.toPreview();
      return CsvImportResult(
        importedCount: imported,
        duplicateCount: preview.duplicateCount,
        errorRowCount: preview.errorRowCount,
      );
    });
  }
}

/// Minute precision (the export writes `HH:mm`).
int _minute(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute).millisecondsSinceEpoch;

int _day(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

String _n(num? v) => v?.toDouble().toString() ?? '';

String _refuelingKey(String vehicleId, DateTime date, double odo, double t) =>
    'r|$vehicleId|${_minute(date)}|${_n(odo)}|${_n(t)}';

String _entryKey(
  String vehicleId,
  EntryKind kind,
  DateTime date,
  double? odo,
  double total,
) => 'e|$vehicleId|${kind.name}|${_minute(date)}|${_n(odo)}|${_n(total)}';

String _routeKey(
  String vehicleId,
  DateTime start,
  double startOdo,
  double? endOdo,
  double? total,
  double? freight,
) =>
    'ro|$vehicleId|${_minute(start)}|${_n(startOdo)}|${_n(endOdo)}|'
    '${_n(total)}|${_n(freight)}';

String _readingKey(String vehicleId, DateTime date, double odo) =>
    'rd|$vehicleId|${_minute(date)}|${_n(odo)}';

String _reminderKey(
  String vehicleId,
  ReminderTarget target,
  String typeName,
  bool repeat,
  bool byDistance,
  double? dueOdometer,
  double? everyDistance,
  bool byDate,
  DateTime? dueDate,
  int? everyAmount,
  PeriodUnit? everyUnit,
) =>
    'rm|$vehicleId|${target.name}|${typeName.trim().toLowerCase()}|$repeat|'
    '$byDistance|${_n(dueOdometer)}|${_n(everyDistance)}|$byDate|'
    '${dueDate == null ? '' : _day(dueDate)}|${everyAmount ?? ''}|'
    '${everyUnit?.name ?? ''}';

String _catalogKey(CatalogKind kind, String name) =>
    '${kind.name}|${name.trim().toLowerCase()}';

const _catalogLabels = {
  CatalogKind.fuel: 'Fuel',
  CatalogKind.serviceType: 'Service type',
  CatalogKind.expenseType: 'Expense type',
  CatalogKind.incomeType: 'Income type',
  CatalogKind.reason: 'Reason',
  CatalogKind.paymentMethod: 'Payment method',
  CatalogKind.gasStation: 'Gas station',
  CatalogKind.place: 'Place',
};

CatalogKind _typeKind(EntryKind kind) => switch (kind) {
  EntryKind.expense => CatalogKind.expenseType,
  EntryKind.service => CatalogKind.serviceType,
  EntryKind.income => CatalogKind.incomeType,
};

/// The matching step, shared by preview and import: which vehicle each
/// record goes to, which records are duplicates, which catalog names are
/// new. Built from one consistent read of the database.
class _Plan {
  _Plan._(this.batch, this.vehicles, this.catalogIds);

  final CsvImportBatch batch;
  final Map<String, Vehicle> vehicles; // id -> vehicle
  final Map<String, String> catalogIds; // _catalogKey -> id

  /// Record (by identity) -> target vehicle id.
  final vehicleOf = Map<Object, String>.identity();

  /// Record (by identity) -> id of the stored record it duplicates.
  final duplicateOf = Map<Object, String>.identity();

  final issues = <ImportIssue>[];
  final vehicleNotes = <String>[];

  /// `_catalogKey` -> display label, for names that don't exist yet.
  final newCatalog = <String, String>{};

  static Future<_Plan> build(
    AppDatabase db,
    CsvImportBatch batch,
    String? currentVehicleId,
  ) async {
    final vehicleRows = await (db.select(
      db.vehicles,
    )..where((v) => v.deletedAt.isNull())).get();
    final catalog = await (db.select(
      db.catalogItems,
    )..where((c) => c.deletedAt.isNull())).get();
    final catalogIds = <String, String>{};
    for (final c in catalog) {
      catalogIds.putIfAbsent(_catalogKey(c.kind, c.name), () => c.id);
    }
    final plan = _Plan._(batch, {
      for (final v in vehicleRows) v.id: v,
    }, catalogIds);
    plan._resolveVehicles(currentVehicleId);
    await plan._findDuplicates(db, {for (final c in catalog) c.id: c.name});
    plan._findNewCatalogNames();
    return plan;
  }

  Iterable<Object> get _allRecords => [
    ...batch.refuelings,
    ...batch.entries,
    ...batch.routes,
    ...batch.readings,
    ...batch.reminders,
  ];

  void _resolveVehicles(String? currentVehicleId) {
    final byName = <String, String>{};
    for (final v in vehicles.values) {
      byName.putIfAbsent(v.name.trim().toLowerCase(), () => v.id);
    }
    final current =
        currentVehicleId != null && vehicles.containsKey(currentVehicleId)
        ? currentVehicleId
        : null;

    final unmatched = <String>{};
    var blank = false;
    for (final r in _allRecords) {
      final (name, line, file) = switch (r) {
        ImportedRefueling r => (r.vehicleName, r.line, 'Refueling'),
        ImportedEntry r => (r.vehicleName, r.line, _entryLabel(r.kind)),
        ImportedRoute r => (r.vehicleName, r.line, 'Route'),
        ImportedReading r => (r.vehicleName, r.line, 'Reading'),
        ImportedReminder r => (r.vehicleName, r.line, 'Reminders'),
        _ => throw StateError('unknown record'),
      };
      final matched = name == null ? null : byName[name.toLowerCase()];
      final target = matched ?? current;
      if (target == null) {
        issues.add(
          ImportIssue(
            file,
            line,
            name == null
                ? 'No vehicle given and no vehicle selected.'
                : 'No vehicle named "$name" (add it, or select a vehicle to '
                      'import into).',
          ),
        );
        continue;
      }
      if (matched == null) {
        if (name == null) {
          blank = true;
        } else {
          unmatched.add(name);
        }
      }
      vehicleOf[r] = target;
    }
    if (current != null) {
      final currentName = vehicles[current]!.name;
      for (final name in unmatched) {
        vehicleNotes.add(
          'No vehicle named "$name" — its records go to "$currentName".',
        );
      }
      if (blank) {
        vehicleNotes.add('Rows without a vehicle go to "$currentName".');
      }
    }
  }

  Future<void> _findDuplicates(
    AppDatabase db,
    Map<String, String> catalogNames,
  ) async {
    final ids = vehicleOf.values.toSet();
    if (ids.isEmpty) return;
    final existing = <String, List<String>>{};
    void add(String key, String id) => (existing[key] ??= []).add(id);

    for (final r in await (db.select(
      db.refuelings,
    )..where((r) => r.vehicleId.isIn(ids) & r.deletedAt.isNull())).get()) {
      add(_refuelingKey(r.vehicleId, r.date, r.odometer, r.totalCost), r.id);
    }
    for (final e in await (db.select(
      db.entries,
    )..where((e) => e.vehicleId.isIn(ids) & e.deletedAt.isNull())).get()) {
      add(
        _entryKey(e.vehicleId, e.kind, e.date, e.odometer, e.totalCost),
        e.id,
      );
    }
    for (final r in await (db.select(
      db.routes,
    )..where((r) => r.vehicleId.isIn(ids) & r.deletedAt.isNull())).get()) {
      add(
        _routeKey(
          r.vehicleId,
          r.startDate,
          r.startOdometer,
          r.endOdometer,
          r.total,
          r.freightValue,
        ),
        r.id,
      );
    }
    for (final r in await (db.select(
      db.readings,
    )..where((r) => r.vehicleId.isIn(ids) & r.deletedAt.isNull())).get()) {
      add(_readingKey(r.vehicleId, r.date, r.odometer), r.id);
    }
    for (final r in await (db.select(
      db.reminders,
    )..where((r) => r.vehicleId.isIn(ids) & r.deletedAt.isNull())).get()) {
      add(
        _reminderKey(
          r.vehicleId,
          r.target,
          catalogNames[r.typeId] ?? '',
          r.repeat,
          r.byDistance,
          r.dueOdometer,
          r.everyDistance,
          r.byDate,
          r.dueDate,
          r.everyAmount,
          r.everyUnit,
        ),
        r.id,
      );
    }

    for (final r in _allRecords) {
      final v = vehicleOf[r];
      if (v == null) continue;
      final key = switch (r) {
        ImportedRefueling r => _refuelingKey(
          v,
          r.date,
          r.odometer,
          r.totalCost,
        ),
        ImportedEntry r => _entryKey(
          v,
          r.kind,
          r.date,
          r.odometer,
          r.totalCost,
        ),
        ImportedRoute r => _routeKey(
          v,
          r.startDate,
          r.startOdometer,
          r.endOdometer,
          r.total,
          r.freightValue,
        ),
        ImportedReading r => _readingKey(v, r.date, r.odometer),
        ImportedReminder r => _reminderKey(
          v,
          r.target,
          r.type,
          r.repeat,
          r.byDistance,
          r.dueOdometer,
          r.everyDistance,
          r.byDate,
          r.dueDate,
          r.everyAmount,
          r.everyUnit,
        ),
        _ => throw StateError('unknown record'),
      };
      final matches = existing[key];
      if (matches != null && matches.isNotEmpty) {
        duplicateOf[r] = matches.removeLast();
      }
    }
  }

  bool _willWrite(Object r) =>
      vehicleOf.containsKey(r) && !duplicateOf.containsKey(r);

  /// Every (kind, name) a to-be-written record refers to.
  Iterable<(CatalogKind, String)> _catalogRefs(Object r) sync* {
    switch (r) {
      case ImportedRefueling r:
        for (final l in r.lines) {
          yield (CatalogKind.fuel, l.fuel);
        }
        if (r.gasStation != null) yield (CatalogKind.gasStation, r.gasStation!);
        if (r.paymentMethod != null) {
          yield (CatalogKind.paymentMethod, r.paymentMethod!);
        }
        if (r.reason != null) yield (CatalogKind.reason, r.reason!);
      case ImportedEntry r:
        for (final i in r.items) {
          yield (_typeKind(r.kind), i.type);
        }
        if (r.place != null) yield (CatalogKind.place, r.place!);
        if (r.paymentMethod != null) {
          yield (CatalogKind.paymentMethod, r.paymentMethod!);
        }
        if (r.reason != null) yield (CatalogKind.reason, r.reason!);
      case ImportedRoute r:
        if (r.reason != null) yield (CatalogKind.reason, r.reason!);
      case ImportedReminder r:
        yield (
          r.target == ReminderTarget.service
              ? CatalogKind.serviceType
              : CatalogKind.expenseType,
          r.type,
        );
    }
  }

  void _findNewCatalogNames() {
    for (final r in _allRecords.where(_willWrite)) {
      for (final (kind, name) in _catalogRefs(r)) {
        final key = _catalogKey(kind, name);
        if (!catalogIds.containsKey(key)) {
          newCatalog.putIfAbsent(key, () => '${_catalogLabels[kind]} "$name"');
        }
      }
    }
  }

  CsvImportPreview toPreview() {
    int count(Iterable<Object> records) => records.where(_willWrite).length;
    return CsvImportPreview(
      batch: batch,
      newCounts: {
        'refuelings': count(batch.refuelings),
        'expenses': count(
          batch.entries.where((e) => e.kind == EntryKind.expense),
        ),
        'services': count(
          batch.entries.where((e) => e.kind == EntryKind.service),
        ),
        'incomes': count(
          batch.entries.where((e) => e.kind == EntryKind.income),
        ),
        'routes': count(batch.routes),
        'readings': count(batch.readings),
        'reminders': count(batch.reminders),
      },
      duplicateCount: duplicateOf.length,
      issues: [...batch.issues, ...issues],
      vehicleNotes: vehicleNotes,
      newCatalogItems: newCatalog.values.toList(),
    );
  }

  // -------------------------------------------------------------------------
  // Writes (called inside the caller's transaction)
  // -------------------------------------------------------------------------

  /// Looks up (or creates) the catalog item for [name]. A new fuel gets the
  /// tank kind of the vehicle tank it went into.
  Future<String> _catalogId(
    AppDatabase db,
    CatalogKind kind,
    String name, {
    FuelKind? fuelKind,
  }) async {
    final key = _catalogKey(kind, name);
    final known = catalogIds[key];
    if (known != null) return known;
    final created = await db
        .into(db.catalogItems)
        .insertReturning(
          CatalogItemsCompanion.insert(
            kind: kind,
            name: name.trim(),
            fuelKind: Value(
              kind == CatalogKind.fuel ? (fuelKind ?? FuelKind.liquid) : null,
            ),
          ),
        );
    return catalogIds[key] = created.id;
  }

  Future<String?> _optionalCatalogId(
    AppDatabase db,
    CatalogKind kind,
    String? name,
  ) async => name == null ? null : _catalogId(db, kind, name);

  /// Adds every non-duplicate record with a vehicle; returns how many.
  Future<int> write(AppDatabase db) async {
    var written = 0;

    for (final r in batch.refuelings.where(_willWrite)) {
      final vehicleId = vehicleOf[r]!;
      final vehicle = vehicles[vehicleId]!;
      final now = DateTime.now();
      final row = await db
          .into(db.refuelings)
          .insertReturning(
            RefuelingsCompanion.insert(
              vehicleId: vehicleId,
              date: r.date,
              odometer: r.odometer,
              totalCost: r.totalCost,
              fullTank: Value(r.fullTank),
              missedPrevious: Value(r.missedPrevious),
              gasStationId: Value(
                await _optionalCatalogId(
                  db,
                  CatalogKind.gasStation,
                  r.gasStation,
                ),
              ),
              paymentMethodId: Value(
                await _optionalCatalogId(
                  db,
                  CatalogKind.paymentMethod,
                  r.paymentMethod,
                ),
              ),
              reasonId: Value(
                await _optionalCatalogId(db, CatalogKind.reason, r.reason),
              ),
              driver: Value(r.driver),
              discount: Value(r.discount),
              notes: Value(r.notes),
            ),
          );
      for (final (i, l) in r.lines.indexed) {
        await db
            .into(db.refuelingFuels)
            .insert(
              RefuelingFuelsCompanion.insert(
                refuelingId: row.id,
                fuelId: await _catalogId(
                  db,
                  CatalogKind.fuel,
                  l.fuel,
                  fuelKind: l.tank == 2 ? vehicle.tank2Kind : vehicle.tank1Kind,
                ),
                pricePerUnit: l.pricePerUnit,
                total: l.total,
                volume: l.volume,
                tank: Value(l.tank),
                // Staggered like `saveRefueling`: keeps the lines in order.
                createdAt: Value(now.add(Duration(microseconds: i))),
              ),
            );
      }
      written++;
    }

    written += await _writeEntries(db);

    for (final r in batch.routes.where(_willWrite)) {
      await db.saveRoute(
        RoutesCompanion.insert(
          vehicleId: vehicleOf[r]!,
          mode: Value(r.mode),
          origin: Value(r.origin),
          startDate: r.startDate,
          startOdometer: r.startOdometer,
          destination: Value(r.destination),
          endDate: Value(r.endDate),
          endOdometer: Value(r.endOdometer),
          valuePerDistance: Value(r.valuePerDistance),
          total: Value(r.total),
          cargoType: Value(r.cargoType),
          contractor: Value(r.contractor),
          cargoUnit: Value(r.cargoUnit),
          cargoAmount: Value(r.cargoAmount),
          cargoWeight: Value(r.cargoWeight),
          cargoVolume: Value(r.cargoVolume),
          freightValue: Value(r.freightValue),
          installments: Value(r.installments),
          driver: Value(r.driver),
          reasonId: Value(
            await _optionalCatalogId(db, CatalogKind.reason, r.reason),
          ),
          notes: Value(r.notes),
        ),
      );
      written++;
    }

    for (final r in batch.readings.where(_willWrite)) {
      await db.saveReading(
        ReadingsCompanion.insert(
          vehicleId: vehicleOf[r]!,
          date: r.date,
          odometer: r.odometer,
          driver: Value(r.driver),
          notes: Value(r.notes),
        ),
      );
      written++;
    }

    for (final r in batch.reminders.where(_willWrite)) {
      await db.insertReminder(
        RemindersCompanion.insert(
          vehicleId: vehicleOf[r]!,
          target: r.target,
          typeId: await _catalogId(
            db,
            r.target == ReminderTarget.service
                ? CatalogKind.serviceType
                : CatalogKind.expenseType,
            r.type,
          ),
          repeat: Value(r.repeat),
          byDistance: Value(r.byDistance),
          dueOdometer: Value(r.dueOdometer),
          everyDistance: Value(r.everyDistance),
          byDate: Value(r.byDate),
          dueDate: Value(r.dueDate),
          everyAmount: Value(r.everyAmount),
          everyUnit: Value(r.everyUnit),
          lastDoneOdometer: Value(r.lastDoneOdometer),
          lastDoneDate: Value(r.lastDoneDate),
          active: Value(r.active),
          notes: Value(r.notes),
        ),
      );
      written++;
    }
    return written;
  }

  /// Entries, re-linking installment plans: installment 1 of N opens a
  /// group; a later installment k of N with the same details (kind,
  /// vehicle, title, place, payment method, reason, driver, notes, types)
  /// joins it as a child (`parentId`), like the form's own plans. An
  /// installment whose first one isn't in the file stays on its own.
  Future<int> _writeEntries(AppDatabase db) async {
    final ordered = batch.entries.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.date.compareTo(b.$2.date);
        if (byDate != 0) return byDate;
        final byNo = a.$2.installmentNo.compareTo(b.$2.installmentNo);
        return byNo != 0 ? byNo : a.$1.compareTo(b.$1);
      });
    final open = <String, List<({String id, int next})>>{};
    String groupKey(ImportedEntry e) => [
      e.kind.name,
      vehicleOf[e],
      e.installmentCount,
      e.title,
      e.place,
      e.paymentMethod,
      e.reason,
      e.driver,
      e.notes,
      ...e.items.map((i) => i.type.toLowerCase()),
    ].join('\u0000');

    var written = 0;
    for (final (_, e) in ordered) {
      if (!vehicleOf.containsKey(e)) continue;
      final multi = e.installmentCount > 1;
      final key = multi ? groupKey(e) : '';

      String? parentId;
      if (multi && e.installmentNo > 1) {
        final groups = open[key];
        final i = groups?.indexWhere((g) => g.next == e.installmentNo) ?? -1;
        if (i >= 0) {
          final g = groups![i];
          parentId = g.id;
          groups[i] = (id: g.id, next: g.next + 1);
        }
      }

      final duplicate = duplicateOf[e];
      if (duplicate != null) {
        if (multi && e.installmentNo == 1) {
          (open[key] ??= []).add((id: duplicate, next: 2));
        }
        continue;
      }

      final now = DateTime.now();
      final row = await db
          .into(db.entries)
          .insertReturning(
            EntriesCompanion.insert(
              vehicleId: vehicleOf[e]!,
              kind: e.kind,
              date: e.date,
              totalCost: e.totalCost,
              odometer: Value(e.odometer),
              title: Value(e.title),
              placeId: Value(
                await _optionalCatalogId(db, CatalogKind.place, e.place),
              ),
              paymentMethodId: Value(
                await _optionalCatalogId(
                  db,
                  CatalogKind.paymentMethod,
                  e.paymentMethod,
                ),
              ),
              reasonId: Value(
                await _optionalCatalogId(db, CatalogKind.reason, e.reason),
              ),
              driver: Value(e.driver),
              discount: Value(e.discount),
              parentId: Value(parentId),
              installmentNo: Value(e.installmentNo),
              installmentCount: Value(e.installmentCount),
              notes: Value(e.notes),
            ),
          );
      for (final (i, item) in e.items.indexed) {
        await db
            .into(db.entryItems)
            .insert(
              EntryItemsCompanion.insert(
                entryId: row.id,
                typeId: await _catalogId(db, _typeKind(e.kind), item.type),
                amount: item.amount,
                createdAt: Value(now.add(Duration(microseconds: i))),
              ),
            );
      }
      if (multi && e.installmentNo == 1) {
        (open[key] ??= []).add((id: row.id, next: 2));
      }
      written++;
    }
    return written;
  }
}

String _entryLabel(EntryKind kind) => switch (kind) {
  EntryKind.expense => 'Expense',
  EntryKind.service => 'Service',
  EntryKind.income => 'Income',
};
