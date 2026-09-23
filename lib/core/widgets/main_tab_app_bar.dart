import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'vehicle_switcher.dart';

/// App bar shared by the main tabs: vehicle switcher on the left, tab
/// specific actions (export, search, share…) on the right.
class MainTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainTabAppBar({
    super.key,
    this.actions = const [],
    this.color = AppTheme.primary,
    this.bottom,
  });

  final List<Widget> actions;
  final Color color;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + 8 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: color,
      toolbarHeight: kToolbarHeight + 8,
      titleSpacing: 12,
      // TODO(milestone-2): read the selected vehicle from the database.
      title: const VehicleSwitcher(
        name: 'My Vehicle',
        subtitle: 'No records yet',
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
