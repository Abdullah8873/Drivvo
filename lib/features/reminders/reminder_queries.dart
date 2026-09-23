import 'package:drift/drift.dart';

import '../../core/calc/reminder_math.dart';
import '../../core/db/app_database.dart';

/// Reminder queries, added onto [AppDatabase] with a Dart extension (like
/// adding methods to a class from another file). Soft deletes only: rows get
/// `deletedAt` set and every query filters them out.
extension ReminderQueries on AppDatabase {
  /// Non-deleted reminders of a vehicle, oldest first.
  Stream<List<Reminder>> watchReminders(String vehicleId) {
    return (select(reminders)
          ..where((r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .watch();
  }

  Future<Reminder?> getReminder(String id) {
    return (select(
      reminders,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
  }

  /// Inserts a reminder and returns its id.
  Future<String> insertReminder(RemindersCompanion data) async {
    final row = await into(reminders).insertReturning(data);
    return row.id;
  }

  Future<void> updateReminder(String id, RemindersCompanion data) {
    return (update(reminders)..where((r) => r.id.equals(id))).write(
      data.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> softDeleteReminder(String id) {
    final now = DateTime.now();
    return (update(reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// One-shot read of a catalog (non-deleted, alphabetical). Used by the
  /// type picker instead of `watchCatalog(kind).first`.
  Future<List<CatalogItem>> getCatalog(CatalogKind kind) {
    return (select(catalogItems)
          ..where((c) => c.kind.equalsValue(kind) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name.collate(Collate.noCase))]))
        .get();
  }

  /// Adds a service/expense type to the catalog (the "+" in the type picker).
  Future<CatalogItem> addCatalogItem(CatalogKind kind, String name) {
    return into(catalogItems)
        .insertReturning(CatalogItemsCompanion.insert(kind: kind, name: name));
  }

  /// Every (date, odometer) the vehicle has logged, across all record
  /// tables, oldest first. Feeds the average distance per day.
  Stream<List<OdometerPoint>> watchOdometerHistory(String vehicleId) {
    const sql = '''
      SELECT date AS d, odometer AS o FROM refuelings
        WHERE vehicle_id = ?1 AND deleted_at IS NULL
      UNION ALL SELECT date, odometer FROM entries
        WHERE vehicle_id = ?1 AND deleted_at IS NULL AND odometer IS NOT NULL
      UNION ALL SELECT date, odometer FROM readings
        WHERE vehicle_id = ?1 AND deleted_at IS NULL
      UNION ALL SELECT start_date, start_odometer FROM routes
        WHERE vehicle_id = ?1 AND deleted_at IS NULL
      UNION ALL SELECT end_date, end_odometer FROM routes
        WHERE vehicle_id = ?1 AND deleted_at IS NULL
          AND end_date IS NOT NULL AND end_odometer IS NOT NULL
    ''';
    return customSelect(
      sql,
      variables: [Variable.withString(vehicleId)],
      readsFrom: {refuelings, entries, readings, routes},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          (date: row.read<DateTime>('d'), odometer: row.read<double>('o')),
      ]..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  /// Non-deleted refuelings of a vehicle as (date, odometer), oldest first.
  Stream<List<OdometerPoint>> watchRefuelPoints(String vehicleId) {
    return (select(refuelings)
          ..where((r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.date)]))
        .watch()
        .map(
          (rows) => [
            for (final r in rows) (date: r.date, odometer: r.odometer),
          ],
        );
  }

  /// For every service/expense type the vehicle has logged: the most recent
  /// time it was done. Map key = catalog type id. This is what makes
  /// repeating reminders reschedule themselves.
  Stream<Map<String, Baseline>> watchLastLoggedByType(String vehicleId) {
    const sql = '''
      SELECT i.type_id AS t, e.date AS d, e.odometer AS o
      FROM entry_items i JOIN entries e ON e.id = i.entry_id
      WHERE e.vehicle_id = ?1 AND e.deleted_at IS NULL AND i.deleted_at IS NULL
    ''';
    return customSelect(
      sql,
      variables: [Variable.withString(vehicleId)],
      readsFrom: {entries, entryItems},
    ).watch().map((rows) {
      final latest = <String, Baseline>{};
      for (final row in rows) {
        final type = row.read<String>('t');
        final date = row.read<DateTime>('d');
        final prev = latest[type];
        if (prev == null || date.isAfter(prev.date)) {
          latest[type] = (date: date, odometer: row.readNullable<double>('o'));
        }
      }
      return latest;
    });
  }
}
