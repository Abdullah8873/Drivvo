import 'package:drift/drift.dart';

import '../../core/calc/consumption.dart';
import '../../core/db/app_database.dart';

/// One fuel line of a refueling, with its catalog fuel (null if the fuel
/// was deleted from the catalog).
class RefuelingFuelLine {
  const RefuelingFuelLine(this.line, this.fuel);

  final RefuelingFuel line;
  final CatalogItem? fuel;

  String get fuelName => fuel?.name ?? '—';
  FuelKind get fuelKind => fuel?.fuelKind ?? FuelKind.liquid;
}

/// A refueling with everything a list row or detail screen shows: its fuel
/// lines and the names behind its catalog ids (like a Prisma `include`).
class RefuelingDetails {
  const RefuelingDetails({
    required this.refueling,
    required this.lines,
    this.gasStation,
    this.paymentMethod,
    this.reason,
  });

  final Refueling refueling;
  final List<RefuelingFuelLine> lines;
  final CatalogItem? gasStation;
  final CatalogItem? paymentMethod;
  final CatalogItem? reason;

  String get id => refueling.id;

  /// "Petrol" or "Petrol + CNG".
  String get title => lines.map((l) => l.fuelName).join(' + ');

  /// Total volume of every line.
  double get volume => lines.fold(0, (s, l) => s + l.line.volume);

  /// Sum of the line totals before the discount.
  double get linesTotal => lines.fold(0, (s, l) => s + l.line.total);

  Iterable<RefuelingFuelLine> _linesFor(int tank) =>
      lines.where((l) => l.line.tank == tank);

  double volumeForTank(int tank) =>
      _linesFor(tank).fold(0, (s, l) => s + l.line.volume);

  /// Cost of the fuel that went into [tank], with the discount split
  /// proportionally between tanks.
  double costForTank(int tank) {
    final lineCost = _linesFor(tank).fold(0.0, (s, l) => s + l.line.total);
    if (linesTotal <= 0) return 0;
    return lineCost * refueling.totalCost / linesTotal;
  }

  /// Input for the consumption engine, or null when nothing went into [tank].
  RefuelSample? toSample({int tank = 1}) {
    if (!_linesFor(tank).any((_) => true)) return null;
    return RefuelSample(
      id: refueling.id,
      date: refueling.date,
      odometer: refueling.odometer,
      volume: volumeForTank(tank),
      cost: costForTank(tank),
      fullTank: refueling.fullTank,
      missedPrevious: refueling.missedPrevious,
    );
  }
}

/// A fuel line as entered in the form.
class FuelLineDraft {
  const FuelLineDraft({
    required this.fuelId,
    required this.pricePerUnit,
    required this.total,
    required this.volume,
    this.tank = 1,
  });

  final String fuelId;
  final double pricePerUnit;
  final double total;
  final double volume;
  final int tank;
}

/// Everything the refueling form saves (like a create/update DTO).
class RefuelingDraft {
  const RefuelingDraft({
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.lines,
    this.fullTank = true,
    this.missedPrevious = false,
    this.gasStationId,
    this.paymentMethodId,
    this.reasonId,
    this.driver,
    this.discount,
    this.notes,
  });

  final String vehicleId;
  final DateTime date;
  final double odometer;
  final List<FuelLineDraft> lines;
  final bool fullTank;
  final bool missedPrevious;
  final String? gasStationId;
  final String? paymentMethodId;
  final String? reasonId;
  final String? driver;
  final double? discount;
  final String? notes;

  /// Sum of the line totals minus the discount.
  double get totalCost =>
      lines.fold(0.0, (s, l) => s + l.total) - (discount ?? 0);
}

/// Refueling reads and writes. Soft deletes only: rows get `deletedAt`
/// instead of being removed, so the future cloud sync can propagate them.
extension RefuelingQueries on AppDatabase {
  /// A vehicle's refuelings with lines and names, newest first.
  Stream<List<RefuelingDetails>> watchRefuelings(String vehicleId) =>
      _detailsQuery(refuelings.vehicleId.equals(vehicleId))
          .watch()
          .map(_groupRows);

