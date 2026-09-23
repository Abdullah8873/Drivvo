import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../refueling/refueling_providers.dart';
import 'history_calc.dart';
import 'history_queries.dart';

/// Live timeline of one vehicle (≈ a `useQuery(['timeline', vehicleId])`
/// that refetches whenever the database changes).
final timelineProvider = StreamProvider.autoDispose
    .family<List<TimelineRecord>, String>(
      (ref, vehicleId) => ref.watch(databaseProvider).watchTimeline(vehicleId),
    );

/// Which vehicle a record belongs to — the detail screen only gets
/// `module` + `id` from the URL.
final recordVehicleIdProvider = FutureProvider.autoDispose
    .family<String?, (RecordModule, String)>(
      (ref, key) => ref.watch(databaseProvider).recordVehicleId(key.$1, key.$2),
    );

/// A single vehicle row (tank capacity, distance unit…).
final vehicleByIdProvider = StreamProvider.autoDispose.family<Vehicle?, String>(
  (ref, id) => ref.watch(databaseProvider).watchVehicle(id),
);

/// Consumption-engine output for one tank of one refuel, plus what the
/// History UI needs to label it (fuel names, kind, volume put in).
class RefuelTank {
  const RefuelTank({
    required this.tank,
    required this.kind,
    required this.fuelName,
    required this.volume,
    this.result,
  });

  /// 1 or 2.
  final int tank;

  /// Energy source of the fuel that went into this tank (km/L vs km/kg…).
  final FuelKind kind;

  /// "Petrol", or "Petrol + Ethanol" when several fuels shared the tank.
  final String fuelName;

  /// Volume that went into this tank on this refuel.
  final double volume;

  /// Engine result for this refuel on this tank (null while loading).
  final RefuelResult? result;

  /// Cycle efficiency shown on this refuel (position-aware), or null.
  double? get efficiency => result?.efficiency;

  /// Cycle cost per distance shown on this refuel, or null.
  double? get costPerDistance => result?.costPerDistance;
}

/// The shared consumption engine's output for both tanks of a vehicle —
/// History reads per-refuel and per-month efficiency from here instead of
/// doing its own math, so it always agrees with Reports.
class HistoryConsumption {
  const HistoryConsumption({required this.tank1, required this.tank2});

  static const empty = HistoryConsumption(
    tank1: ConsumptionStats.empty,
    tank2: ConsumptionStats.empty,
  );

  final ConsumptionStats tank1;
  final ConsumptionStats tank2;

  ConsumptionStats tank(int n) => n == 2 ? tank2 : tank1;

  /// One entry per tank [record] (a refuel) put fuel into, tank 1 first.
  /// Empty for other modules.
  List<RefuelTank> tanksOf(TimelineRecord record) {
    if (record.module != RecordModule.refueling) return const [];
    return [
      for (final n in const [1, 2])
        if (record.fuels.where((f) => f.tank == n).toList() case final lines
            when lines.isNotEmpty)
          RefuelTank(
            tank: n,
            kind: lines.first.kind,
            fuelName: lines.map((f) => f.name).join(' + '),
            volume: lines.fold(0.0, (s, f) => s + f.volume),
            result: tank(n).resultFor(record.id),
          ),
    ];
  }
}

/// Consumption engine output for both tanks of [vehicleId] (empty stats
/// while loading). Recomputes when refuelings or the "where fuel economy is
/// shown" setting change.
final historyConsumptionProvider = Provider.autoDispose
    .family<HistoryConsumption, String>((ref, vehicleId) {
      ConsumptionStats stats(int tank) =>
          ref
              .watch(
                tankConsumptionProvider((vehicleId: vehicleId, tank: tank)),
              )
              .value ??
          ConsumptionStats.empty;
      return HistoryConsumption(tank1: stats(1), tank2: stats(2));
    });

/// Key of [monthSummaryProvider].
typedef MonthKey = ({String vehicleId, DateTime month});

/// One month of a vehicle's timeline (null when it has no records), live —
/// the month's cost screen watches this so edits/deletes show immediately.
final monthSummaryProvider = Provider.autoDispose
    .family<AsyncValue<MonthSummary?>, MonthKey>(
      (ref, key) => ref
          .watch(timelineProvider(key.vehicleId))
          .whenData(
            (records) =>
                groupByMonth(records)
                    .where((m) => m.month == monthOf(key.month))
                    .firstOrNull,
          ),
    );
