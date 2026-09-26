import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/vehicles/vehicle_labels.dart';
import '../../features/vehicles/vehicle_picker_screen.dart';
import '../db/app_database.dart';
import '../../features/sharing/account_switcher.dart';
import '../providers.dart';
import '../sharing/active_account.dart';
import '../theme/app_theme.dart';
import 'vehicle_switcher.dart';

/// App bar shared by the main tabs: vehicle switcher on the left, tab
/// specific actions (export, search, share…) on the right.
///
/// A ConsumerWidget (reads providers) that also implements
/// `PreferredSizeWidget`, which `Scaffold.appBar` requires.
class MainTabAppBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentVehicleProvider);
    final Widget title;
    if (!current.hasValue) {
      // Still loading from the database: keep the bar empty, no flicker.
      title = const SizedBox.shrink();
    } else if (current.value case final vehicle?) {
      title = _CurrentVehicleChip(vehicle: vehicle);
    } else {
      final account = ref.watch(activeAccountProvider);
      title = account != null
          ? VehicleSwitcher(
              name: 'No vehicles',
              subtitle: accountLabel(account),
            )
          : VehicleSwitcher(
              name: 'Add a vehicle',
              onTap: () => context.push('/vehicles/new'),
            );
    }
    return AppBar(
      backgroundColor: color,
      toolbarHeight: kToolbarHeight + 8,
      titleSpacing: 12,
      title: title,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Chip for the selected vehicle: "name" over "model · 56935 km".
class _CurrentVehicleChip extends ConsumerWidget {
  const _CurrentVehicleChip({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final odometer = ref.watch(lastOdometerProvider(vehicle.id)).value;
    final fmt = ref.watch(formattersProvider);
    // In a shared account the chip says whose data this is.
    final account = ref.watch(activeAccountProvider);
    final subtitle = account != null
        ? accountLabel(account)
        : [
            if (vehicle.model case final m? when m.isNotEmpty) m,
            if (odometer != null) fmt.distance(odometer, vehicle.distanceUnit),
          ].join(' · ');
    return VehicleSwitcher(
      name: vehicle.name,
      subtitle: subtitle,
      icon: vehicle.type.icon,
      onTap: () => openVehiclePicker(context),
    );
  }
}
