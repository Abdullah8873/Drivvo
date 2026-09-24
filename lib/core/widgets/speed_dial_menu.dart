import 'package:flutter/material.dart';

import '../theme/record_module.dart';

/// Every menu item's label style — shared by [SpeedDialMenu.build] and
/// [SpeedDialMenu._menuWidth], which measures against it.
const _labelStyle = TextStyle(fontSize: 15);

/// The white popup card above the center "+" button listing every record
/// type (Reminder … Refueling), each with its colored round icon.
class SpeedDialMenu extends StatelessWidget {
  const SpeedDialMenu({super.key, required this.onSelected});

  final ValueChanged<RecordModule> onSelected;

  /// Just wide enough for an icon, the gap and the longest label — a
  /// concrete width instead of `IntrinsicWidth`, which throws when asked to
  /// measure a scrolling viewport (see [build]).
  double _menuWidth(BuildContext context) {
    var maxLabelWidth = 0.0;
    for (final module in RecordModule.speedDialOrder) {
      final painter = TextPainter(
        text: TextSpan(text: module.label, style: _labelStyle),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      if (painter.width > maxLabelWidth) maxLabelWidth = painter.width;
    }
    // Icon (32) + gap (16) + the row's left/right padding (12 + 28).
    return 32 + 16 + 12 + 28 + maxLabelWidth;
  }

  @override
  Widget build(BuildContext context) {
    // The parent (MainShell) bounds our height to the space above the FAB.
    // `shrinkWrap` hugs the item list's natural height on tall screens, and
    // caps + scrolls it on short ones instead of overflowing past the top
    // of the screen — which would leave the topmost items (e.g. Reminder)
    // unreachable.
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: _menuWidth(context),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                        child: Icon(module.icon, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Text(module.label, style: _labelStyle),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
