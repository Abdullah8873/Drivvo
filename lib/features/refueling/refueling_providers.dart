import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/consumption.dart';
import '../../core/providers.dart';
import 'refueling_queries.dart';

export '../../core/calc/consumption.dart';
export 'refueling_queries.dart';

/// Riverpod providers for refuelings — the "React Query hooks" other
/// features (History, Reports, detail view) read with `ref.watch(...)`.

/// A vehicle's refuelings with fuel lines and names, newest first (live).
final refuelingsProvider =
    StreamProvider.family<List<RefuelingDetails>, String>(
      (ref, vehicleId) =>
          ref.watch(databaseProvider).watchRefuelings(vehicleId),
    );

/// One refueling by id (null when missing or deleted), live.
final refuelingProvider = StreamProvider.family<RefuelingDetails?, String>(
  (ref, id) => ref.watch(databaseProvider).watchRefueling(id),
);

/// The consumption engine's input for every tank of a vehicle (tank →
/// samples), live — a lighter query than [refuelingsProvider] (see
/// `watchRefuelSamples`).
final refuelSamplesProvider =
    StreamProvider.family<Map<int, List<RefuelSample>>, String>(
      (ref, vehicleId) =>
          ref.watch(databaseProvider).watchRefuelSamples(vehicleId),
    );

/// Identifies one tank of one vehicle (2-tank vehicles are measured per
/// tank, e.g. gasoline and CNG separately).
typedef TankKey = ({String vehicleId, int tank});

/// Consumption engine output for one tank of a vehicle. Recomputes whenever
/// a refueling changes or the "economy position" setting changes — and only
/// then: the result is cached per (vehicle, tank) like a memoized selector,
/// so History, the detail screen and Reports share one computation.
final tankConsumptionProvider =
    Provider.family<AsyncValue<ConsumptionStats>, TankKey>((ref, key) {
      final position = ref.watch(
        settingsProvider.select((s) => s.economyPosition),
      );
      return ref
          .watch(refuelSamplesProvider(key.vehicleId))
          .whenData(
            (byTank) => ConsumptionStats.compute(
              byTank[key.tank] ?? const [],
              position: position,
            ),
          );
    });

/// Consumption stats for a vehicle's main tank (tank 1). Use
/// `stats.resultFor(refuelingId)` for one row's efficiency / distance, and
/// the aggregate getters (`averageEfficiency`, `fullTankRatio`, …) for
/// reports. Efficiencies are distance per volume in the vehicle's native
/// units — format them with `efficiencyText(...)`.
final refuelingStatsProvider =
    Provider.family<AsyncValue<ConsumptionStats>, String>(
      (ref, vehicleId) =>
          ref.watch(tankConsumptionProvider((vehicleId: vehicleId, tank: 1))),
    );
