import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../attachments/attachment_queries.dart';
import '../attachments/attachments_field.dart';
import 'history_calc.dart';
import 'history_providers.dart';
import 'history_queries.dart';
import 'widgets/timeline_widgets.dart';

/// Read-only view of one record (`/record/<module>/<id>`): colored header
/// with ‹ date › arrows that step through records of the same module, then
/// cards with values, fuel/items, details and notes.
class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.module, required this.id});

  final RecordModule module;
  final String id;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  /// The record being shown; the arrows change it without a new route.
  late String _id = widget.id;

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final vehicleId = ref
        .watch(recordVehicleIdProvider((module, widget.id)))
        .value;
    final timeline = vehicleId == null
        ? null
        : ref.watch(timelineProvider(vehicleId)).value;
    final vehicle = vehicleId == null
        ? null
        : ref.watch(vehicleByIdProvider(vehicleId)).value;
    final consumption = vehicleId == null || module != RecordModule.refueling
        ? HistoryConsumption.empty
        : ref.watch(historyConsumptionProvider(vehicleId));

    // Same-module records, newest first (the timeline's order).
    final same = timeline?.where((r) => r.module == module).toList() ?? [];
    final index = same.indexWhere((r) => r.id == _id);
    final record = index < 0 ? null : same[index];
    final older = index >= 0 && index + 1 < same.length
        ? same[index + 1]
        : null;
    final newer = index > 0 ? same[index - 1] : null;
    final fmt = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: module.color,
        title: Text(module.label),
        actions: [
          if (record != null) ...[
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final deleted = await confirmAndDeleteRecord(
                  context,
                  ref,
                  record,
                );
                if (deleted && context.mounted) context.pop();
              },
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/edit/${module.name}/${record.id}'),
            ),
          ],
        ],
        bottom: record == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('detail-older'),
                      tooltip: 'Previous',
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: older == null
                          ? null
                          : () => setState(() => _id = older.id),
                    ),
                    Text(
                      '${fmt.date(record.date)} - ${fmt.time(record.date)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    IconButton(
                      key: const Key('detail-newer'),
                      tooltip: 'Next',
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: newer == null
                          ? null
                          : () => setState(() => _id = newer.id),
                    ),
                  ],
                ),
              ),
      ),
      body: switch ((timeline, record)) {
        (null, _) => const Center(child: CircularProgressIndicator()),
        (_, null) => const Center(child: Text('Record not found')),
        (final all?, final r?) => _DetailBody(
          record: r,
          timeline: all,
          vehicle: vehicle,
          consumption: consumption,
          fmt: fmt,
        ),
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.record,
    required this.timeline,
    required this.vehicle,
    required this.consumption,
    required this.fmt,
  });

  final TimelineRecord record;
  final List<TimelineRecord> timeline;
  final Vehicle? vehicle;

  /// Consumption engine output (efficiency, cost/distance per refuel).
  final HistoryConsumption consumption;
  final Formatters fmt;

  DistanceUnit get unit => vehicle?.distanceUnit ?? DistanceUnit.km;

  String _dist(double v) => fmt.distance(v, unit);

  @override
  Widget build(BuildContext context) {
    final r = record;
    final sincePrev = distanceSincePrevious(timeline, r);
    final cards = <Widget>[
      _InfoCard(
        title: 'Values',
        rows: [
          if (r.odometer != null) ('Odometer', _dist(r.odometer!)),
          if (sincePrev != null) ('Distance since last', _dist(sincePrev)),
          if (r.module != RecordModule.reading &&
              r.module != RecordModule.checklist)
            ('Total', fmt.money(r.amount)),
          if (r.module == RecordModule.checklist)
            ('Result', r.checklistCounts.summary),
        ],
      ),
      ...switch (r.module) {
        RecordModule.refueling => _refuelCards(),
        RecordModule.expense ||
        RecordModule.service ||
        RecordModule.income => _entryCards(),
        RecordModule.route => _routeCards(),
        RecordModule.checklist => _checklistCards(),
        _ => const <Widget>[],
      },
      _InfoCard(
        title: 'Details',
        rows: [
          if (r.place != null)
            (
              r.module == RecordModule.refueling ? 'Gas station' : 'Place',
              r.place!,
            ),
          if (r.paymentMethod != null) ('Payment method', r.paymentMethod!),
          if (r.reason != null) ('Reason', r.reason!),
          if (r.driver != null) ('Driver', r.driver!),
        ],
      ),
      if (r.notes != null && r.notes!.trim().isNotEmpty)
        _InfoCard(title: 'Notes', child: Text(r.notes!)),
      if (r.hasAttachments)
        if (attachmentParentTable(r.module) case final table?)
          _InfoCard(
            title: 'Attachments',
            child: RecordAttachmentsList(
              parentTable: table,
              parentId: r.entry?.parentId ?? r.id,
            ),
          ),
    ];
    return ListView(padding: const EdgeInsets.all(12), children: cards);
  }

  List<Widget> _checklistCards() {
    String statusText(ChecklistStatus? s) => switch (s) {
      ChecklistStatus.ok => 'OK',
      ChecklistStatus.problem => 'Problem',
      ChecklistStatus.na => 'N/A',
      null => '—',
    };
    return [
      _InfoCard(
        title: record.title,
        rows: [for (final a in record.answers) (a.label, statusText(a.status))],
      ),
      if (record.answers.any(
        (a) =>
            a.status == ChecklistStatus.problem &&
            (a.note?.trim().isNotEmpty ?? false),
      ))
        _InfoCard(
          title: 'Problems',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in record.answers)
                if (a.status == ChecklistStatus.problem &&
                    (a.note?.trim().isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        text: '${a.label}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        children: [
                          TextSpan(
                            text: a.note,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _refuelCards() {
    final r = record;
    final refuel = r.refueling!;
    final tanks = consumption.tanksOf(r);
    final per = Formatters.distanceUnitLabel(unit);

    // "% of tank": volume that went into each tank vs that tank's capacity
    // (null capacity → hint instead of a gauge).
    double? capacityOf(int tank) =>
        tank == 2 ? vehicle?.tank2Capacity : vehicle?.tank1Capacity;
    final gauges = vehicle == null
        ? const <Widget>[]
        : <Widget>[
            for (final t in tanks)
              if (capacityOf(t.tank) case final c? when c > 0)
                _TankGauge(
                  share: t.volume / c,
                  label: tanks.length > 1 ? 'of ${t.fuelName} tank' : null,
                ),
            if (tanks.any((t) => (capacityOf(t.tank) ?? 0) <= 0))
              const _TankCapacityHint(),
          ];

    return [
      for (final f in r.fuels)
        _InfoCard(
          title: f.name,
          rows: [
            (
              'Price / ${fmt.volumeUnitLabel(f.kind)}',
              fmt.unitPrice(f.pricePerUnit, fmt.volumeUnitLabel(f.kind)),
            ),
            ('Total', fmt.money(f.total)),
            ('Volume', fmt.volume(f.volume, kind: f.kind)),
          ],
        ),
      _InfoCard(
        title: 'Consumption',
        rows: [
          ('Complete tank', refuel.fullTank ? 'Yes' : 'No'),
          if (refuel.missedPrevious) ('Missed previous refueling', 'Yes'),
          if (refuel.discount != null && refuel.discount! > 0)
            ('Discount', fmt.money(refuel.discount!)),
          for (final t in tanks)
            if (t.efficiency != null) ...[
              (
                tankLabel('Efficiency', t, tanks.length),
                efficiencyText(fmt, t.efficiency!, unit, t.kind),
              ),
              (
                tankLabel('Cost / $per', t, tanks.length),
                fmt.money(t.costPerDistance!),
              ),
            ],
        ],
        child: gauges.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: gauges,
              ),
      ),
    ];
  }

  List<Widget> _entryCards() {
    final e = record.entry!;
    return [
      _InfoCard(
        title: e.title?.trim().isNotEmpty == true ? e.title! : 'Items',
        rows: [
          for (final i in record.items) (i.name, fmt.money(i.amount)),
          if (e.discount != null && e.discount! > 0)
            ('Discount', fmt.money(e.discount!)),
          if (e.installmentCount > 1)
            ('Installment', '${e.installmentNo}/${e.installmentCount}'),
        ],
      ),
    ];
  }

  List<Widget> _routeCards() {
    final route = record.route!;
    String when(DateTime d) => '${fmt.date(d)} ${fmt.time(d)}';
    final distance = route.endOdometer == null
        ? null
        : route.endOdometer! - route.startOdometer;
    final duration = route.endDate?.difference(route.startDate);
    final per = Formatters.distanceUnitLabel(unit);

    return [
      _InfoCard(
        title: 'Route',
        rows: [
          ('Origin', route.origin ?? '-'),
          ('Start', when(route.startDate)),
          ('Initial odometer', _dist(route.startOdometer)),
          ('Destination', route.destination ?? '-'),
          if (route.endDate != null) ('End', when(route.endDate!)),
          if (route.endOdometer != null)
            ('Final odometer', _dist(route.endOdometer!)),
          if (distance != null) ('Distance', _dist(distance)),
          if (duration != null && !duration.isNegative)
            (
              'Duration',
              '${duration.inHours} h ${duration.inMinutes % 60} min',
            ),
        ],
      ),
      if (route.mode == RouteMode.trip)
        _InfoCard(
          title: 'Trip',
          rows: [
            if (route.valuePerDistance != null)
              ('Value / $per', fmt.money(route.valuePerDistance!)),
            if (route.total != null) ('Total', fmt.money(route.total!)),
          ],
        )
      else
        _InfoCard(
          title: 'Freight',
          rows: [
            if (route.cargoType != null) ('Cargo type', route.cargoType!),
            if (route.contractor != null) ('Contractor', route.contractor!),
            if (route.cargoUnit != null) ('Unit', route.cargoUnit!),
            if (route.cargoAmount != null)
              ('Amount', fmt.number(route.cargoAmount!, decimals: 2)),
            if (route.cargoWeight != null)
              ('Weight', fmt.number(route.cargoWeight!, decimals: 2)),
            if (route.cargoVolume != null)
              ('Volume (m³)', fmt.number(route.cargoVolume!, decimals: 2)),
            if (route.freightValue != null)
              ('Freight value', fmt.money(route.freightValue!)),
            if (route.installments > 1)
              ('Installments', '${route.installments}'),
          ],
        ),
    ];
  }
}

/// White rounded card with a title and label/value rows (and/or a child).
/// Renders nothing when it has no content.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.rows = const [], this.child});

  final String title;
  final List<(String, String)> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && child == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(value, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ?child,
          ],
        ),
      ),
    );
  }
}

/// Round gauge showing how much of the tank this refuel filled.
class _TankGauge extends StatelessWidget {
  const _TankGauge({required this.share, this.label});

  /// 0..1 (clamped for display; overfills show >100% in the label).
  final double share;

  /// Caption next to the gauge; defaults to "of tank".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  color: RecordModule.refueling.color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                Center(
                  child: Text(
                    '${(share * 100).round()}%',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label ?? 'of tank',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the "% of tank" gauge when the vehicle has no capacity
/// for the tank that was filled (so the missing gauge isn't a mystery).
class _TankCapacityHint extends StatelessWidget {
  const _TankCapacityHint();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Set tank capacity in the vehicle to see % of tank',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
