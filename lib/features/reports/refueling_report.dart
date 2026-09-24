import 'dart:math' as math;

import '../../core/calc/consumption.dart';
import '../../core/db/tables.dart' show FuelKind;
import '../history/history_calc.dart' show monthOf;
import 'report_period.dart';

// Pure aggregation for the Reports → Refueling tab (no widgets, no
// providers), so every number on the tab is unit-tested. Distance/cost/price
// figures come from plain refueling data; every efficiency and cost-per-km
// figure is built from the shared consumption engine's `FuelCycle`s and
// `RefuelResult`s (`core/calc/consumption.dart`) so the numbers always agree
// with History's row-by-row efficiency.
//
// Two-tank vehicles are measured "per tank": cycles are tagged with the fuel
// that was in that tank (see [tagCycle]), so the Fuel section's chips never
// blend km/L with km/kg. The top stat grid's price/efficiency cards and the
// "Refueling routine" card use the vehicle's tank 1 (the primary tank) —
// mixing tank 1 and tank 2 into one average would be meaningless the moment
// their fuels use different volume units.

/// One fuel line of a refueling (DB/Riverpod-free — a `TimelineRecord`'s
/// `FuelLine`s map straight onto these).
class ReportFuelLine {
  const ReportFuelLine({
    required this.fuelName,
    required this.kind,
    required this.tank,
    required this.volume,
    required this.total,
  });

  final String fuelName;
  final FuelKind kind;
  final int tank;

  /// Volume of this line.
  final double volume;

  /// Pre-discount total of this line (the refueling's discount is prorated
  /// across lines by [RefuelingEntry.costForLine]).
  final double total;
}

/// One refueling flattened for report aggregation.
class RefuelingEntry {
  const RefuelingEntry({
    required this.id,
    required this.date,
    required this.fullTank,
    required this.totalCost,
    this.gasStation,
    this.lines = const [],
  });

  final String id;
  final DateTime date;
  final bool fullTank;

  /// Post-discount total cost of the whole refueling.
  final double totalCost;
  final String? gasStation;
  final List<ReportFuelLine> lines;

  double get linesTotal => lines.fold(0.0, (s, l) => s + l.total);
  double get volume => lines.fold(0.0, (s, l) => s + l.volume);

  double volumeForTank(int tank) =>
      lines.where((l) => l.tank == tank).fold(0.0, (s, l) => s + l.volume);

  /// Share of [totalCost] (i.e. with the discount applied) attributable to
  /// one fuel line, prorated by its share of [linesTotal].
  double costForLine(ReportFuelLine line) =>
      linesTotal > 0 ? line.total * totalCost / linesTotal : 0;

  double costForTank(int tank) => lines
      .where((l) => l.tank == tank)
      .fold(0.0, (s, l) => s + costForLine(l));
}

/// One measured full-to-full cycle (see [FuelCycle]) for one tank, tagged
/// with the fuel that closed it. Built by [tagCycle].
class RefuelingCycle {
  const RefuelingCycle({
    required this.tank,
    required this.fuelName,
    required this.fuelKind,
    required this.endDate,
    required this.endOdometer,
    required this.distance,
    required this.volume,
    required this.cost,
    required this.efficiency,
    required this.costPerDistance,
  });

  final int tank;
  final String fuelName;
  final FuelKind fuelKind;
  final DateTime endDate;
  final double endOdometer;
  final double distance;
  final double volume;
  final double cost;
  final double efficiency;
  final double costPerDistance;
}

