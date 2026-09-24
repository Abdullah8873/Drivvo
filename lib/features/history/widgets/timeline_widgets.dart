import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/calc/achievements.dart';
import '../../../core/db/app_database.dart';
import '../../../core/format/formatters.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/record_module.dart';
import '../../refueling/efficiency_text.dart' as shared;
import '../history_calc.dart';
import '../history_providers.dart';
import '../history_queries.dart';

/// Horizontal center of the timeline track, from the list's left edge.
const double kTrackX = 30;

/// Where row/card content starts (right of the track).
const double kContentLeft = 60;

const _incomeGreen = Color(0xFF2E7D32);

/// "39.344 km/L", "2.542 L/100km", "12.500 km/kg", … — delegates to the
/// shared formatter so History honours the efficiency format chosen in
/// Settings. [kind] is required so CNG/electric never show liquid units.
String efficiencyText(
  Formatters fmt,
  double value,
  DistanceUnit unit,
  FuelKind kind,
) => shared.efficiencyText(fmt, unit, value, kind: kind) ?? '—';

/// Label for a per-tank value: "Efficiency" on single-tank refuels,
/// "Efficiency (CNG)" when the refuel filled both tanks.
String tankLabel(String label, RefuelTank tank, int tankCount) =>
    tankCount > 1 ? '$label (${tank.fuelName})' : label;

