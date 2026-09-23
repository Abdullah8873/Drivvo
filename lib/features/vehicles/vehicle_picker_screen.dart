import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'vehicle_labels.dart';
import 'vehicle_widgets.dart';

/// Opens the full-screen vehicle picker above the tab bar (on the root
/// navigator, so the bottom navigation is covered like a modal).
Future<void> openVehiclePicker(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const VehiclePickerScreen()));
}

/// "Select vehicle" list opened from the `VehicleSwitcher` chip: search,
/// tap a vehicle to make it current, + to add a new one.
class VehiclePickerScreen extends ConsumerStatefulWidget {
  const VehiclePickerScreen({super.key});

  @override
  ConsumerState<VehiclePickerScreen> createState() =>
      _VehiclePickerScreenState();
}

class _VehiclePickerScreenState extends ConsumerState<VehiclePickerScreen> {
  String _query = '';

  bool _matches(String? text) =>
      text != null && text.toLowerCase().contains(_query.toLowerCase());

  Future<void> _select(String id) async {
    await selectVehicle(ref, id);
    if (mounted) Navigator.pop(context);
  }

  void _addNew() {
    // Grab the router before popping: this page's context goes away.
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/vehicles/new');
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final currentId = ref.watch(currentVehicleProvider).value?.id;
    final filtered = vehicles
        .where(
          (v) =>
              _query.isEmpty ||
              _matches(v.name) ||
              _matches(vehicleDetails(v)) ||
              _matches(v.manufacturer),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select vehicle'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white70, size: 18),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(indent: 72),
        itemBuilder: (context, i) {
          final v = filtered[i];
          return VehicleTile(
            vehicle: v,
            trailing: v.id == currentId
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () => _select(v.id),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add vehicle',
        shape: const CircleBorder(),
        onPressed: _addNew,
        child: const Icon(Icons.add),
      ),
    );
  }
}
