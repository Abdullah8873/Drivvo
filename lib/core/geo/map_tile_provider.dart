import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `TileProvider` every `TileLayer` in the app should use — a single
/// override point so widget tests can swap out real network tile fetches
/// (My places map, the location picker) for [NoNetworkTileProvider] without
/// touching each screen. Production code never overrides this; it stays the
/// default `NetworkTileProvider`.
final mapTileProviderProvider = Provider<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// A `TileProvider` that never makes a network request: every tile resolves
/// instantly to a 1×1 transparent PNG (flutter_map ships the bytes for this
/// exact purpose, see [TileProvider.transparentImage]). Widget tests
/// override [mapTileProviderProvider] with this so pumping a map screen
/// doesn't hang on — or flake because of — real HTTP calls.
class NoNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}
