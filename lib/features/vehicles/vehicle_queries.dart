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
  Future<void> softDeleteVehicle(String id) {
    final now = DateTime.now();
    return (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
