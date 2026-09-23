import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import 'reading_math.dart';

/// Reading (quick odometer update) database queries.
extension ReadingQueries on AppDatabase {
  /// Non-deleted readings of a vehicle, newest first.
  Stream<List<Reading>> watchReadings(String vehicleId) {
    return (select(readings)
          ..where((r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.date)]))
        .watch();
  }

  Stream<Reading?> watchReading(String id) {
    return (select(readings)
          ..where((r) => r.id.equals(id) & r.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<Reading?> getReading(String id) {
    return (select(
      readings,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
  }

  /// Inserts (id == null) or updates a reading, returning its id.
  Future<String> saveReading(ReadingsCompanion data, {String? id}) async {
    if (id == null) {
      final row = await into(readings).insertReturning(data);
      return row.id;
    }
    await (update(readings)..where((r) => r.id.equals(id))).write(
      data.copyWith(updatedAt: Value(DateTime.now())),
    );
    return id;
  }

  /// Soft delete (sets `deletedAt`).
  Future<void> deleteReading(String id) {
    final now = DateTime.now();
    return (update(readings)..where((r) => r.id.equals(id))).write(
      ReadingsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

extension ReadingX on Reading {
  /// The numbers [ReadingMath.stats] needs.
  ReadingPoint get point => (date: date, odometer: odometer);
}
