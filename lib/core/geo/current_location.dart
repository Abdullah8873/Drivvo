import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Requests (asking for permission if needed) and returns the device's
/// current location, or `null` if anything stops that — location services
/// off, permission denied, a plugin/platform error, geolocator not wired up
/// on this platform, etc.
///
/// Deliberately swallows every failure instead of throwing: this is called
/// from a "my location" button tap (My places map, the location picker), and
/// the caller's job is just to show a SnackBar and otherwise carry on — not
/// to crash the screen.
Future<LatLng?> currentLatLng() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}