  /// The consumption engine's input for every tank of a vehicle, live:
  /// tank (1 or 2) → one [RefuelSample] per refueling that put fuel in it.
  ///
  /// Same values as `watchRefuelings(...).map((d) => d.toSample(tank: n))`
  /// (same order, lines summed in the same order), but from one light query:
  /// no catalog joins and only the columns the engine reads — on a long
  /// history that is several times cheaper, and it re-runs on every
  /// refueling change.
  Stream<Map<int, List<RefuelSample>>> watchRefuelSamples(String vehicleId) {
    return customSelect(
      '''
      SELECT r.id, r.date, r.odometer, r.full_tank, r.missed_previous,
        r.total_cost, f.tank, f.volume, f.total
      FROM refuelings r
      JOIN refueling_fuels f ON f.refueling_id = r.id AND f.deleted_at IS NULL
      WHERE r.vehicle_id = ?1 AND r.deleted_at IS NULL
      ORDER BY r.date DESC, r.odometer DESC, r.id ASC, f.created_at ASC
      ''',
      variables: [Variable.withString(vehicleId)],
      readsFrom: {refuelings, refuelingFuels},
    ).watch().map(_samplesByTank);
  }

  static Map<int, List<RefuelSample>> _samplesByTank(List<QueryRow> rows) {
    final out = <int, List<RefuelSample>>{};
    var i = 0;
    while (i < rows.length) {
      final first = rows[i];
      final id = first.read<String>('id');
      // This refueling's lines are consecutive (ORDER BY … r.id).
      final lines = <({int tank, double volume, double total})>[];
      for (; i < rows.length && rows[i].read<String>('id') == id; i++) {
        lines.add((
          tank: rows[i].read<int>('tank'),
          volume: rows[i].read<double>('volume'),
          total: rows[i].read<double>('total'),
        ));
      }
      final linesTotal = lines.fold(0.0, (s, l) => s + l.total);
      final totalCost = first.read<double>('total_cost');
      for (final tank in {for (final l in lines) l.tank}) {
        final mine = lines.where((l) => l.tank == tank);
        final lineCost = mine.fold(0.0, (s, l) => s + l.total);
        (out[tank] ??= []).add(
          RefuelSample(
            id: id,
            date: first.read<DateTime>('date'),
            odometer: first.read<double>('odometer'),
            volume: mine.fold(0.0, (s, l) => s + l.volume),
            cost: linesTotal <= 0 ? 0 : lineCost * totalCost / linesTotal,
            fullTank: first.read<bool>('full_tank'),
            missedPrevious: first.read<bool>('missed_previous'),
          ),
        );
      }
    }
    return out;
  }

  /// One refueling (null when missing or deleted), live.
  Stream<RefuelingDetails?> watchRefueling(String id) =>
      _detailsQuery(refuelings.id.equals(id))
          .watch()
          .map((rows) => _groupRows(rows).firstOrNull);

  Future<RefuelingDetails?> getRefueling(String id) async =>
      _groupRows(await _detailsQuery(refuelings.id.equals(id)).get())
          .firstOrNull;

  /// Inserts ([id] == null) or updates a refueling and its fuel lines in one
  /// transaction. On update the old lines are soft-deleted and replaced.
  /// Returns the refueling id.
  Future<String> saveRefueling(RefuelingDraft draft, {String? id}) {
    return transaction(() async {
      final now = DateTime.now();
      final row = RefuelingsCompanion(
        vehicleId: Value(draft.vehicleId),
        date: Value(draft.date),
        odometer: Value(draft.odometer),
        fullTank: Value(draft.fullTank),
        missedPrevious: Value(draft.missedPrevious),
        gasStationId: Value(draft.gasStationId),
        paymentMethodId: Value(draft.paymentMethodId),
        reasonId: Value(draft.reasonId),
        driver: Value(draft.driver),
        discount: Value(draft.discount),
        totalCost: Value(draft.totalCost),
        notes: Value(draft.notes),
        updatedAt: Value(now),
      );

      final String refuelingId;
      if (id == null) {
        refuelingId = (await into(refuelings).insertReturning(row)).id;
      } else {
        refuelingId = id;
        await (update(refuelings)..where((r) => r.id.equals(id))).write(row);
        await _softDeleteLines(id, now);
      }

      await batch((b) {
        b.insertAll(refuelingFuels, [
          for (final (i, l) in draft.lines.indexed)
            RefuelingFuelsCompanion.insert(
              refuelingId: refuelingId,
              fuelId: l.fuelId,
              pricePerUnit: l.pricePerUnit,
              total: l.total,
              volume: l.volume,
              tank: Value(l.tank),
              // Staggered timestamps keep the lines in the order entered.
              createdAt: Value(now.add(Duration(microseconds: i))),
              updatedAt: Value(now),
            ),
        ]);
      });
      return refuelingId;
    });
  }

