import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/record_module.dart';
import '../../refueling/efficiency_text.dart';
import '../../refueling/refueling_providers.dart';
import '../general_report.dart' show periodDistance;
import '../refueling_report.dart';
import '../widgets/donut_chart.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/report_section.dart';
import '../widgets/report_tab_scaffold.dart';
import '../widgets/stat_card.dart';

/// Reports → REFUELING: cost/volume/price/efficiency cards, the "Refueling
/// routine" card, monthly cost bars, a per-fuel breakdown card, gas
/// stations, and four charts (fuels/stations donuts, efficiency-by-odometer
/// and price-over-time lines). All numbers come from `buildRefuelingReport`;
/// every efficiency figure is formatted with `efficiencyText` so the
/// Settings efficiency format applies.
///
/// Two-tank vehicles are measured per tank (see `refueling_report.dart`):
/// the top stat grid and the "Refueling routine" card reflect tank 1 (the
/// primary tank), while the "Fuel" card's chips break every figure down per
/// fuel so a km/L average never blends with a km/kg one.
class RefuelingReportTab extends StatelessWidget {
  const RefuelingReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ReportTabScaffold(
      modules: const {RecordModule.refueling},
      builder: (context, ref, scope) {
        final fmt = ref.watch(formattersProvider);
        final vehicle = scope.vehicle;
        final unit = vehicle.distanceUnit;
        final unitLabel = Formatters.distanceUnitLabel(unit);

        final tank1Async = ref.watch(refuelingStatsProvider(vehicle.id));
        final tank2Async = ref.watch(
          tankConsumptionProvider((vehicleId: vehicle.id, tank: 2)),
        );
        if (tank1Async.isLoading || tank2Async.isLoading) {
          return const [Center(child: CircularProgressIndicator())];
        }
        final error = tank1Async.error ?? tank2Async.error;
        if (error != null) return [Center(child: Text('$error'))];

        final tank1Stats = tank1Async.requireValue;
        final tank2Stats = tank2Async.requireValue;

        // Every refueling of the vehicle (all periods — cycles may start
        // before the selected one), flattened into report DTOs from the
        // History timeline (already loaded by `ReportScope`).
        final fuelByRefueling = <String, List<ReportFuelLine>>{
          for (final r in scope.timeline)
            if (r.module == RecordModule.refueling)
              r.id: [
                for (final f in r.fuels)
                  ReportFuelLine(
                    fuelName: f.name,
                    kind: f.kind,
                    tank: f.tank,
                    volume: f.volume,
                    total: f.total,
                  ),
              ],
        };
        final entries = [
          for (final r in scope.timeline)
            if (r.module == RecordModule.refueling)
              RefuelingEntry(
                id: r.id,
                date: r.date,
                fullTank: r.refueling?.fullTank ?? true,
                totalCost: r.amount,
                gasStation: r.place,
                lines: fuelByRefueling[r.id] ?? const [],
              ),
        ];
        final cycles = <RefuelingCycle>[
          for (final c in tank1Stats.cycles) ?tagCycle(c, 1, fuelByRefueling),
          for (final c in tank2Stats.cycles) ?tagCycle(c, 2, fuelByRefueling),
        ];

        final report = buildRefuelingReport(
          entries: entries,
          cycles: cycles,
          primaryResults: tank1Stats.results,
          range: scope.range,
          days: scope.days,
          distance: periodDistance(scope.timeline, scope.range),
          primaryTankCapacity: vehicle.tank1Capacity,
        );
        final tank1Kind = vehicle.tank1Kind;
        final fuelKinds = {for (final f in report.fuels) f.kind}.toList();
        if (fuelKinds.isEmpty) fuelKinds.add(tank1Kind);

        String money(double? v) => v == null ? StatCard.dash : fmt.money(v);
        String costPerDistance(double? v) =>
            v == null ? StatCard.dash : fmt.unitPrice(v, unitLabel);
        String volume(double? v, [FuelKind kind = FuelKind.liquid]) =>
            v == null ? StatCard.dash : fmt.volume(v, kind: kind);
        String? pricePerUnit(double? v, FuelKind kind) =>
            v == null ? null : fmt.unitPrice(v, fmt.volumeUnitLabel(kind));
        String? efficiency(double? v, FuelKind kind) =>
            v == null ? null : efficiencyText(fmt, unit, v, kind: kind);

        return [
          StatGrid(
            children: [
              StatCard(
                key: const Key('stat-refuel-cost'),
                title: 'Cost',
                icon: Icons.payments,
                color: RecordModule.refueling.color,
                value: money(report.totalCost),
                subValues: [
                  (label: 'By day', value: money(report.costPerDay)),
                  (
                    label: 'By $unitLabel',
                    value: costPerDistance(report.costPerDistance),
                  ),
                ],
              ),
              StatCard(
                key: const Key('stat-refuel-volume'),
                title: 'Volume',
                icon: Icons.local_gas_station,
                color: RecordModule.refueling.color,
                value: volume(report.primaryVolume, tank1Kind),
                subValues: [
                  (
                    label: 'Per refueling',
                    value: volume(report.averageVolumePerRefuel, tank1Kind),
                  ),
                  (
                    label: 'By day',
                    value: volume(report.volumePerDay, tank1Kind),
                  ),
                ],
              ),
              StatCard(
                key: const Key('stat-refuel-price'),
                title: 'Average price',
                icon: Icons.sell,
                color: RecordModule.refueling.color,
                valueLabel: 'Average',
                value:
                    pricePerUnit(report.primaryPricePerUnit, tank1Kind) ??
                    StatCard.dash,
                lower: pricePerUnit(report.lowestPricePerUnit, tank1Kind),
                higher: pricePerUnit(report.highestPricePerUnit, tank1Kind),
              ),
              StatCard(
                key: const Key('stat-refuel-efficiency'),
                title: 'Fuel efficiency',
                icon: Icons.speed,
                color: RecordModule.refueling.color,
                valueLabel: 'General average',
                value:
                    efficiency(report.primaryEfficiency, tank1Kind) ??
                    StatCard.dash,
                lower: efficiency(report.lowestEfficiency, tank1Kind),
                higher: efficiency(report.highestEfficiency, tank1Kind),
              ),
            ],
          ),
          _RoutineSection(report: report, fmt: fmt, unit: unit),
          ReportSection(
            title: 'Monthly expenses chart',
            icon: Icons.bar_chart,
            color: RecordModule.refueling.color,
            subtitle: 'Refueling cost per month',
            child: MonthlyBarChart(
              months: report.months,
              formatValue: fmt.money,
              series: [
                BarSeries(
                  label: RecordModule.refueling.label,
                  color: RecordModule.refueling.color,
                  values: report.monthlyCost,
                ),
              ],
            ),
          ),
          _FuelSection(
            report: report,
            fmt: fmt,
            unit: unit,
            primaryKind: tank1Kind,
          ),
          _StationsSection(stations: report.stations, fmt: fmt),
          ReportSection(
            title: 'Fuels chart',
            icon: Icons.pie_chart,
            color: RecordModule.refueling.color,
            child: DonutChart(
              formatValue: (v) => fmt.volume(v, kind: fuelKinds.first),
              // L + kg has no total; each slice still shows its own unit.
              showTotal: fuelKinds.length == 1,
              slices: [
                for (final (i, f) in report.fuels.indexed)
                  DonutSlice(
                    label: f.fuelName,
                    value: f.volume,
                    valueText: fmt.volume(f.volume, kind: f.kind),
                    color: fuelColor(i),
                  ),
              ],
            ),
          ),
          ReportSection(
            title: 'Gas stations chart',
            icon: Icons.pie_chart,
            color: RecordModule.refueling.color,
            child: DonutChart(
              formatValue: fmt.money,
              slices: [
                for (final (i, s) in report.stations.indexed)
                  DonutSlice(
                    label: s.name,
                    value: s.cost,
                    color: stationColor(i),
                  ),
              ],
            ),
          ),
          ReportSection(
            title: 'Average by fuel chart',
            icon: Icons.show_chart,
            color: RecordModule.refueling.color,
            subtitle: 'Cycle efficiency by odometer',
            // One line per fuel (never a zig-zag between fuels), each
            // labelled in its own unit; the dashed average is tank 1's.
            child: LineChartCard(
              color: Theme.of(context).colorScheme.outline,
              series: [
                for (final (i, f) in report.fuels.indexed)
                  if (f.cycles.isNotEmpty)
                    LineSeries(
                      color: fuelColor(i),
                      formatY: (y) => efficiency(y, f.kind) ?? StatCard.dash,
                      points: [
                        for (final c in f.cycles)
                          LinePoint(x: c.endOdometer, y: c.efficiency),
                      ],
                    ),
              ],
              formatX: (x) => fmt.distance(x, unit),
              formatY: (y) => efficiency(y, tank1Kind) ?? StatCard.dash,
              average: report.primaryEfficiency,
              averageLabel: 'Fuel efficiency',
              legend: [
                for (final (i, f) in report.fuels.indexed)
                  if (f.cycles.isNotEmpty)
                    (label: f.fuelName, color: fuelColor(i)),
              ],
            ),
          ),
          ReportSection(
            title: 'Fuels price chart',
            icon: Icons.show_chart,
            color: RecordModule.refueling.color,
            subtitle: 'Price per unit over time',
            child: LineChartCard(
              color: Theme.of(context).colorScheme.outline,
              series: [
                for (final (i, f) in report.fuels.indexed)
                  if (f.priceSeries.isNotEmpty)
                    LineSeries(
                      color: fuelColor(i),
                      formatY: (y) => pricePerUnit(y, f.kind) ?? StatCard.dash,
                      points: [
                        for (final p in f.priceSeries)
                          LinePoint.date(p.date, p.pricePerUnit),
                      ],
                    ),
              ],
              formatX: (x) => fmt.date(LinePoint.xToDate(x)),
              dateAxis: true,
              formatY: (y) => pricePerUnit(y, tank1Kind) ?? StatCard.dash,
              average: report.primaryPricePerUnit,
              averageLabel: 'Fuel price',
              legend: [
                for (final (i, f) in report.fuels.indexed)
                  if (f.priceSeries.isNotEmpty)
                    (label: f.fuelName, color: fuelColor(i)),
              ],
            ),
          ),
        ];
      },
    );
  }
}

