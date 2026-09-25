import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/db/app_database.dart';
import '../../core/geo/current_location.dart';
import '../../core/geo/map_tile_provider.dart';
import '../catalog/catalog_item_form_screen.dart';
import '../catalog/catalog_labels.dart';
import 'places_providers.dart';

/// The Android/iOS app id, used as flutter_map's `userAgentPackageName` (the
/// OSM tile usage policy asks for a way to identify the requesting app).
const _userAgentPackageName = 'com.abdullah8873.motolog';

/// My places → MAP: every located place/gas station as a marker; tapping one
/// shows a bottom card with an Edit button. The camera starts fitted to
/// every marker (or a zoomed-out world view when none have coordinates).
class PlacesMapTab extends ConsumerStatefulWidget {
  const PlacesMapTab({super.key});

  @override
  ConsumerState<PlacesMapTab> createState() => _PlacesMapTabState();
}

class _PlacesMapTabState extends ConsumerState<PlacesMapTab> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    final point = await currentLatLng();
    if (!mounted) return;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get your location")),
      );
      return;
    }
    _mapController.move(point, 15);
  }

  void _openForm(CatalogItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogItemFormScreen(kind: item.kind, item: item),
      ),
    );
  }

  void _showItem(CatalogItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(item.kind.icon, color: item.kind.markerColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              if ((item.address ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.address!.trim()),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openForm(item);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('EDIT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(myPlacesProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (list) {
        final located = [
          for (final i in list)
            if (i.latitude != null && i.longitude != null) i,
        ];
        final points = [
          for (final i in located) LatLng(i.latitude!, i.longitude!),
        ];
        final MapOptions options;
        if (points.isEmpty) {
          // Nothing to fit: a zoomed-out view of the world.
          options = const MapOptions(
            initialCenter: LatLng(20, 0),
            initialZoom: 2,
          );
        } else if (points.length == 1) {
          // `CameraFit.coordinates` needs a non-zero-area bounds.
          options = MapOptions(initialCenter: points.first, initialZoom: 15);
        } else {
          options = MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(48),
            ),
          );
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: options,
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: _userAgentPackageName,
                  tileProvider: ref.watch(mapTileProviderProvider),
                ),
                MarkerLayer(
                  markers: [
                    for (final item in located)
                      Marker(
                        point: LatLng(item.latitude!, item.longitude!),
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _showItem(item),
                          child: Icon(
                            item.kind.icon,
                            size: 34,
                            color: item.kind.markerColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'places-map-my-location',
                tooltip: 'My location',
                onPressed: _goToMyLocation,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        );
      },
    );
  }
}
