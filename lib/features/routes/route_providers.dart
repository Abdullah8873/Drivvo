import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import 'route_math.dart';
import 'route_queries.dart';

/// Riverpod providers for routes — used by History and Reports.
/// `ref.watch(routesProvider(vehicleId))` ≈ `useQuery(['routes', vehicleId])`.

/// Non-deleted routes of a vehicle, newest first.
final routesProvider = StreamProvider.family<List<Route>, String>(
  (ref, vehicleId) => ref.watch(databaseProvider).watchRoutes(vehicleId),
);

/// One route by id (null when missing or deleted).
final routeProvider = StreamProvider.family<Route?, String>(
  (ref, id) => ref.watch(databaseProvider).watchRoute(id),
);

/// Report filter: a vehicle plus an optional `[from, to)` range on the start
/// date (null = unbounded). A record, so equal filters share one provider.
typedef RoutePeriod = ({String vehicleId, DateTime? from, DateTime? to});

/// Route report numbers (value, distance, time) for a period.
final routeTotalsProvider =
    Provider.family<AsyncValue<RouteTotals>, RoutePeriod>((ref, p) {
      return ref.watch(routesProvider(p.vehicleId)).whenData((list) {
        final inPeriod = list.where(
          (r) =>
              (p.from == null || !r.startDate.isBefore(p.from!)) &&
              (p.to == null || r.startDate.isBefore(p.to!)),
        );
        return RouteMath.totals(inPeriod.map((r) => r.span));
      });
    });
