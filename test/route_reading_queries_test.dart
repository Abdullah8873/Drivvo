import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/providers.dart';
import 'package:motolog/features/readings/reading_providers.dart';
import 'package:motolog/features/readings/reading_queries.dart';
import 'package:motolog/features/routes/route_providers.dart';
import 'package:motolog/features/routes/route_queries.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late String vid;
  setUp(() async {
    db = testDatabase();
    vid = await addTestVehicle(db);
  });
  tearDown(() => db.close());

  RoutesCompanion route(
    DateTime start, {
    double startOdo = 0,
    double? endOdo,
    RouteMode mode = RouteMode.trip,
    double? total,
    double? freightValue,
  }) => RoutesCompanion(
    vehicleId: Value(vid),
    mode: Value(mode),
    startDate: Value(start),
    startOdometer: Value(startOdo),
    endDate: Value(endOdo == null ? null : start.add(const Duration(hours: 1))),
    endOdometer: Value(endOdo),
    total: Value(total),
    freightValue: Value(freightValue),
  );

  test('routes: save, update, open list and soft delete', () async {
    final a = await db.saveRoute(
      route(DateTime(2026, 9, 1), startOdo: 100, endOdo: 150),
    );
    final b = await db.saveRoute(route(DateTime(2026, 9, 2), startOdo: 150));

    expect((await db.watchRoutes(vid).first).map((r) => r.id), [b, a]);
    expect((await db.watchOpenRoutes(vid).first).single.id, b);

    final before = (await db.getRoute(b))!;
    await db.saveRoute(const RoutesCompanion(endOdometer: Value(180)), id: b);
    final after = (await db.getRoute(b))!;
    expect(after.endOdometer, 180);
    expect(after.isOpen, isFalse);
    expect(after.distance, 30);
    expect(after.updatedAt.isBefore(before.updatedAt), isFalse);

    await db.deleteRoute(a);
    expect(await db.getRoute(a), isNull);
    expect((await db.watchRoutes(vid).first).single.id, b);
  });

  test('routeTotalsProvider sums a period', () async {
    await db.saveRoute(
      route(DateTime(2026, 8, 30), startOdo: 0, endOdo: 50, total: 100),
    );
    await db.saveRoute(
      route(DateTime(2026, 9, 3), startOdo: 50, endOdo: 150, total: 200),
    );
    await db.saveRoute(
      route(
        DateTime(2026, 9, 5),
        startOdo: 150,
        mode: RouteMode.freight,
        freightValue: 1000,
      ),
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final period = (
      vehicleId: vid,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
    );
    // Keep the stream alive, then wait for its first value.
    container.listen(routeTotalsProvider(period), (_, _) {});
    await container.read(routesProvider(vid).future);
    final totals = container.read(routeTotalsProvider(period)).requireValue;
    expect(totals.count, 2);
    expect(totals.distance, 100);
    expect(totals.minutes, 60);
    expect(totals.value, 1200);
  });

  test('readings: save, update, soft delete and stats provider', () async {
    final a = await db.saveReading(
      ReadingsCompanion.insert(
        vehicleId: vid,
        date: DateTime(2026, 9, 1),
        odometer: 1000,
      ),
    );
    await db.saveReading(
      ReadingsCompanion.insert(
        vehicleId: vid,
        date: DateTime(2026, 9, 11),
        odometer: 1300,
      ),
    );
    await db.saveReading(const ReadingsCompanion(driver: Value('Ali')), id: a);
    expect((await db.getReading(a))!.driver, 'Ali');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final period = (vehicleId: vid, from: null, to: null);
    container.listen(readingStatsProvider(period), (_, _) {});
    await container.read(readingsProvider(vid).future);
    final stats = container.read(readingStatsProvider(period)).requireValue;
    expect(stats.distance, 300);
    expect(stats.dailyAverage, 30);
    expect(stats.averageDaysBetween, 10);

    await db.deleteReading(a);
    expect(await db.getReading(a), isNull);
    expect(await db.watchReadings(vid).first, hasLength(1));
  });
}