/// Tags a consumption-engine [cycle] with the fuel used in [tank], read off
/// the refueling that closes it (`cycle.end`) via [fuelByRefueling] (id →
/// tank → fuel). Null when that refueling has no line for [tank] (shouldn't
/// happen for a cycle the engine measured on that tank, but keeps this total).
RefuelingCycle? tagCycle(
  FuelCycle cycle,
  int tank,
  Map<String, List<ReportFuelLine>> fuelByRefueling,
) {
  final line = (fuelByRefueling[cycle.end.id] ?? const [])
      .where((l) => l.tank == tank)
      .firstOrNull;
  if (line == null) return null;
  return RefuelingCycle(
    tank: tank,
    fuelName: line.fuelName,
    fuelKind: line.kind,
    endDate: cycle.end.date,
    endOdometer: cycle.end.odometer,
    distance: cycle.distance,
    volume: cycle.volume,
    cost: cycle.cost,
    efficiency: cycle.efficiency,
    costPerDistance: cycle.costPerDistance,
  );
}

double? _weightedEfficiency(Iterable<RefuelingCycle> cs) {
  final volume = cs.fold(0.0, (s, c) => s + c.volume);
  if (volume <= 0) return null;
  return cs.fold(0.0, (s, c) => s + c.distance) / volume;
}

double? _weightedCostPerDistance(Iterable<RefuelingCycle> cs) {
  final distance = cs.fold(0.0, (s, c) => s + c.distance);
  if (distance <= 0) return null;
  return cs.fold(0.0, (s, c) => s + c.cost) / distance;
}

/// One point of a [FuelSummary.priceSeries] (the "Fuels price chart").
typedef FuelPricePoint = ({DateTime date, double pricePerUnit});

/// Figures for one fuel shown in the "Fuel" card's chips: the fuel's
/// refuelings (volume/cost, any tank) and its measured cycles in the period,
/// oldest first by odometer (the x axis of the efficiency-by-odometer chart).
class FuelSummary {
  const FuelSummary({
    required this.fuelName,
    required this.kind,
    required this.recordCount,
    required this.volume,
    required this.cost,
    required this.cycles,
    this.priceSeries = const [],
  });

  final String fuelName;
  final FuelKind kind;
  final int recordCount;
  final double volume;
  final double cost;
  final List<RefuelingCycle> cycles;

  /// Price paid per unit on every refueling line of this fuel, oldest first
  /// (the "Fuels price chart").
  final List<FuelPricePoint> priceSeries;

  double? get lastEfficiency => cycles.lastOrNull?.efficiency;
  double? get averageEfficiency => _weightedEfficiency(cycles);
  double? get lowestEfficiency =>
      cycles.isEmpty ? null : cycles.map((c) => c.efficiency).reduce(math.min);
  double? get highestEfficiency =>
      cycles.isEmpty ? null : cycles.map((c) => c.efficiency).reduce(math.max);

  double? get lastCostPerDistance => cycles.lastOrNull?.costPerDistance;
  double? get averageCostPerDistance => _weightedCostPerDistance(cycles);
  double? get lowestCostPerDistance => cycles.isEmpty
      ? null
      : cycles.map((c) => c.costPerDistance).reduce(math.min);
  double? get highestCostPerDistance => cycles.isEmpty
      ? null
      : cycles.map((c) => c.costPerDistance).reduce(math.max);

  /// Average price paid per unit of volume (cost / volume, weighted).
  double? get averagePricePerUnit => volume > 0 ? cost / volume : null;
}

/// Figures for one gas station's rows in the period.
class StationSummary {
  const StationSummary({
    required this.name,
    required this.recordCount,
    required this.volume,
    required this.cost,
  });

  final String name;
  final int recordCount;
  final double volume;
  final double cost;

  double? get averagePricePerUnit => volume > 0 ? cost / volume : null;
}

/// One gap between two consecutive refuelings of the primary tank (any
/// order), used for the "Refueling routine" averages.
typedef RefuelGap = ({DateTime date, double distance, double days});

/// Consecutive-refueling gaps from the primary tank's engine results
/// (oldest → newest); the first refueling has no previous one so it isn't
/// included.
List<RefuelGap> refuelGaps(List<RefuelResult> primaryResults) {
  final sorted = [...primaryResults]
    ..sort((a, b) => a.refuel.date.compareTo(b.refuel.date));
  return [
    for (final (i, r) in sorted.indexed)
      if (i > 0)
        (
          date: r.refuel.date,
          distance: r.distanceSincePrevious ?? 0,
          days:
              r.refuel.date.difference(sorted[i - 1].refuel.date).inMinutes /
              Duration.minutesPerDay,
        ),
  ];
}

