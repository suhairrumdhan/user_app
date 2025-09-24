// location_utils.dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationUtils {
  // Check and request location permissions
  static Future<LocationPermission> checkAndRequestLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمة تحديد الموقع غير مفعلة');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض صلاحيات الموقع');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('صلاحيات الموقع مرفوضة بشكل دائم');
    }

    return permission;
  }

  // Get current position
  static Future<LatLng> getCurrentPosition() async {
    await checkAndRequestLocationPermissions();

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  // Generate nearby pharmacies around a given position
  static List<LatLng> generateNearbyPharmacies(LatLng position, {int count = 3}) {
    final pharmacies = <LatLng>[];

    for (int i = 0; i < count; i++) {
      // Generate random offsets within a reasonable distance
      final latOffset = (0.001 + (i * 0.002)) * (i.isEven ? 1 : -1);
      final lngOffset = (0.001 + (i * 0.002)) * (i.isOdd ? 1 : -1);

      pharmacies.add(LatLng(
        position.latitude + latOffset,
        position.longitude + lngOffset,
      ));
    }

    return pharmacies;
  }

  // Calculate distance between two points in meters
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end);
  }

  // Sort pharmacies by distance from current position
  static List<LatLng> sortPharmaciesByDistance(LatLng currentPosition, List<LatLng> pharmacies) {
    pharmacies.sort((a, b) {
      final distanceA = calculateDistance(currentPosition, a);
      final distanceB = calculateDistance(currentPosition, b);
      return distanceA.compareTo(distanceB);
    });

    return pharmacies;
  }
}