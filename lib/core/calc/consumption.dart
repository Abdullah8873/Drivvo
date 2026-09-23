import 'dart:math' as math;

import '../settings/app_settings.dart' show EconomyPosition;

/// One refuel as the consumption engine sees it — a plain value object so the
/// math doesn't depend on the database (like a DTO).
///
/// [volume] and [cost] are the totals for the tank being measured (all fuel
/// lines of that tank; [cost] after discount).
class RefuelSample {
  const RefuelSample({
    required this.id,
    required this.date,
    required this.odometer,
    required this.volume,
    required this.cost,
    this.fullTank = true,
    this.missedPrevious = false,
  });

  final String id;
  final DateTime date;
  final double odometer;
  final double volume;
  final double cost;
  final bool fullTank;
  final bool missedPrevious;
}

/// A measured cycle between two full tanks.
class FuelCycle {
  const FuelCycle({
    required this.start,
    required this.end,
    required this.distance,
    required this.volume,
    required this.cost,
  });

  /// The full-tank refuel that starts the cycle (the baseline).
  final RefuelSample start;

  /// The full-tank refuel that closes the cycle.
  final RefuelSample end;

  /// `end.odometer - start.odometer`.
  final double distance;

  /// Fuel added after [start] up to and including [end] (partials included)
  /// — that's the fuel burnt to drive [distance].
  final double volume;

  /// Cost of that fuel.
  final double cost;

  /// Distance per volume (e.g. km/L), in the vehicle's native units.
  double get efficiency => distance / volume;

  double get costPerDistance => cost / distance;
}

/// Per-refuel output of the engine.
class RefuelResult {
  const RefuelResult({
    required this.refuel,
    this.distanceSincePrevious,
    this.cycle,
  });

  final RefuelSample refuel;

  /// Odometer delta from the previous refuel (null for the first one).
  final double? distanceSincePrevious;

  /// The cycle attributed to this refuel (per [EconomyPosition]), if any.
  final FuelCycle? cycle;

  /// Cycle efficiency shown on this refuel, or null.
  double? get efficiency => cycle?.efficiency;

  /// Cycle cost per distance shown on this refuel, or null.
  double? get costPerDistance => cycle?.costPerDistance;

  /// Price per unit actually paid on this refuel.
  double? get pricePerUnit =>
      refuel.volume > 0 ? refuel.cost / refuel.volume : null;
}

/// Everything the History and Reports screens need about fuel consumption.
/// Build it with [ConsumptionStats.compute].
class ConsumptionStats {
  const ConsumptionStats._({required this.results, required this.cycles});

  static const empty = ConsumptionStats._(results: [], cycles: []);

  /// One entry per refuel, oldest first.
  final List<RefuelResult> results;

  /// Every measured full-to-full cycle, oldest first.
  final List<FuelCycle> cycles;

