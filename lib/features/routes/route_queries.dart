import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import 'route_math.dart';

/// Route database queries (like a small repository / Prisma service).
///
/// Note: drift names the row class `Route`, which clashes with Flutter's
/// `Route` from `material.dart`. In widget files import material with
/// `hide Route` (or import this db with a prefix).
extension RouteQueries on AppDatabase {
  /// Non-deleted routes of a vehicle, newest first.
  Stream<List<Route>> watchRoutes(String vehicleId) {
    return (select(routes)
          ..where((r) => r.vehicleId.equals(vehicleId) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.startDate)]))
        .watch();
  }

  /// Routes still waiting for their final odometer ("finish later").
  Stream<List<Route>> watchOpenRoutes(String vehicleId) {
    return (select(routes)
          ..where(
            (r) =>
                r.vehicleId.equals(vehicleId) &
                r.deletedAt.isNull() &
                r.endOdometer.isNull(),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.startDate)]))
        .watch();
  }

  Stream<Route?> watchRoute(String id) {
    return (select(routes)
          ..where((r) => r.id.equals(id) & r.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<Route?> getRoute(String id) {
    return (select(
      routes,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
  }

  /// Inserts a new route (id == null) or updates an existing one, returning
  /// its id. Updates bump `updatedAt` for the future sync.
  Future<String> saveRoute(RoutesCompanion data, {String? id}) async {
    if (id == null) {
      final row = await into(routes).insertReturning(data);
      return row.id;
    }
    await (update(routes)..where((r) => r.id.equals(id))).write(
      data.copyWith(updatedAt: Value(DateTime.now())),
    );
    return id;
  }

  /// Soft delete: the row stays (for sync) but disappears from every query.
  Future<void> deleteRoute(String id) {
    final now = DateTime.now();
    return (update(routes)..where((r) => r.id.equals(id))).write(
      RoutesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

extension RouteX on Route {
  bool get isOpen => endOdometer == null;

  /// Distance driven, null while open.
  double? get distance => RouteMath.distance(startOdometer, endOdometer);

  /// Duration in minutes, null while open.
  int? get durationMinutes => RouteMath.durationMinutes(startDate, endDate);

  /// Money value of the route: trip total or freight value.
  double? get value => switch (mode) {
    RouteMode.trip => total,
    RouteMode.freight => freightValue,
  };

  /// The numbers [RouteMath.totals] needs.
  RouteSpan get span => (
    start: startDate,
    end: endDate,
    startOdometer: startOdometer,
    endOdometer: endOdometer,
    value: value,
  );
}
