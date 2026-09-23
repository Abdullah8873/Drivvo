import 'package:drift/drift.dart';
import 'package:motolog/core/db/app_database.dart';

/// Test data builders for the History tests (records are inserted directly
/// with drift companions, since the forms belong to other features).

Future<String> catalogId(AppDatabase db, CatalogKind kind, String name) async {
  final row = await (db.select(
    db.catalogItems,
  )..where((c) => c.kind.equalsValue(kind) & c.name.equals(name))).getSingle();
  return row.id;
}

/// A single-fuel (Petrol) refueling. Returns its id.
Future<String> addRefuel(
  AppDatabase db,
  String vehicleId, {
  required DateTime date,
  required double odometer,
  required double volume,
  double price = 293.03,
  bool fullTank = true,
  String? notes,
}) async {
  final fuel = await catalogId(db, CatalogKind.fuel, 'Petrol');
  final total = volume * price;
  final r = await db
      .into(db.refuelings)
      .insertReturning(
        RefuelingsCompanion.insert(
          vehicleId: vehicleId,
          date: date,
          odometer: odometer,
          totalCost: total,
          fullTank: Value(fullTank),
          notes: Value(notes),
        ),
      );
  await db
      .into(db.refuelingFuels)
      .insert(
        RefuelingFuelsCompanion.insert(
          refuelingId: r.id,
          fuelId: fuel,
          pricePerUnit: price,
          total: total,
          volume: volume,
        ),
      );
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
