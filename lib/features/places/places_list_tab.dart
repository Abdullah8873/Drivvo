import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/widgets/max_width_body.dart';
import '../catalog/catalog_item_form_screen.dart';
import '../catalog/catalog_labels.dart';
import 'places_providers.dart';

/// My places → LIST: gas stations then places, each section header-led,
/// tapping a row opens the same edit form as More → Places / Gas stations.
class PlacesListTab extends ConsumerWidget {
  const PlacesListTab({super.key});

  void _openForm(BuildContext context, CatalogItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogItemFormScreen(kind: item.kind, item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myPlacesProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No places yet.\nAdd one from More → Places or Gas stations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final stations = [
          for (final i in list)
            if (i.kind == CatalogKind.gasStation) i,
        ];
        final places = [
          for (final i in list)
            if (i.kind == CatalogKind.place) i,
        ];
        // Flatten the two sections (header + rows) into one list so the
        // whole screen is one lazy ListView.builder, same trick as History.
        final rows = <Widget Function()>[
          if (stations.isNotEmpty) ...[
            () => const _SectionHeader('Gas stations'),
            for (final s in stations)
              () => _PlaceTile(item: s, onTap: () => _openForm(context, s)),
          ],
          if (places.isNotEmpty) ...[
            () => const _SectionHeader('Places'),
            for (final p in places)
              () => _PlaceTile(item: p, onTap: () => _openForm(context, p)),
          ],
        ];
        return MaxWidthBody(
          maxWidth: 840,
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i](),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.item, required this.onTap});

  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = item.address?.trim() ?? '';
    final hasLocation = item.latitude != null && item.longitude != null;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(item.kind.icon, color: item.kind.markerColor),
      title: Text(item.name),
      subtitle: address.isEmpty && hasLocation
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty) Text(address),
                if (!hasLocation)
                  Text(
                    'No location',
                    style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
      onTap: onTap,
    );
  }
}
