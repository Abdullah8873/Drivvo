import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/reload_on_change.dart';
import '../../core/theme/record_module.dart';
import '../../core/calc/checklist_math.dart';
import '../attachments/attachment_queries.dart';
import '../checklists/checklist_queries.dart';
import '../entries/entry_queries.dart';

/// One fuel inside a refueling, with its catalog name resolved.
class FuelLine {
  const FuelLine({
    required this.name,
    required this.kind,
    required this.pricePerUnit,
    required this.total,
    required this.volume,
    required this.tank,
  });

  final String name;
  final FuelKind kind;
  final double pricePerUnit;
  final double total;
  final double volume;
  final int tank;
}

/// One typed line of an expense/service/income ("Oil Change — 1200").
class ItemLine {
  const ItemLine({required this.name, required this.amount, this.partNumber});

  final String name;
  final double amount;

  /// Service items only: the replaced part's number or brand.
  final String? partNumber;
}

/// A record of any module flattened into one shape for the timeline — like a
/// "view model" / DTO a REST API would return for a feed. The raw drift row
/// is kept too ([refueling], [entry], [route], [reading]) for module-specific
/// fields.
class TimelineRecord {
  const TimelineRecord({
    required this.module,
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.amount,
    this.odometer,
    this.fuels = const [],
    this.items = const [],
    this.place,
    this.paymentMethod,
    this.reason,
    this.refueling,
    this.entry,
    this.route,
    this.reading,
    this.checklist,
    this.answers = const [],
    this.hasAttachments = false,
  });

  final RecordModule module;
  final String id;
  final String vehicleId;
  final DateTime date;

  /// Money value: cost for refuel/expense/service, value for income/route,
  /// 0 for readings.
  final double amount;

  /// Odometer at the record (routes: final odometer, else initial).
  final double? odometer;
  final List<FuelLine> fuels;
  final List<ItemLine> items;

  /// Gas station (refuels) or place (entries).
  final String? place;
  final String? paymentMethod;
  final String? reason;

  final Refueling? refueling;
  final Entry? entry;
  final Route? route;
  final Reading? reading;

  /// Checklist runs: the record and its live answers, in order. Never a
  /// cost ([amount] is 0; see [isCost]).
  final Checklist? checklist;
  final List<ChecklistAnswer> answers;

  /// Whether the record has at least one live attachment (paperclip icon).
  final bool hasAttachments;

  String? get notes =>
      refueling?.notes ??
      entry?.notes ??
      route?.notes ??
      reading?.notes ??
      checklist?.notes;
  String? get driver =>
      refueling?.driver ??
      entry?.driver ??
      route?.driver ??
      reading?.driver ??
      checklist?.driver;

  /// OK / problem / N/A counts of a checklist run.
  ChecklistCounts get checklistCounts =>
      ChecklistCounts.of(answers.map((a) => a.status));

  /// Money going out (counts toward "total spent").
  bool get isCost =>
      module == RecordModule.refueling ||
      module == RecordModule.expense ||
      module == RecordModule.service;

  /// Money coming in (shown in green).
  bool get isIncome =>
      module == RecordModule.income || module == RecordModule.route;

  double get totalVolume => fuels.fold(0.0, (s, f) => s + f.volume);

  /// Row title, e.g. "Petrol + AdBlue", "Oil Change +2", "Route: A → B".
  String get title {
    switch (module) {
      case RecordModule.refueling:
        return fuels.isEmpty
            ? module.label
            : fuels.map((f) => f.name).join(' + ');
      case RecordModule.expense || RecordModule.service || RecordModule.income:
        if (items.isEmpty) {
          final custom = entry?.title?.trim();
          return custom == null || custom.isEmpty ? module.label : custom;
        }
        final more = items.length > 1 ? ' +${items.length - 1}' : '';
        return '${items.first.name}$more';
      case RecordModule.route:
        final from = route?.origin?.trim();
        final to = route?.destination?.trim();
        return 'Route: ${from == null || from.isEmpty ? '?' : from} → '
            '${to == null || to.isEmpty ? '?' : to}';
      case RecordModule.reading:
        return 'Reading';
      case RecordModule.checklist:
        return checklist?.title ?? module.label;
      case RecordModule.reminder:
        return module.label;
    }
  }
}

/// History's read model. Lives here (not in app_database.dart) so features
/// don't collide — see the note on [AppDatabase].
extension HistoryQueries on AppDatabase {
  /// Every non-deleted record of [vehicleId], newest first. Re-emits whenever
  /// any record/catalog table changes (drift re-runs the dummy "trigger"
  /// query on writes to its `readsFrom` tables, then we reload everything —
  /// at most one reload per burst of writes, see [reloadOnChange]).
  Stream<List<TimelineRecord>> watchTimeline(String vehicleId) {
    return reloadOnChange(
      customSelect(
        'SELECT 1',
        readsFrom: {
          refuelings,
          refuelingFuels,
          entries,
          entryItems,
          routes,
          readings,
          catalogItems,
          checklists,
          checklistAnswers,
          attachments,
        },
      ).watch(),
      () => loadTimeline(vehicleId),
    );
  }

