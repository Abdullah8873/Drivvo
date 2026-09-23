import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// Writes for the user-editable pick lists (fuels, types, stations, places…).
/// Reads go through `catalogProvider(kind)` / `watchCatalog(kind)`.
///
/// Deletes are *soft* (`deletedAt` is set) so old records that point to an
/// item keep their label and the future cloud sync can propagate the delete.
extension CatalogQueries on AppDatabase {
  /// True when another live (non-deleted) item of [kind] already uses [name],
  /// ignoring case and surrounding spaces. [exceptId] skips the item being
  /// edited so saving it unchanged isn't flagged as a duplicate.
  Future<bool> catalogNameExists(
    CatalogKind kind,
    String name, {
    String? exceptId,
  }) async {
    final wanted = name.trim().toLowerCase();
    final rows = await (select(
      catalogItems,
    )..where((c) => c.kind.equalsValue(kind) & c.deletedAt.isNull())).get();
    // Compared in Dart (not SQL `lower()`) so non-ASCII names match too.
    return rows.any(
      (r) => r.id != exceptId && r.name.trim().toLowerCase() == wanted,
    );
  }

  Future<CatalogItem> addCatalogItem({
    required CatalogKind kind,
    required String name,
    FuelKind? fuelKind,
    String? address,
  }) {
    return into(catalogItems).insertReturning(
      CatalogItemsCompanion.insert(
        kind: kind,
        name: name.trim(),
        fuelKind: Value(fuelKind),
        address: Value(address),
      ),
    );
  }

  /// Renames / edits an item. Pass `Value(x)` for the optional columns you
  /// want to change; the default `Value.absent()` leaves them untouched
  /// (like omitting a key in a PATCH body).
  Future<void> updateCatalogItem(
    String id, {
    required String name,
    Value<FuelKind?> fuelKind = const Value.absent(),
    Value<String?> address = const Value.absent(),
  }) {
    return (update(catalogItems)..where((c) => c.id.equals(id))).write(
      CatalogItemsCompanion(
        name: Value(name.trim()),
        fuelKind: fuelKind,
        address: address,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteCatalogItem(String id) {
    final now = DateTime.now();
    return (update(catalogItems)..where((c) => c.id.equals(id))).write(
      CatalogItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Number of non-deleted refueling-fuel lines that use fuel [fuelId].
  /// Changing a fuel's tank kind after it has been used would corrupt the
  /// volume/price math on those existing refuelings, so the form locks the
  /// "Type of fuel" picker once this is non-zero.
  Future<int> countRefuelingsUsingFuel(String fuelId) async {
    final count = refuelingFuels.id.count();
    final query = selectOnly(refuelingFuels)
      ..addColumns([count])
      ..where(
        refuelingFuels.fuelId.equals(fuelId) &
            refuelingFuels.deletedAt.isNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }
}