  /// Runs Drivvo's rules over a vehicle's refuels (any order):
  ///
  /// - Efficiency is measured between two FULL tanks: distance is the
  ///   odometer difference, volume is everything added after the first full
  ///   tank up to and including the second (partial fills accumulate).
  /// - A refuel flagged "missed previous refueling" breaks the chain: that
  ///   cycle is discarded and (if full) it becomes the new baseline.
  /// - A full tank whose odometer isn't past the baseline is rejected and
  ///   isn't used as a baseline either; the next full tank becomes it.
  /// - [position] decides whether a cycle shows on the refuel that starts it
  ///   (Drivvo's default) or the one that closes it.
  factory ConsumptionStats.compute(
    Iterable<RefuelSample> refuels, {
    EconomyPosition position = EconomyPosition.cycleStart,
  }) {
    final sorted = [...refuels]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.odometer.compareTo(b.odometer);
      });
    if (sorted.isEmpty) return empty;

    final cycles = <FuelCycle>[];
    final cycleByRefuelId = <String, FuelCycle>{};

    RefuelSample? baseline; // last full tank we can measure from
    var volume = 0.0;
    var cost = 0.0;
    for (final r in sorted) {
      if (r.missedPrevious) baseline = null; // unknown fuel went in: reset
      if (baseline == null) {
        if (r.fullTank) baseline = r;
        volume = 0;
        cost = 0;
        continue;
      }
      volume += r.volume;
      cost += r.cost;
      if (!r.fullTank) continue;

      final distance = r.odometer - baseline.odometer;
      if (distance > 0 && volume > 0) {
        final cycle = FuelCycle(
          start: baseline,
          end: r,
          distance: distance,
          volume: volume,
          cost: cost,
        );
        cycles.add(cycle);
        final owner = position == EconomyPosition.cycleStart ? baseline : r;
        cycleByRefuelId[owner.id] = cycle;
      }
      // An odometer that didn't move forward is a typo or a backwards
      // reading: measuring from it would inflate the next cycle, so the
      // next full tank becomes the baseline instead.
      baseline = distance > 0 ? r : null;
      volume = 0;
      cost = 0;
    }

    final results = [
      for (final (i, r) in sorted.indexed)
        RefuelResult(
          refuel: r,
          distanceSincePrevious: i == 0
              ? null
              : r.odometer - sorted[i - 1].odometer,
          cycle: cycleByRefuelId[r.id],
        ),
    ];
    return ConsumptionStats._(results: results, cycles: cycles);
  }

  /// Result for one refuel id, or null.
  RefuelResult? resultFor(String refuelId) =>
      results.where((r) => r.refuel.id == refuelId).firstOrNull;

  int get count => results.length;
  bool get isEmpty => results.isEmpty;

  Iterable<RefuelSample> get _refuels => results.map((r) => r.refuel);

  double get totalCost => _refuels.fold(0, (s, r) => s + r.cost);
  double get totalVolume => _refuels.fold(0, (s, r) => s + r.volume);

  DateTime? get firstDate => results.firstOrNull?.refuel.date;
  DateTime? get lastDate => results.lastOrNull?.refuel.date;

  /// Distance between the first and the last refuel.
  double get trackedDistance => count < 2
      ? 0
      : results.last.refuel.odometer - results.first.refuel.odometer;

  double get _cycleDistance => cycles.fold(0, (s, c) => s + c.distance);
  double get _cycleVolume => cycles.fold(0, (s, c) => s + c.volume);
  double get _cycleCost => cycles.fold(0, (s, c) => s + c.cost);

  /// Overall efficiency: total measured distance / total measured volume
  /// (weights long cycles more than averaging the cycle values would).
  double? get averageEfficiency =>
      cycles.isEmpty ? null : _cycleDistance / _cycleVolume;

  /// Highest cycle efficiency (distance per volume: higher = better).
  double? get bestEfficiency =>
      cycles.isEmpty ? null : cycles.map((c) => c.efficiency).reduce(math.max);

  double? get worstEfficiency =>
      cycles.isEmpty ? null : cycles.map((c) => c.efficiency).reduce(math.min);

  /// Efficiency of the most recent measured cycle.
  double? get lastEfficiency => cycles.lastOrNull?.efficiency;

  /// Fuel cost per distance over the measured cycles.
  double? get costPerDistance =>
      cycles.isEmpty ? null : _cycleCost / _cycleDistance;

  /// Average paid per unit of volume across all refuels.
  double? get averagePricePerUnit =>
      totalVolume > 0 ? totalCost / totalVolume : null;

  Iterable<double> get _prices =>
      results.map((r) => r.pricePerUnit).whereType<double>();

  double? get lowestPricePerUnit =>
      _prices.isEmpty ? null : _prices.reduce(math.min);

  double? get highestPricePerUnit =>
      _prices.isEmpty ? null : _prices.reduce(math.max);

  /// Share of refuels that filled the tank, 0..1.
  double? get fullTankRatio => isEmpty
      ? null
      : _refuels.where((r) => r.fullTank).length / results.length;

  /// Average distance between consecutive refuels.
  double? get averageDistanceBetween =>
      count < 2 ? null : trackedDistance / (count - 1);

  /// Average days between consecutive refuels (fractional).
  double? get averageDaysBetween {
    if (count < 2) return null;
    final span = lastDate!.difference(firstDate!);
    return span.inMinutes / Duration.minutesPerDay / (count - 1);
  }

  /// Average volume per refuel.
  double? get averageVolume => isEmpty ? null : totalVolume / count;

  /// How far a full tank of [tankCapacity] should go at the average
  /// efficiency, or null when unknown.
  double? estimatedRange(double? tankCapacity) {
    final eff = averageEfficiency;
    if (eff == null || tankCapacity == null || tankCapacity <= 0) return null;
    return eff * tankCapacity;
  }
}