/// Every figure and chart series on the Refueling tab.
class RefuelingReport {
  const RefuelingReport({
    required this.entryCount,
    required this.days,
    required this.distance,
    required this.totalCost,
    required this.totalVolume,
    required this.fullTankCount,
    required this.primaryPricePerUnit,
    required this.lowestPricePerUnit,
    required this.highestPricePerUnit,
    required this.primaryEfficiency,
    required this.primaryLastEfficiency,
    required this.lowestEfficiency,
    required this.highestEfficiency,
    required this.primaryLastCostPerDistance,
    required this.primaryLowestCostPerDistance,
    required this.primaryHighestCostPerDistance,
    required this.averageDistanceBetween,
    required this.averageDaysBetween,
    required this.estimatedRange,
    required this.months,
    required this.monthlyCost,
    required this.fuels,
    required this.stations,
  });

  /// Refuelings in the period (any tank).
  final int entryCount;

  /// Days the period covers (see `reportSpan`); 0 = no "by day" figures.
  final int days;

  /// Distance driven in the period (see `periodDistance`); 0 = unknown.
  final double distance;

  /// Cost / volume of every refueling in the period (all tanks).
  final double totalCost;
  final double totalVolume;

  /// How many of [entryCount] filled the tank.
  final int fullTankCount;

  /// Price paid per unit of volume on the primary tank, period-scoped
  /// (engine `RefuelResult.pricePerUnit`, weighted by volume for the
  /// average).
  final double? primaryPricePerUnit;
  final double? lowestPricePerUnit;
  final double? highestPricePerUnit;

  /// Primary tank's efficiency over cycles that end in the period (engine
  /// `FuelCycle.efficiency`, weighted by volume for the average).
  final double? primaryEfficiency;

  /// Efficiency of the primary tank's most recent cycle in the period (the
  /// "Fuel efficiency — Last" figure when the Fuel card's "All" chip is
  /// selected).
  final double? primaryLastEfficiency;
  final double? lowestEfficiency;
  final double? highestEfficiency;

  /// Cost per distance of the primary tank's most recent cycle in the
  /// period.
  final double? primaryLastCostPerDistance;
  final double? primaryLowestCostPerDistance;
  final double? primaryHighestCostPerDistance;

  /// Average km (or the vehicle's unit) / days between consecutive
  /// primary-tank refuelings that land in the period.
  final double? averageDistanceBetween;
  final double? averageDaysBetween;

  /// [primaryEfficiency] × the primary tank's capacity; null when the
  /// capacity isn't set.
  final double? estimatedRange;

  /// Continuous months (first day) from the period's first to last refuel.
  final List<DateTime> months;

  /// Refueling cost per month (all tanks) for the "Monthly expenses" bars.
  final Map<DateTime, double> monthlyCost;

  /// One entry per fuel used in the period, largest volume first (the "All"
  /// chip in the Fuel card aggregates all of these).
  final List<FuelSummary> fuels;

  /// One entry per gas station used in the period, largest cost first.
  final List<StationSummary> stations;

  double? perDay(double v) => days > 0 ? v / days : null;
  double? perDistance(double v) => distance > 0 ? v / distance : null;

  double? get costPerDay => perDay(totalCost);
  double? get costPerDistance => perDistance(totalCost);
  double? get volumePerDay => perDay(totalVolume);
  double? get averageVolumePerRefuel =>
      entryCount > 0 ? totalVolume / entryCount : null;

  double? get fullTankRatio =>
      entryCount > 0 ? fullTankCount / entryCount : null;

