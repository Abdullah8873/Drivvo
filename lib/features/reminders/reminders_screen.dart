import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/reminder_math.dart';
import '../../core/providers.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/main_tab_app_bar.dart';
import 'reminder_providers.dart';
import 'upcoming_reminders_strip.dart';

/// Reminders tab (purple, like the Reminder module): one card per reminder
/// of the current vehicle with its due point, what's left and a progress
/// bar, most urgent first. Tap a card to edit it.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(currentVehicleProvider);
    final vehicle = vehicleAsync.value;
    final itemsAsync = vehicle == null
        ? null
        : ref.watch(reminderItemsProvider(vehicle.id));
    // `.value` keeps the previous list while a refresh is loading.
    final items = vehicle == null
        ? (vehicleAsync.isLoading ? null : const <UpcomingReminder>[])
        : itemsAsync!.value;

    return Scaffold(
      appBar: MainTabAppBar(color: RecordModule.reminder.color),
      body: switch (items) {
        null when itemsAsync?.hasError ?? false => Center(
          child: Text('Could not load reminders\n${itemsAsync!.error}'),
        ),
        null => const Center(child: CircularProgressIndicator()),
        [] => const _EmptyState(),
        _ => ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => ReminderCard(item: items[i]),
        ),
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm, size: 120, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Add your first reminder',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// One reminder in the Reminders tab.
class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.item});

  final UpcomingReminder item;

  @override
  Widget build(BuildContext context) {
    final color = item.module.color;
    final statusColor = remainingColor(item.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openUpcoming(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Icon(item.module.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.dueText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.dueText,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    if (item.remainingText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.remainingText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: item.status == ReminderStatus.ok
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                    if (item.progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 3,
                          color: item.status == ReminderStatus.ok
                              ? RecordModule.reminder.color
                              : statusColor,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
