import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/calc/access_profile.dart';
import '../../core/sharing/active_account.dart';
import '../../core/widgets/max_width_body.dart';
import 'vehicle_widgets.dart';

/// More → Vehicles: every non-deleted vehicle (active first). Tap to edit,
/// + to add.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `vehiclesProvider` streams the table, so the list refreshes by itself
    // after a create/edit/delete (like a live query subscription).
    final vehicles = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      body: vehicles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load vehicles: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'No vehicles yet. Tap + to add one.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : MaxWidthBody(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(indent: 72),
                  itemBuilder: (context, i) => VehicleTile(
                    vehicle: list[i],
                    onTap: () => context.push('/vehicles/${list[i].id}'),
                  ),
                ),
              ),
      ),
      floatingActionButton:
          ref
              .watch(currentAccessProvider)
              .can(AccessArea.vehicles, AccessAction.register)
          ? FloatingActionButton(
              tooltip: 'Add vehicle',
              shape: const CircleBorder(),
              onPressed: () => context.push('/vehicles/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
