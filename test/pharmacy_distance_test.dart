import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/search/services/pharmacy_distance.dart';

void main() {
  test(
    'unrounded WGS-84 distance is within 10 m of independent references',
    () {
      // Equatorial arc: a * delta-longitude (WGS-84 a = 6378137 m).
      const equatorialReferenceMeters = 1113.1949079327358;
      final equatorKm = PharmacyDistance.betweenKm(
        userLat: 0,
        userLng: 0,
        pharmacyLat: 0,
        pharmacyLng: 0.01,
      );
      expect(equatorKm, isNotNull);
      expect(
        (equatorKm! * 1000 - equatorialReferenceMeters).abs(),
        lessThanOrEqualTo(10),
      );

      // WGS-84 meridian: independent Simpson integration of
      // a(1-e²)/(1-e² sin²(latitude))^(3/2), 32.8872° to 32.8972°.
      const tripoliReferenceMeters = 1109.0254075994483;
      final tripoliKm = PharmacyDistance.betweenKm(
        userLat: 32.8872,
        userLng: 13.1913,
        pharmacyLat: 32.8972,
        pharmacyLng: 13.1913,
      );
      expect(tripoliKm, isNotNull);
      expect(
        (tripoliKm! * 1000 - tripoliReferenceMeters).abs(),
        lessThanOrEqualTo(10),
      );

      // A second meridian fixture close to the default 4 km search radius.
      const radiusEdgeReferenceMeters = 3881.596698458054;
      final radiusEdgeKm = PharmacyDistance.betweenKm(
        userLat: 32.8872,
        userLng: 13.1913,
        pharmacyLat: 32.9222,
        pharmacyLng: 13.1913,
      );
      expect(radiusEdgeKm, isNotNull);
      expect(
        (radiusEdgeKm! * 1000 - radiusEdgeReferenceMeters).abs(),
        lessThanOrEqualTo(10),
      );
    },
  );

  test('invalid or missing coordinates have unknown distance', () {
    double? distance(
      double? userLat,
      double? userLng,
      double? pharmacyLat,
      double? pharmacyLng,
    ) => PharmacyDistance.betweenKm(
      userLat: userLat,
      userLng: userLng,
      pharmacyLat: pharmacyLat,
      pharmacyLng: pharmacyLng,
    );

    expect(distance(null, 13, 32, 13), isNull);
    expect(distance(91, 13, 32, 13), isNull);
    expect(distance(32, 181, 32, 13), isNull);
    expect(distance(double.nan, 13, 32, 13), isNull);
    expect(distance(32, 13, 0, 0), isNull);
    expect(distance(32, 13, 32, 13), 0);
  });
}
