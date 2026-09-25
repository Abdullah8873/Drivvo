import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../achievements/achievements_providers.dart';
import '../reminders/upcoming_reminders_strip.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/widgets/main_tab_app_bar.dart';
import 'achievement_timeline.dart';
import 'history_calc.dart';
import 'history_providers.dart';
import 'history_search_screen.dart';
import 'month_costs_screen.dart';
import 'widgets/timeline_widgets.dart';

/// Home tab: timeline of every record for the selected vehicle, grouped by
/// month (newest first) with a summary card opening each month.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(currentVehicleProvider);
    final vehicle = vehicleAsync.value;

    return Scaffold(
      appBar: MainTabAppBar(
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.download),
            onPressed: () => context.push('/export'),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: vehicle == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HistorySearchScreen(
                        vehicleId: vehicle.id,
                        distanceUnit: vehicle.distanceUnit,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: vehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (vehicle) => vehicle == null
            ? _EmptyState(
                icon: Icons.two_wheeler,
                message: 'No vehicle yet',
                // No "+" icon here: the bottom bar's FAB already uses it.
                action: FilledButton(
                  onPressed: () => context.push('/vehicles/new'),
                  child: const Text('Add your first vehicle'),
                ),
              )
            : _Timeline(vehicle: vehicle),
      ),
    );
  }
}

/// The scrolling timeline of one vehicle. Stateful only to remember which
/// row is expanded (≈ `useState(expandedId)`).
class _Timeline extends ConsumerStatefulWidget {
  const _Timeline({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final timeline = ref.watch(timelineProvider(vehicle.id));
    // Earned achievements are merged into the display list below, purely as
    // presentation — they never enter `MonthSummary` (totals/reports), see
    // `achievement_timeline.dart`.
    final achievements = ref.watch(earnedAchievementsProvider(vehicle.id));

    return timeline.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (records) {
        if (records.isEmpty) {
          return Column(
            children: [
              _UpcomingRemindersSlot(vehicleId: vehicle.id),
              const Expanded(
                child: _EmptyState(
                  icon: Icons.format_list_bulleted,
                  message: 'Tap + to add your first record',
                ),
              ),
            ],
          );
        }

        // Flatten months + records into one list for a lazy ListView
        // (like rendering a virtualized list of mixed items).
        final items = <Widget Function()>[
          () => _UpcomingRemindersSlot(vehicleId: vehicle.id),
          for (final month in groupByMonth(records)) ...[
            () => MonthSummaryCard(
              summary: month,
              vehicle: vehicle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MonthCostsScreen(
                    vehicleId: vehicle.id,
                    month: month.month,
                  ),
                ),
              ),
            ),
            for (final item in mergeAchievements(month, achievements))
              switch (item) {
                RecordItem(:final record) => () => TimelineRow(
                  key: ValueKey(record.id),
                  record: record,
                  distanceUnit: vehicle.distanceUnit,
                  expanded: _expandedId == record.id,
                  onTap: () => setState(
                    () => _expandedId = _expandedId == record.id
                        ? null
                        : record.id,
                  ),
                ),
                AchievementItem(:final achievement) =>
                  () => AchievementTimelineRow(
                    key: Key('achievement-row-${achievement.id}'),
                    achievement: achievement,
                  ),
              },
          ],
        ];
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: items.length,
          itemBuilder: (context, i) => items[i](),
        );
      },
    );
  }
}

/// Slot for the "Next refueling / upcoming reminders" strip at the top of
/// the timeline.
class _UpcomingRemindersSlot extends StatelessWidget {
  const _UpcomingRemindersSlot({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    // "Next refueling" prediction + due reminders (renders nothing if none).
    return UpcomingRemindersStrip(vehicleId: vehicleId);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 96, color: onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
