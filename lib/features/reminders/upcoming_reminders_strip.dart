import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/calc/reminder_math.dart';
import '../../core/theme/record_module.dart';
import 'reminder_providers.dart';

/// Color of the "in 197 km · in 9 days" line: red when overdue, amber
/// otherwise (grey for reminders that are comfortably far away).
Color remainingColor(ReminderStatus status, {bool amberWhenOk = false}) =>
    switch (status) {
      ReminderStatus.overdue => Colors.red.shade700,
      ReminderStatus.soon => Colors.amber.shade800,
      ReminderStatus.ok =>
        amberWhenOk ? Colors.amber.shade800 : Colors.grey.shade700,
    };

/// Opens the record behind an item: the reminder's edit form, or a new
/// refueling for the "Next refueling" prediction.
void openUpcoming(BuildContext context, UpcomingReminder item) {
  if (item.reminderId != null) {
    context.push('/edit/${RecordModule.reminder.name}/${item.reminderId}');
  } else if (item.module == RecordModule.refueling) {
    context.push('/add/${RecordModule.refueling.name}');
  }
}

/// Drivvo's horizontally scrolling "REMINDERS" strip at the top of History:
/// "Next refueling" prediction first, then the most urgent reminders.
/// Renders nothing when there is nothing to show.
///
/// Drop it into a scrolling list: `UpcomingRemindersStrip(vehicleId: id)`.
class UpcomingRemindersStrip extends ConsumerWidget {
  const UpcomingRemindersStrip({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` keeps showing the previous list while a refresh is loading,
    // so the strip doesn't flicker when records change.
    final items = ref.watch(upcomingRemindersProvider(vehicleId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'REMINDERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _StripCard(item: items[i]),
          ),
        ),
      ],
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({required this.item});

  final UpcomingReminder item;

  @override
  Widget build(BuildContext context) {
    final color = item.module.color;
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openUpcoming(context, item),
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Icon(item.module.icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.dueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.remainingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: remainingColor(item.status, amberWhenOk: true),
                      ),
                    ),
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
