import 'package:drift/drift.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/features/catalog/catalog_queries.dart';

/// Test data builders for the History tests (records are inserted directly
/// with drift companions, since the forms belong to other features).

Future<String> catalogId(AppDatabase db, CatalogKind kind, String name) async {
  final row = await (db.select(
    db.catalogItems,
  )..where((c) => c.kind.equalsValue(kind) & c.name.equals(name))).getSingle();
  return row.id;
}

/// One fuel line for [addRefuel]'s `lines`.
typedef TestFuelLine = ({String fuel, double volume, int tank});

/// A refueling — by default a single [fuel] line of [volume] in tank 1;
/// pass [lines] instead for several fuels / tanks (then [volume] is
/// ignored). Every line costs [price] per unit. Returns its id.
Future<String> addRefuel(
  AppDatabase db,
  String vehicleId, {
  required DateTime date,
  required double odometer,
  double volume = 0,
  String fuel = 'Petrol',
  int tank = 1,
  List<TestFuelLine>? lines,
  double price = 293.03,
  bool fullTank = true,
  bool missedPrevious = false,
  String? notes,

  /// Gas station name — created in the catalog on first use (gas stations
  /// aren't seeded, unlike fuel/expense types). Needed for the achievement
  /// badges that count distinct/same-station refuels.
  String? station,
}) async {
  final all = lines ?? [(fuel: fuel, volume: volume, tank: tank)];
  final total = all.fold(0.0, (s, l) => s + l.volume * price);
  final gasStationId = station == null
      ? null
      : (await db.addCatalogItem(
          kind: CatalogKind.gasStation,
          name: station,
        )).id;
  final r = await db
      .into(db.refuelings)
      .insertReturning(
        RefuelingsCompanion.insert(
          vehicleId: vehicleId,
          date: date,
          odometer: odometer,
          totalCost: total,
          fullTank: Value(fullTank),
          missedPrevious: Value(missedPrevious),
          notes: Value(notes),
          gasStationId: Value(gasStationId),
        ),
      );
  for (final l in all) {
    await db
        .into(db.refuelingFuels)
        .insert(
          RefuelingFuelsCompanion.insert(
            refuelingId: r.id,
            fuelId: await catalogId(db, CatalogKind.fuel, l.fuel),
            pricePerUnit: price,
            total: l.volume * price,
            volume: l.volume,
            tank: Value(l.tank),
          ),
        );
  }
  return r.id;
}

/// An expense/service/income with typed items. Returns its id.
Future<String> addEntry(
  AppDatabase db,
  String vehicleId, {
  required EntryKind kind,
  required DateTime date,
  required Map<String, double> items,
  double? odometer,
}) async {
  final typeKind = switch (kind) {
    EntryKind.expense => CatalogKind.expenseType,
    EntryKind.service => CatalogKind.serviceType,
    EntryKind.income => CatalogKind.incomeType,
  };
  final e = await db
      .into(db.entries)
      .insertReturning(
        EntriesCompanion.insert(
          vehicleId: vehicleId,
          kind: kind,
          date: date,
          totalCost: items.values.fold(0.0, (s, v) => s + v),
          odometer: Value(odometer),
        ),
      );
  for (final MapEntry(:key, :value) in items.entries) {
    await db
        .into(db.entryItems)
        .insert(
          EntryItemsCompanion.insert(
            entryId: e.id,
            typeId: await catalogId(db, typeKind, key),
            amount: value,
          ),
        );
  }
  return e.id;
}
