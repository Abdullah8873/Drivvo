import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo/current_location.dart';
import '../../core/geo/map_tile_provider.dart';

const _userAgentPackageName = 'com.abdullah8873.motolog';

/// Full-screen "pick a point on the map" used by the place / gas station
/// form's Location field. Tap anywhere to drop (or move) the pin; the ✓ app
/// bar action confirms and pops with the picked [LatLng]; a "my location"
/// FAB centers on and drops the pin at the device's current position.
///
/// Push it and await the result:
/// `final picked = await Navigator.push<LatLng>(...);`
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  /// Starting pin position, if the field already had one.
  final LatLng? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _mapController = MapController();
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

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
    setState(() => _picked = point);
    _mapController.move(point, 15);
  }

  void _confirm() {
    final picked = _picked;
    if (picked != null) Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
        actions: [
          IconButton(
            tooltip: 'Confirm',
            icon: const Icon(Icons.check),
            onPressed: _picked == null ? null : _confirm,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initial ?? const LatLng(20, 0),
              initialZoom: initial == null ? 2 : 15,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: _userAgentPackageName,
                tileProvider: ref.watch(mapTileProviderProvider),
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_pin,
                        size: 36,
                        color: Colors.red,
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
              heroTag: 'location-picker-my-location',
              tooltip: 'My location',
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
