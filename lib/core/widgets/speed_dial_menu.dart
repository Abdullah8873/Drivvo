import 'package:flutter/material.dart';

import '../theme/record_module.dart';

/// The white popup card above the center "+" button listing every record
/// type (Reminder … Refueling), each with its colored round icon.
class SpeedDialMenu extends StatelessWidget {
  const SpeedDialMenu({super.key, required this.onSelected});

  final ValueChanged<RecordModule> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final module in RecordModule.speedDialOrder)
                InkWell(
                  onTap: () => onSelected(module),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 28, 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: module.color,
                          child: Icon(
                            module.icon,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          module.label,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