  /// Cost-per-day projected over a 30-day month.
  double? get monthlyProjection {
    final perDayCost = costPerDay;
    return perDayCost == null ? null : perDayCost * 30;
  }
}

/// Builds the Refueling report.
///
/// - [entries]: every refueling of the vehicle (any order) — filtered to
///   [range] internally, like `buildGeneralReport`.
/// - [cycles]: every measured cycle of every tank ([tagCycle] output, any
///   order) — a cycle counts when it **ends** in [range] (it may have
///   started earlier), the same rule History uses per month.
/// - [primaryResults]: the primary tank's full `ConsumptionStats.results`
///   (any order) — source of the price and "refueling routine" figures.
/// - [distance]: period distance driven (`periodDistance`, computed by the
///   caller so both General and Refueling agree on it).
/// - [primaryTankCapacity]: the primary tank's capacity, for the estimated
///   range figure.
RefuelingReport buildRefuelingReport({
  required List<RefuelingEntry> entries,
  required List<RefuelingCycle> cycles,
  required List<RefuelResult> primaryResults,
  required ReportRange range,
  required int days,
  required double distance,
  int primaryTank = 1,
  double? primaryTankCapacity,
}) {
  final periodEntries = [
    for (final e in entries)
      if (range.contains(e.date)) e,
  ]..sort((a, b) => a.date.compareTo(b.date));

  final periodCycles = [
    for (final c in cycles)
      if (range.contains(c.endDate)) c,
  ]..sort((a, b) => a.endOdometer.compareTo(b.endOdometer));

  final primaryCycles = [
    for (final c in periodCycles)
      if (c.tank == primaryTank) c,
  ];

  final totalCost = periodEntries.fold(0.0, (s, e) => s + e.totalCost);
  final totalVolume = periodEntries.fold(0.0, (s, e) => s + e.volume);
  final fullTankCount = periodEntries.where((e) => e.fullTank).length;

  final primaryPriceResults = [
    for (final r in primaryResults)
      if (range.contains(r.refuel.date) && r.refuel.volume > 0) r,
  ];
  final primaryPriceVolume = primaryPriceResults.fold(
    0.0,
    (s, r) => s + r.refuel.volume,
  );
  final primaryPrices = [for (final r in primaryPriceResults) r.pricePerUnit!];

  final gaps = [
    for (final g in refuelGaps(primaryResults))
      if (range.contains(g.date)) g,
  ];

  // Fuel breakdown: group the period's fuel lines by fuel name, largest
  // volume first (matches the donut's "largest slice first" convention).
  final fuelVolume = <String, double>{};
  final fuelCost = <String, double>{};
  final fuelKind = <String, FuelKind>{};
  final fuelRecords = <String, Set<String>>{};
  final fuelPrices = <String, List<FuelPricePoint>>{};
  for (final e in periodEntries) {
    for (final l in e.lines) {
      fuelVolume[l.fuelName] = (fuelVolume[l.fuelName] ?? 0) + l.volume;
      fuelCost[l.fuelName] = (fuelCost[l.fuelName] ?? 0) + e.costForLine(l);
      fuelKind[l.fuelName] = l.kind;
      (fuelRecords[l.fuelName] ??= {}).add(e.id);
      if (l.volume > 0) {
        (fuelPrices[l.fuelName] ??= []).add((
          date: e.date,
          pricePerUnit: e.costForLine(l) / l.volume,
        ));
      }
    }
  }
  final cyclesByFuel = <String, List<RefuelingCycle>>{};
  for (final c in periodCycles) {
    (cyclesByFuel[c.fuelName] ??= []).add(c);
  }
  for (final list in cyclesByFuel.values) {
    list.sort((a, b) => a.endOdometer.compareTo(b.endOdometer));
  }
  for (final list in fuelPrices.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  final fuelNames = {...fuelVolume.keys, ...cyclesByFuel.keys}.toList()
    ..sort((a, b) => (fuelVolume[b] ?? 0).compareTo(fuelVolume[a] ?? 0));
  final fuels = [
    for (final name in fuelNames)
      FuelSummary(
        fuelName: name,
        kind: fuelKind[name] ?? FuelKind.liquid,
        recordCount: fuelRecords[name]?.length ?? 0,
        volume: fuelVolume[name] ?? 0,
        cost: fuelCost[name] ?? 0,
        cycles: cyclesByFuel[name] ?? const [],
        priceSeries: fuelPrices[name] ?? const [],
      ),
  ];

  // Gas stations: grouped by name, largest cost first.
  final stationVolume = <String, double>{};
  final stationCost = <String, double>{};
  final stationRecords = <String, int>{};
  for (final e in periodEntries) {
    final station = e.gasStation;
    if (station == null || station.isEmpty) continue;
    stationVolume[station] = (stationVolume[station] ?? 0) + e.volume;
    stationCost[station] = (stationCost[station] ?? 0) + e.totalCost;
    stationRecords[station] = (stationRecords[station] ?? 0) + 1;
  }
  final stationNames = stationCost.keys.toList()
    ..sort((a, b) => stationCost[b]!.compareTo(stationCost[a]!));
  final stations = [
    for (final name in stationNames)
      StationSummary(
        name: name,
        recordCount: stationRecords[name] ?? 0,
        volume: stationVolume[name] ?? 0,
        cost: stationCost[name] ?? 0,
      ),
  ];

  final primaryEfficiency = _weightedEfficiency(primaryCycles);
  final estimatedRange =
      primaryEfficiency == null ||
          primaryTankCapacity == null ||
          primaryTankCapacity <= 0
      ? null
      : primaryEfficiency * primaryTankCapacity;

  final monthlyCost = <DateTime, double>{};
  for (final e in periodEntries) {
    final key = monthOf(e.date);
    monthlyCost[key] = (monthlyCost[key] ?? 0) + e.totalCost;
  }

  return RefuelingReport(
    entryCount: periodEntries.length,
    days: days,
    distance: distance,
    totalCost: totalCost,
    totalVolume: totalVolume,
    fullTankCount: fullTankCount,
    primaryPricePerUnit: primaryPriceVolume > 0
        ? primaryPriceResults.fold(0.0, (s, r) => s + r.refuel.cost) /
              primaryPriceVolume
        : null,
    lowestPricePerUnit: primaryPrices.isEmpty
        ? null
        : primaryPrices.reduce(math.min),
    highestPricePerUnit: primaryPrices.isEmpty
        ? null
        : primaryPrices.reduce(math.max),
    primaryEfficiency: primaryEfficiency,
    primaryLastEfficiency: primaryCycles.lastOrNull?.efficiency,
    lowestEfficiency: primaryCycles.isEmpty
        ? null
        : primaryCycles.map((c) => c.efficiency).reduce(math.min),
    highestEfficiency: primaryCycles.isEmpty
        ? null
        : primaryCycles.map((c) => c.efficiency).reduce(math.max),
    primaryLastCostPerDistance: primaryCycles.lastOrNull?.costPerDistance,
    primaryLowestCostPerDistance: primaryCycles.isEmpty
        ? null
        : primaryCycles.map((c) => c.costPerDistance).reduce(math.min),
    primaryHighestCostPerDistance: primaryCycles.isEmpty
        ? null
        : primaryCycles.map((c) => c.costPerDistance).reduce(math.max),
    averageDistanceBetween: gaps.isEmpty
        ? null
        : gaps.fold(0.0, (s, g) => s + g.distance) / gaps.length,
    averageDaysBetween: gaps.isEmpty
        ? null
        : gaps.fold(0.0, (s, g) => s + g.days) / gaps.length,
    estimatedRange: estimatedRange,
    months: periodEntries.isEmpty
        ? const []
        : monthsBetween(periodEntries.first.date, periodEntries.last.date),
    monthlyCost: monthlyCost,
    fuels: fuels,
    stations: stations,
  );
}