  /// Soft-deletes a refueling and its fuel lines.
  Future<void> deleteRefueling(String id) {
    return transaction(() async {
      final now = DateTime.now();
      await (update(refuelings)..where((r) => r.id.equals(id))).write(
        RefuelingsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _softDeleteLines(id, now);
    });
  }

  /// Fuel of the vehicle's most recent refueling (the form's default).
  Future<String?> lastFuelIdFor(String vehicleId) async {
    final q =
        select(refuelingFuels).join([
            innerJoin(
              refuelings,
              refuelings.id.equalsExp(refuelingFuels.refuelingId),
            ),
          ])
          ..where(
            refuelings.vehicleId.equals(vehicleId) &
                refuelings.deletedAt.isNull() &
                refuelingFuels.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(refuelings.date),
            OrderingTerm.asc(refuelingFuels.createdAt),
          ])
          ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.readTable(refuelingFuels).fuelId;
  }

  /// The refueling right before [date] for a vehicle (by date), ignoring
  /// [excludeId] — used to warn about an odometer going backwards.
  Future<Refueling?> previousRefueling(
    String vehicleId,
    DateTime date, {
    String? excludeId,
  }) {
    final q = select(refuelings)
      ..where(
        (r) =>
            r.vehicleId.equals(vehicleId) &
            r.deletedAt.isNull() &
            r.date.isSmallerThanValue(date) &
            (excludeId == null
                ? const Constant(true)
                : r.id.equals(excludeId).not()),
      )
      ..orderBy([
        (r) => OrderingTerm.desc(r.date),
        (r) => OrderingTerm.desc(r.odometer),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  Future<void> _softDeleteLines(String refuelingId, DateTime now) {
    return (update(refuelingFuels)..where(
          (l) => l.refuelingId.equals(refuelingId) & l.deletedAt.isNull(),
        ))
        .write(
          RefuelingFuelsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
  }

  // Aliases compare by name, so the query and the row reader can each
  // create their own copies.
  ({
    $CatalogItemsTable fuel,
    $CatalogItemsTable station,
    $CatalogItemsTable payment,
    $CatalogItemsTable reason,
  })
  _aliases() => (
    fuel: alias(catalogItems, 'fuel'),
    station: alias(catalogItems, 'station'),
    payment: alias(catalogItems, 'payment'),
    reason: alias(catalogItems, 'reason'),
  );

  // Refuelings LEFT JOIN their live lines and the catalog names. Aliases are
  // needed because catalog_items is joined four times (fuel, station, …).
  JoinedSelectStatement<HasResultSet, dynamic> _detailsQuery(
    Expression<bool> where,
  ) {
    final (:fuel, :station, :payment, :reason) = _aliases();
    return select(refuelings).join([
        leftOuterJoin(
          refuelingFuels,
          refuelingFuels.refuelingId.equalsExp(refuelings.id) &
              refuelingFuels.deletedAt.isNull(),
        ),
        leftOuterJoin(fuel, fuel.id.equalsExp(refuelingFuels.fuelId)),
        leftOuterJoin(station, station.id.equalsExp(refuelings.gasStationId)),
        leftOuterJoin(
          payment,
          payment.id.equalsExp(refuelings.paymentMethodId),
        ),
        leftOuterJoin(reason, reason.id.equalsExp(refuelings.reasonId)),
      ])
      ..where(where & refuelings.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(refuelings.date),
        OrderingTerm.desc(refuelings.odometer),
        OrderingTerm.asc(refuelings.id),
        OrderingTerm.asc(refuelingFuels.createdAt),
      ]);
  }

  /// Folds the flat join rows (one per fuel line) back into one object per
  /// refueling, keeping the query order.
  List<RefuelingDetails> _groupRows(List<TypedResult> rows) {
    final (:fuel, :station, :payment, :reason) = _aliases();

    final byId = <String, RefuelingDetails>{}; // keeps insertion order
    for (final row in rows) {
      final r = row.readTable(refuelings);
      final details = byId.putIfAbsent(
        r.id,
        () => RefuelingDetails(
          refueling: r,
          lines: [],
          gasStation: row.readTableOrNull(station),
          paymentMethod: row.readTableOrNull(payment),
          reason: row.readTableOrNull(reason),
        ),
      );
      final line = row.readTableOrNull(refuelingFuels);
      if (line != null) {
        details.lines.add(RefuelingFuelLine(line, row.readTableOrNull(fuel)));
      }
    }
    return byId.values.toList();
  }
}