  /// One-shot version of [watchTimeline].
  Future<List<TimelineRecord>> loadTimeline(String vehicleId) async {
    // Catalogs are small: load them once into an id → item map ("join" in Dart).
    final catalog = {for (final c in await select(catalogItems).get()) c.id: c};
    String? nameOf(String? id) => id == null ? null : catalog[id]?.name;

    // Child rows are filtered by a subquery on the parent (not a Dart list
    // of thousands of bound ids), grouped by parent id in one pass (not a
    // scan of every child per parent), and — for fuel lines and entry
    // items, the most numerous rows — read as plain columns: a typed drift
    // row parses its text timestamps, which was most of the load time on a
    // long history. `ORDER BY rowid` keeps the order they always had.
    final vehicleVar = [Variable.withString(vehicleId)];
    final refuelRows =
        await (select(refuelings)..where(
              (r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull(),
            ))
            .get();
    final fuelsOf = _groupBy(
      await customSelect(
        'SELECT refueling_id, fuel_id, price_per_unit, total, volume, tank '
        'FROM refueling_fuels WHERE deleted_at IS NULL AND refueling_id IN '
        '(SELECT id FROM refuelings WHERE vehicle_id = ?1 '
        'AND deleted_at IS NULL) ORDER BY rowid',
        variables: vehicleVar,
        readsFrom: {refuelings, refuelingFuels},
      ).get(),
      (f) => f.read<String>('refueling_id'),
    );

    final entryRows =
        await (select(entries)..where(
              (e) => e.vehicleId.equals(vehicleId) & e.deletedAt.isNull(),
            ))
            .get();
    final itemsOf = _groupBy(
      await customSelect(
        'SELECT entry_id, type_id, amount, part_number FROM entry_items '
        'WHERE deleted_at IS NULL AND entry_id IN '
        '(SELECT id FROM entries WHERE vehicle_id = ?1 '
        'AND deleted_at IS NULL) ORDER BY rowid',
        variables: vehicleVar,
        readsFrom: {entries, entryItems},
      ).get(),
      (i) => i.read<String>('entry_id'),
    );

    final routeRows =
        await (select(routes)..where(
              (r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull(),
            ))
            .get();
    final readingRows =
        await (select(readings)..where(
              (r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull(),
            ))
            .get();
    final checklistRows =
        await (select(checklists)..where(
              (c) => c.vehicleId.equals(vehicleId) & c.deletedAt.isNull(),
            ))
            .get();
    final answersOf = _groupBy(
      await (select(checklistAnswers)
            ..where(
              (a) =>
                  a.checklistId.isInQuery(
                    selectOnly(checklists)
                      ..addColumns([checklists.id])
                      ..where(
                        checklists.vehicleId.equals(vehicleId) &
                            checklists.deletedAt.isNull(),
                      ),
                  ) &
                  a.deletedAt.isNull(),
            )
            ..orderBy([(a) => OrderingTerm.asc(a.position)]))
          .get(),
      (a) => a.checklistId,
    );
    final withFiles = await parentsWithAttachments();
    bool files(String table, String id) => withFiles.contains('$table|$id');

    final records = <TimelineRecord>[
      for (final r in refuelRows)
        TimelineRecord(
          module: RecordModule.refueling,
          id: r.id,
          vehicleId: r.vehicleId,
          date: r.date,
          amount: r.totalCost,
          odometer: r.odometer,
          fuels: [
            for (final f in fuelsOf[r.id] ?? const <QueryRow>[])
              FuelLine(
                name: nameOf(f.read<String>('fuel_id')) ?? 'Fuel',
                kind:
                    catalog[f.read<String>('fuel_id')]?.fuelKind ??
                    FuelKind.liquid,
                pricePerUnit: f.read<double>('price_per_unit'),
                total: f.read<double>('total'),
                volume: f.read<double>('volume'),
                tank: f.read<int>('tank'),
              ),
          ],
          place: nameOf(r.gasStationId),
          paymentMethod: nameOf(r.paymentMethodId),
          reason: nameOf(r.reasonId),
          refueling: r,
          hasAttachments: files('refuelings', r.id),
        ),
      for (final e in entryRows)
        TimelineRecord(
          module: switch (e.kind) {
            EntryKind.expense => RecordModule.expense,
            EntryKind.service => RecordModule.service,
            EntryKind.income => RecordModule.income,
          },
          id: e.id,
          vehicleId: e.vehicleId,
          date: e.date,
          amount: e.totalCost,
          odometer: e.odometer,
          items: [
            for (final i in itemsOf[e.id] ?? const <QueryRow>[])
              ItemLine(
                name: nameOf(i.read<String>('type_id')) ?? 'Item',
                amount: i.read<double>('amount'),
                partNumber: i.readNullable<String>('part_number'),
              ),
          ],
          place: nameOf(e.placeId),
          paymentMethod: nameOf(e.paymentMethodId),
          reason: nameOf(e.reasonId),
          entry: e,
          // Attachments live on the installment group's parent.
          hasAttachments: files('entries', e.parentId ?? e.id),
        ),
      for (final r in routeRows)
        TimelineRecord(
          module: RecordModule.route,
          id: r.id,
          vehicleId: r.vehicleId,
          date: r.startDate,
          amount: r.mode == RouteMode.freight
              ? (r.freightValue ?? 0)
              : (r.total ?? 0),
          odometer: r.endOdometer ?? r.startOdometer,
          reason: nameOf(r.reasonId),
          route: r,
          hasAttachments: files('routes', r.id),
        ),
      for (final r in readingRows)
        TimelineRecord(
          module: RecordModule.reading,
          id: r.id,
          vehicleId: r.vehicleId,
          date: r.date,
          amount: 0,
          odometer: r.odometer,
          reading: r,
          hasAttachments: files('readings', r.id),
        ),
      for (final c in checklistRows)
        TimelineRecord(
          module: RecordModule.checklist,
          id: c.id,
          vehicleId: c.vehicleId,
          date: c.date,
          amount: 0,
          odometer: c.odometer,
          checklist: c,
          answers: answersOf[c.id] ?? const [],
          hasAttachments: files('checklists', c.id),
        ),
    ];

    // Newest first; same timestamp → higher odometer first.
    records.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.odometer ?? 0).compareTo(a.odometer ?? 0);
    });
    return records;
  }