/// Distinct colors for the Fuel card's chips and the fuel-keyed charts
/// (fuel names aren't `RecordModule`s, so they don't have their own color).
final _fuelPalette = <Color>[
  RecordModule.refueling.color,
  Colors.blueGrey,
  Colors.teal,
  Colors.deepPurple,
  Colors.indigo,
  Colors.brown,
  Colors.pink,
  Colors.cyan,
];

Color fuelColor(int index) => _fuelPalette[index % _fuelPalette.length];

/// Distinct colors for the gas stations donut.
final _stationPalette = <Color>[
  Colors.indigo,
  Colors.teal,
  Colors.deepOrange,
  Colors.purple,
  Colors.blueGrey,
  Colors.brown,
  Colors.cyan,
  Colors.pink,
];

Color stationColor(int index) =>
    _stationPalette[index % _stationPalette.length];

/// The "Refueling routine" card: between-refuelings distance, frequency,
/// estimated range, monthly projection, and the full-tank progress bar.
class _RoutineSection extends StatelessWidget {
  const _RoutineSection({
    required this.report,
    required this.fmt,
    required this.unit,
  });

  final RefuelingReport report;
  final Formatters fmt;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final unitLabel = Formatters.distanceUnitLabel(unit);
    final ratio = report.fullTankRatio;

