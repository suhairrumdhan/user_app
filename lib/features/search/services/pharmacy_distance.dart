import 'package:latlong2/latlong.dart';

/// Straight-line distance over the WGS-84 ellipsoid, not driving distance.
/// Keep the unrounded value for filtering and sorting; round only in the UI.
class PharmacyDistance {
  const PharmacyDistance._();

  static double? betweenKm({
    required double? userLat,
    required double? userLng,
    required double? pharmacyLat,
    required double? pharmacyLng,
  }) {
    if (!_validPoint(userLat, userLng) ||
        !_validPoint(pharmacyLat, pharmacyLng)) {
      return null;
    }

    // Existing pharmacy records use (0, 0) as a missing-location sentinel.
    if (pharmacyLat == 0 && pharmacyLng == 0) return null;

    try {
      final meters = const Vincenty().distance(
        LatLng(userLat!, userLng!),
        LatLng(pharmacyLat!, pharmacyLng!),
      );
      return meters.isFinite && meters >= 0 ? meters / 1000 : null;
    } on StateError {
      // Vincenty's inverse formula may not converge near antipodal points.
      // Never show an inaccurate distance as if it were a measured result.
      return null;
    }
  }

  static bool _validPoint(double? lat, double? lng) =>
      lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}