  /// [rows] bucketed by [key], keeping their order inside each bucket.
  static Map<String, List<T>> _groupBy<T>(
    Iterable<T> rows,
    String Function(T row) key,
  ) {
    final out = <String, List<T>>{};
    for (final r in rows) {
      (out[key(r)] ??= []).add(r);
    }
    return out;
  }

  /// The vehicle a record belongs to (null if it doesn't exist).
  Future<String?> recordVehicleId(RecordModule module, String id) async {
    switch (module) {
      case RecordModule.refueling:
        return (await (select(
          refuelings,
        )..where((r) => r.id.equals(id))).getSingleOrNull())?.vehicleId;
      case RecordModule.expense || RecordModule.service || RecordModule.income:
        return (await (select(
          entries,
        )..where((r) => r.id.equals(id))).getSingleOrNull())?.vehicleId;
      case RecordModule.route:
        return (await (select(
          routes,
        )..where((r) => r.id.equals(id))).getSingleOrNull())?.vehicleId;
      case RecordModule.reading:
        return (await (select(
          readings,
        )..where((r) => r.id.equals(id))).getSingleOrNull())?.vehicleId;
      case RecordModule.checklist:
        return (await (select(
          checklists,
        )..where((r) => r.id.equals(id))).getSingleOrNull())?.vehicleId;
      case RecordModule.reminder:
        return null;
    }
  }

  /// Soft-deletes a record and its child rows (fuel lines / entry items) in
  /// one transaction. Soft = set `deletedAt`, so the future sync can
  /// propagate the delete. Expenses, services and incomes go through the
  /// entries feature's `deleteEntry`, which removes the whole installment
  /// group (deleting one installment alone would leave the rest orphaned).
  Future<void> softDeleteRecord(RecordModule module, String id) {
    if (module
        case RecordModule.expense ||
            RecordModule.service ||
            RecordModule.income) {
      return deleteEntry(id);
    }
    if (module == RecordModule.checklist) return deleteChecklist(id);
    final now = Value(DateTime.now());
    return transaction(() async {
      switch (module) {
        case RecordModule.refueling:
          // Lines already soft-deleted by an earlier edit keep their
          // original `deletedAt` (and aren't re-uploaded by the sync).
          await (update(refuelingFuels)
                ..where((f) => f.refuelingId.equals(id) & f.deletedAt.isNull()))
              .write(RefuelingFuelsCompanion(deletedAt: now, updatedAt: now));
          await (update(refuelings)..where((r) => r.id.equals(id))).write(
            RefuelingsCompanion(deletedAt: now, updatedAt: now),
          );
        case RecordModule.route:
          await (update(routes)..where((r) => r.id.equals(id))).write(
            RoutesCompanion(deletedAt: now, updatedAt: now),
          );
        case RecordModule.reading:
          await (update(readings)..where((r) => r.id.equals(id))).write(
            ReadingsCompanion(deletedAt: now, updatedAt: now),
          );
        case RecordModule.expense ||
            RecordModule.service ||
            RecordModule.income ||
            RecordModule.checklist ||
            RecordModule.reminder:
          break; // entries handled above; the rest aren't on the timeline
      }
    });
  }
}
