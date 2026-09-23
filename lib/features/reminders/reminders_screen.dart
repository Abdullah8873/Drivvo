import 'package:flutter/material.dart';

import '../../core/theme/record_module.dart';
import '../../core/widgets/main_tab_app_bar.dart';

/// Reminders tab (purple, like the Reminder module). Milestone 3 lists
/// reminders with remaining km/days and progress.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainTabAppBar(color: RecordModule.reminder.color),
      body: Center(
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
      ),
    );
  }
}