/// Asks for confirmation, then soft-deletes the record — for expenses,
/// services and incomes, its whole installment group. Returns true when
/// the record was deleted.
Future<bool> confirmAndDeleteRecord(
  BuildContext context,
  WidgetRef ref,
  TimelineRecord record,
) async {
  final installments = record.entry?.installmentCount ?? 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete record?'),
      content: Text(
        installments > 1
            ? '"${record.title}" is split into installments. '
                  'This deletes all $installments installments.'
            : '"${record.title}" will be removed from your history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('DELETE'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(databaseProvider).softDeleteRecord(record.module, record.id);
  return true;
}

/// The grey "road" line with white dashes running down the left side.
/// Every row paints its own segment, so the list looks like one track.
class TimelineTrack extends StatelessWidget {
  const TimelineTrack({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: kTrackX - 3,
      top: 0,
      bottom: 0,
      width: 6,
      child: CustomPaint(painter: _TrackPainter(Colors.grey.shade300)),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    final x = size.width / 2;
    for (double y = 3; y < size.height; y += 12) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 6), dash);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.color != color;
}

/// Colored circle with the module's icon (the dot on the track).
class ModuleDot extends StatelessWidget {
  const ModuleDot({super.key, required this.module, this.size = 36});

  final RecordModule module;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: module.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Icon(module.icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// An earned achievement shown on the timeline on its earned date — Drivvo's
/// "Completed 1 year of tracking this vehicle" style event. Purely
/// presentational: it carries no amount and isn't a [TimelineRecord], so it
/// can never affect month totals or reports (see
/// `achievement_timeline.dart`).
class AchievementTimelineRow extends ConsumerWidget {
  const AchievementTimelineRow({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    return Stack(
      children: [
        const TimelineTrack(),
        Positioned(
          left: kTrackX - 14,
          top: 10,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(kContentLeft, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  achievement.text,
                  key: Key('achievement-${achievement.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(fmt.shortDate(achievement.earnedDate!), style: grey),
            ],
          ),
        ),
      ],
    );
  }
}

/// One record on the timeline. Tap toggles the in-place details panel with
/// delete / edit / view buttons.
class TimelineRow extends ConsumerWidget {
  const TimelineRow({
    super.key,
    required this.record,
    required this.distanceUnit,
    required this.expanded,
    required this.onTap,
  });

  final TimelineRecord record;
  final DistanceUnit distanceUnit;
  final bool expanded;
  final VoidCallback onTap;

  /// "56935 km · 39.344 km/L · 5.017 L" for refuels (efficiency omitted
  /// when the engine has none for this refuel), "odometer · place" for
  /// entries.
  String _subtitle(Formatters fmt, List<RefuelTank> tanks) {
    final odo = record.odometer == null
        ? null
        : fmt.distance(record.odometer!, distanceUnit);
    final parts = <String?>[odo];
    switch (record.module) {
      case RecordModule.refueling:
        // The first tank with a measured cycle (usually the only tank).
        final measured = tanks.where((t) => t.efficiency != null).firstOrNull;
        if (measured != null) {
          parts.add(
            efficiencyText(
              fmt,
              measured.efficiency!,
              distanceUnit,
              measured.kind,
            ),
          );
        }
        if (tanks.isNotEmpty) {
          parts.add(
            tanks.map((t) => fmt.volume(t.volume, kind: t.kind)).join(' + '),
          );
        }
      case RecordModule.route:
        final r = record.route!;
        if (r.endOdometer != null) {
          parts.add(
            fmt.distance(r.endOdometer! - r.startOdometer, distanceUnit),
          );
        }
      default:
        parts.add(record.place);
    }
    return parts.whereType<String>().join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade600,
    );
    final showAmount = record.module != RecordModule.reading;
    // Efficiency comes from the shared consumption engine (per tank,
    // position-aware, respecting "missed previous refueling").
    final tanks = record.module == RecordModule.refueling
        ? ref
              .watch(historyConsumptionProvider(record.vehicleId))
              .tanksOf(record)
        : const <RefuelTank>[];

    return Stack(
      children: [
        const TimelineTrack(),
        Positioned(
          left: kTrackX - 18,
          top: 10,
          child: ModuleDot(module: record.module),
        ),
        InkWell(
          key: Key('row-${record.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kContentLeft, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(fmt, tanks),
                            style: grey,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showAmount)
                          Text(
                            fmt.money(record.amount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: record.isIncome ? _incomeGreen : null,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(fmt.shortDate(record.date), style: grey),
                      ],
                    ),
                  ],
                ),
                // AnimatedSize ≈ a CSS height transition on the details panel.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? _RowDetails(
                          record: record,
                          tanks: tanks,
                          distanceUnit: distanceUnit,
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The expanded part of a [TimelineRow].
class _RowDetails extends ConsumerWidget {
  const _RowDetails({
    required this.record,
    required this.tanks,
    required this.distanceUnit,
  });

  final TimelineRecord record;

  /// Engine results per tank filled (refuels only).
  final List<RefuelTank> tanks;
  final DistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final lines = <Widget>[];
    void line(String label, String value) =>
        lines.add(_DetailLine(label: label, value: value));

    switch (record.module) {
      case RecordModule.refueling:
        for (final f in record.fuels) {
          line(
            '${f.name} · ${fmt.volume(f.volume, kind: f.kind)} × '
            '${fmt.unitPrice(f.pricePerUnit, fmt.volumeUnitLabel(f.kind))}',
            fmt.money(f.total),
          );
        }
        for (final t in tanks) {
          if (t.efficiency == null) continue;
          line(
            tankLabel('Efficiency', t, tanks.length),
            efficiencyText(fmt, t.efficiency!, distanceUnit, t.kind),
          );
        }
        line('Full tank', record.refueling!.fullTank ? 'Yes' : 'No');
        if (record.place != null) line('Gas station', record.place!);
      case RecordModule.expense || RecordModule.service || RecordModule.income:
        for (final i in record.items) {
          line(i.name, fmt.money(i.amount));
        }
        final discount = record.entry!.discount;
        if (discount != null && discount > 0) {
          line('Discount', fmt.money(discount));
        }
        if (record.place != null) line('Place', record.place!);
      case RecordModule.route:
        final r = record.route!;
        line('Start', '${fmt.date(r.startDate)} ${fmt.time(r.startDate)}');
        if (r.endDate != null) {
          line('End', '${fmt.date(r.endDate!)} ${fmt.time(r.endDate!)}');
        }
      default:
        break;
    }
    if (record.driver != null) line('Driver', record.driver!);
    final notes = record.notes;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...lines,
          if (notes != null && notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                notes,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmAndDeleteRecord(context, ref, record),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/edit/${record.module.name}/${record.id}'),
              ),
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () =>
                    context.push('/record/${record.module.name}/${record.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Light grey card opening each month group: "SEPTEMBER 2026", spend,
/// distance, efficiency and the month-over-month insight.
class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({
    super.key,
    required this.summary,
    required this.vehicle,
    this.onTap,
  });

  final MonthSummary summary;

  /// The vehicle (distance unit, tank count and fuel kinds).
  final Vehicle vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formattersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final distanceUnit = vehicle.distanceUnit;
    final distance = summary.distance;
    // Engine cycles that close in this month, per tank (a 2-tank vehicle
    // gets one value per tank: km/L and km/kg can't be averaged together).
    final consumption = ref.watch(historyConsumptionProvider(vehicle.id));
    final efficiencies = [
      (
        summary.efficiencyFrom(consumption.tank1.cycles),
        vehicle.tank1Kind,
        vehicle.tankCount > 1 ? 'Efficiency (tank 1)' : 'Efficiency',
      ),
      if (vehicle.tankCount > 1)
        (
          summary.efficiencyFrom(consumption.tank2.cycles),
          vehicle.tank2Kind ?? FuelKind.liquid,
          'Efficiency (tank 2)',
        ),
    ];
    final change = summary.changeVsPrevious;
    final prevMonthName = DateFormat('MMMM')
        .format(DateTime(summary.month.year, summary.month.month - 1));

    return Stack(
      children: [
        const TimelineTrack(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          // Material sizes to its child (the Wrap of stats) unless told
          // otherwise, so without this the card hugs its content instead of
          // stretching across the row like Drivvo's month header.
          child: SizedBox(
            width: double.infinity,
            child: Material(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: Key('month-${summary.month.year}-${summary.month.month}'),
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy')
                            .format(summary.month)
                            .toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.grey.shade700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _Stat(
                            icon: Icons.payments_outlined,
                            label: 'Spent',
                            value: fmt.money(summary.spent),
                          ),
                          if (distance != null)
                            _Stat(
                              icon: Icons.route_outlined,
                              label: 'Distance',
                              value: fmt.distance(distance, distanceUnit),
                            ),
                          for (final (value, kind, label) in efficiencies)
                            if (value != null)
                              _Stat(
                                icon: Icons.local_gas_station_outlined,
                                label: label,
                                value: efficiencyText(
                                  fmt,
                                  value,
                                  distanceUnit,
                                  kind,
                                ),
                              ),
                        ],
                      ),
                      if (change != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              change <= 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 16,
                              color: change <= 0
                                  ? _incomeGreen
                                  : RecordModule.expense.color,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Expenses ${(change.abs() * 100).round()}% '
                                '${change <= 0 ? 'below' : 'above'} $prevMonthName',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