    String distanceText(double? v) =>
        v == null ? StatCard.dash : '${v.toStringAsFixed(1)} $unitLabel';
    String daysText(double? v) =>
        v == null ? StatCard.dash : '${fmt.number(v, decimals: 3)} Days';

    return ReportSection(
      title: 'Refueling routine',
      icon: Icons.route,
      color: RecordModule.refueling.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoutineRow(
            label: 'Between refuelings',
            value: distanceText(report.averageDistanceBetween),
          ),
          _RoutineRow(
            label: 'Frequency',
            value: daysText(report.averageDaysBetween),
          ),
          _RoutineRow(
            label: 'Estimated range',
            value: report.estimatedRange == null
                ? StatCard.dash
                : fmt.distance(report.estimatedRange!, unit),
          ),
          _RoutineRow(
            label: 'Monthly projection',
            value: report.monthlyProjection == null
                ? StatCard.dash
                : fmt.money(report.monthlyProjection!),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio ?? 0,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: RecordModule.refueling.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ratio == null
                ? 'No refuelings in this period'
                : '${report.fullTankCount} of ${report.entryCount} '
                      'refuelings with a full tank '
                      '(${(ratio * 100).toStringAsFixed(1)}%) — the average '
                      'is measured from one full tank to the next.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Fuel" card: a chip per fuel used in the period (plus "All"), and
/// the selected chip's efficiency / cost-per-distance range and volume /
/// cost totals (see `fuelCardFigures`). "All" shows the primary tank's
/// figures (the same ones on the top stat grid), since averaging across
/// fuels with different volume units isn't meaningful; a fuel chip shows
/// only that fuel ("—" where it has no figure).
class _FuelSection extends StatefulWidget {
  const _FuelSection({
    required this.report,
    required this.fmt,
    required this.unit,
    required this.primaryKind,
  });

  final RefuelingReport report;
  final Formatters fmt;
  final DistanceUnit unit;

  /// The vehicle's tank-1 fuel kind (unit of the "All" figures).
  final FuelKind primaryKind;

  @override
  State<_FuelSection> createState() => _FuelSectionState();
}

class _FuelSectionState extends State<_FuelSection> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final report = widget.report;
    final fmt = widget.fmt;
    final fuels = report.fuels;
    final selectedName = fuels.any((f) => f.fuelName == _selected)
        ? _selected
        : null;
    final figures = fuelCardFigures(
      report,
      fuelName: selectedName,
      primaryKind: widget.primaryKind,
    );
    final kind = figures.kind;
    final unitLabel = Formatters.distanceUnitLabel(widget.unit);

    String? eff(double? v) =>
        v == null ? null : efficiencyText(fmt, widget.unit, v, kind: kind);
    String? costKm(double? v) => v == null ? null : fmt.unitPrice(v, unitLabel);

    return ReportSection(
      title: 'Fuel',
      icon: RecordModule.refueling.icon,
      color: RecordModule.refueling.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              recordCountLabel(figures.recordCount),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selectedName == null,
                onSelected: (_) => setState(() => _selected = null),
              ),
              for (final f in fuels)
                ChoiceChip(
                  label: Text(f.fuelName),
                  selected: selectedName == f.fuelName,
                  onSelected: (_) => setState(() => _selected = f.fuelName),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Fuel efficiency — Last',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          Text(
            eff(figures.lastEfficiency) ?? StatCard.dash,
            key: const Key('fuel-card-efficiency'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: RecordModule.refueling.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _RangeBar(
            low: figures.lowestEfficiency,
            high: figures.highestEfficiency,
            marker: figures.lastEfficiency,
            format: eff,
          ),
          Text(
            'Period average '
            '${eff(figures.averageEfficiency) ?? StatCard.dash}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Text(
            'Cost / $unitLabel — Last',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          Text(
            costKm(figures.lastCostPerDistance) ?? StatCard.dash,
            key: const Key('fuel-card-cost-per-distance'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: RecordModule.refueling.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _RangeBar(
            low: figures.lowestCostPerDistance,
            high: figures.highestCostPerDistance,
            marker: figures.lastCostPerDistance,
            format: costKm,
          ),
          Text(
            'Period average '
            '${costKm(figures.averageCostPerDistance) ?? StatCard.dash}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FuelFooterStat(
                  label: 'Volume',
                  value: fmt.volume(figures.volume, kind: kind),
                ),
              ),
              Expanded(
                child: _FuelFooterStat(
                  label: 'Total cost',
                  value: fmt.money(figures.cost),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelFooterStat extends StatelessWidget {
  const _FuelFooterStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A thin "Lower … Larger" bar with a dot marking [marker] between [low]
/// and [high] (all already-formatted with [format]).
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.low,
    required this.high,
    required this.marker,
    required this.format,
  });

  final double? low;
  final double? high;
  final double? marker;
  final String? Function(double?) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final l = low;
    final h = high;
    final m = marker;
    final double? fraction = (l == null || h == null || m == null || h == l)
        ? null
        : ((m - l) / (h - l)).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth - 10;
            final markerLeft = fraction == null
                ? 0.0
                : fraction * (trackWidth < 0 ? 0.0 : trackWidth);
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 6,
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (fraction != null)
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: RecordModule.refueling.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        // Each half may wrap onto a second line on a 320px phone rather
        // than overflowing the row.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Lower ${format(low) ?? StatCard.dash}',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Larger ${format(high) ?? StatCard.dash}',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The "Gas stations" list: name, average price per unit, record count and
/// volume, total cost.
class _StationsSection extends StatelessWidget {
  const _StationsSection({required this.stations, required this.fmt});

  final List<StationSummary> stations;
  final Formatters fmt;

  @override
  Widget build(BuildContext context) {
    return ReportSection(
      title: 'Gas stations',
      icon: Icons.local_gas_station,
      color: RecordModule.refueling.color,
      child: stations.isEmpty
          ? Text(
              'No gas station on record for this period',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final s in stations) _StationRow(station: s, fmt: fmt),
              ],
            ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.station, required this.fmt});

  final StationSummary station;
  final Formatters fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Per fuel kind, never summed: "10.00 L · 20.00 kg".
    final kinds = station.volumeByKind.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final volumes = [
      for (final k in kinds) fmt.volume(station.volumeByKind[k]!, kind: k),
    ];
    final prices = [
      for (final k in kinds)
        if (station.pricePerUnit(k) case final p?)
          fmt.unitPrice(p, fmt.volumeUnitLabel(k)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station.name, style: theme.textTheme.bodyMedium),
                Text(
                  [
                    recordCountLabel(station.recordCount),
                    ...volumes,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prices.isEmpty ? StatCard.dash : prices.join('\n'),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fmt.money(station.cost),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
