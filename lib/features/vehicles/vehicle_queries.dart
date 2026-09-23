import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// Vehicle reads/writes used by the vehicles feature. Lives here (not in
/// `AppDatabase`) so features don't collide — like a per-feature repository.
extension VehicleQueries on AppDatabase {
  /// One non-deleted vehicle, or null.
  Future<Vehicle?> getVehicle(String id) {
    return (select(
      vehicles,
    )..where((v) => v.id.equals(id) & v.deletedAt.isNull())).getSingleOrNull();
  }

  /// Number of non-deleted vehicles.
  Future<int> countVehicles() async {
    final count = vehicles.id.count();
    final query = selectOnly(vehicles)
      ..addColumns([count])
      ..where(vehicles.deletedAt.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Inserts a vehicle and returns its generated id.
  Future<String> insertVehicle(VehiclesCompanion data) async {
    final row = await into(vehicles).insertReturning(data);
    return row.id;
  }

  /// Writes the given columns and bumps `updatedAt` (used by the future sync).
  Future<void> updateVehicle(String id, VehiclesCompanion data) {
    return (update(vehicles)..where((v) => v.id.equals(id))).write(
      data.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Soft delete: the row stays (so sync can propagate the delete) but every
  /// query filters it out via `deletedAt IS NULL`.
  ///
  /// Kept for the count-only case; deleting a vehicle from the UI should go
  /// through [softDeleteVehicleAndRecords] instead, which also removes the
  /// vehicle's records so they don't linger as orphans.
  Future<void> softDeleteVehicle(String id) {
    final now = DateTime.now();
    return (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Non-deleted refuelings + entries + routes + readings + reminders that
  /// belong to vehicle [id] — shown in the delete confirmation ("… and its
  /// 42 records will be deleted") before [softDeleteVehicleAndRecords] runs.
  Future<int> countVehicleRecords(String id) async {
    const sql = '''
      SELECT
        (SELECT COUNT(*) FROM refuelings WHERE vehicle_id = ?1 AND deleted_at IS NULL) +
        (SELECT COUNT(*) FROM entries WHERE vehicle_id = ?1 AND deleted_at IS NULL) +
        (SELECT COUNT(*) FROM routes WHERE vehicle_id = ?1 AND deleted_at IS NULL) +
        (SELECT COUNT(*) FROM readings WHERE vehicle_id = ?1 AND deleted_at IS NULL) +
        (SELECT COUNT(*) FROM reminders WHERE vehicle_id = ?1 AND deleted_at IS NULL)
        AS total
    ''';
    final row = await customSelect(
      sql,
      variables: [Variable.withString(id)],
      readsFrom: {refuelings, entries, routes, readings, reminders},
    ).getSingle();
    return row.read<int>('total');
  }

  /// Soft-deletes vehicle [id] and cascades the soft delete to every record
  /// that points to it (refuelings + their fuel lines, entries + their
  /// items, routes, readings, reminders), all in one transaction so the
  /// vehicle never ends up gone while its records survive (or vice versa).
  Future<void> softDeleteVehicleAndRecords(String id) {
    final now = DateTime.now();
    Value<DateTime> deleted() => Value(now);

    return transaction(() async {
      final refuelingIds =
          await (selectOnly(refuelings)
                ..addColumns([refuelings.id])
                ..where(
                  refuelings.vehicleId.equals(id) &
                      refuelings.deletedAt.isNull(),
                ))
              .map((row) => row.read(refuelings.id)!)
              .get();
      final entryIds =
          await (selectOnly(entries)
                ..addColumns([entries.id])
                ..where(
                  entries.vehicleId.equals(id) & entries.deletedAt.isNull(),
                ))
              .map((row) => row.read(entries.id)!)
              .get();

      if (refuelingIds.isNotEmpty) {
        await (update(refuelingFuels)..where(
              (r) => r.refuelingId.isIn(refuelingIds) & r.deletedAt.isNull(),
            ))
            .write(
              RefuelingFuelsCompanion(
                deletedAt: deleted(),
                updatedAt: Value(now),
              ),
            );
      }
      if (entryIds.isNotEmpty) {
        await (update(
          entryItems,
        )..where((e) => e.entryId.isIn(entryIds) & e.deletedAt.isNull())).write(
          EntryItemsCompanion(deletedAt: deleted(), updatedAt: Value(now)),
        );
      }

      await (update(
        refuelings,
      )..where((r) => r.vehicleId.equals(id) & r.deletedAt.isNull())).write(
        RefuelingsCompanion(deletedAt: deleted(), updatedAt: Value(now)),
      );
      await (update(entries)
            ..where((e) => e.vehicleId.equals(id) & e.deletedAt.isNull()))
          .write(EntriesCompanion(deletedAt: deleted(), updatedAt: Value(now)));
      await (update(routes)
            ..where((r) => r.vehicleId.equals(id) & r.deletedAt.isNull()))
          .write(RoutesCompanion(deletedAt: deleted(), updatedAt: Value(now)));
      await (update(
        readings,
      )..where((r) => r.vehicleId.equals(id) & r.deletedAt.isNull())).write(
        ReadingsCompanion(deletedAt: deleted(), updatedAt: Value(now)),
      );
      await (update(
        reminders,
      )..where((r) => r.vehicleId.equals(id) & r.deletedAt.isNull())).write(
        RemindersCompanion(deletedAt: deleted(), updatedAt: Value(now)),
      );

      await (update(vehicles)..where((v) => v.id.equals(id))).write(
        VehiclesCompanion(deletedAt: deleted(), updatedAt: Value(now)),
      );
    });
  }
}
