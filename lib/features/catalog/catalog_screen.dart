import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import 'catalog_item_form_screen.dart';
import 'catalog_labels.dart';

/// One user-editable pick list (More → Fuel / Gas stations / Types of…).
/// Tap a row to edit it, long-press to delete, FAB + to add.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key, required this.kind});

  final CatalogKind kind;

  void _openForm(BuildContext context, [CatalogItem? item]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogItemFormScreen(kind: kind, item: item),
      ),
    );
  }

  /// Subtitle under the name: address for stations/places, tank kind for fuels.
  String? _subtitle(CatalogItem item) {
    if (kind.hasAddress) {
      final address = item.address?.trim() ?? '';
      return address.isEmpty ? null : address;
    }
    if (kind == CatalogKind.fuel) return item.fuelKind?.label;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // StreamProvider → AsyncValue; `.when` is like rendering
    // loading / error / data states from a React Query hook.
    final items = ref.watch(catalogProvider(kind));
    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'Nothing here yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.separated(
                // Leave room so the FAB never covers the last row.
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  final item = list[i];
                  final subtitle = _subtitle(item);
                  return ListTile(
                    leading: Icon(
                      kind.icon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(item.name),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    onTap: () => _openForm(context, item),
                    onLongPress: () =>
                        confirmDeleteCatalogItem(context, ref, item),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        tooltip: 'Add',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
