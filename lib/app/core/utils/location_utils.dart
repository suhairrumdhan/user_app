import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:user_application/features/pharmacy/models/pharmacy_model.dart';

class LocationUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<LatLng?> getCurrentPosition(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (context.mounted) {
        await LocationDialog.showServiceDisabledDialog(context);
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          await LocationDialog.showPermissionDialog(context);
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await LocationDialog.showPermissionDialog(context);
      }
      return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
          '📍 Current position: ${position.latitude}, ${position.longitude}');
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // دالة مساعدة لاستخراج الإحداثيات من أي هيكل بيانات
  static Map<String, double> _extractCoordinates(Map<String, dynamic> data) {
    double latitude = 0.0;
    double longitude = 0.0;

    // طريقة 1: إذا كان location موجوداً كـ Map
    if (data.containsKey('location') && data['location'] != null) {
      final locationData = data['location'];

      if (locationData is Map) {
        // location: {latitude: xxx, longitude: xxx}
        latitude = _parseDouble(locationData['latitude']);
        longitude = _parseDouble(locationData['longitude']);
        debugPrint(
            '📍 Extracted from location map: lat=$latitude, lng=$longitude');
      }
      else if (locationData is GeoPoint) {
        // location: GeoPoint
        latitude = locationData.latitude;
        longitude = locationData.longitude;
        debugPrint('📍 Extracted from GeoPoint: lat=$latitude, lng=$longitude');
      }
    }
    // طريقة 2: إذا كان هناك حقول latitude و longitude منفصلة
    else if (data.containsKey('latitude') && data.containsKey('longitude')) {
      latitude = _parseDouble(data['latitude']);
      longitude = _parseDouble(data['longitude']);
      debugPrint(
          '📍 Extracted from separate fields: lat=$latitude, lng=$longitude');
    }
    // طريقة 3: إذا كان هناك حقل geoPoint
    else if (data.containsKey('geoPoint') && data['geoPoint'] != null) {
      final geoPoint = data['geoPoint'];
      if (geoPoint is GeoPoint) {
        latitude = geoPoint.latitude;
        longitude = geoPoint.longitude;
        debugPrint('📍 Extracted from geoPoint: lat=$latitude, lng=$longitude');
      }
    }

    return {'latitude': latitude, 'longitude': longitude};
  }

  // دالة مساعدة لتحويل القيم إلى double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // جلب كل الصيدليات من Firebase
  static Future<List<PharmacyModel>> fetchAllPharmacies() async {
    try {
      final snapshot = await _firestore.collection('pharmacies').get();
      debugPrint('📦 Total pharmacies in Firebase: ${snapshot.docs.length}');

      final pharmacies = <PharmacyModel>[];

      for (final doc in snapshot.docs) {
        final pharmacy = await getPharmacyWithBusinessHours(doc);

        debugPrint(
          '🏪 Pharmacy: ${pharmacy.displayName}, '
              'Lat: ${pharmacy.latitude}, '
              'Lng: ${pharmacy.longitude}',
        );

        if (pharmacy.latitude != null &&
            pharmacy.longitude != null &&
            pharmacy.latitude != 0.0 &&
            pharmacy.longitude != 0.0) {
          pharmacies.add(pharmacy);
        } else {
          debugPrint(
            '⚠️ Skipping pharmacy: ${pharmacy
                .displayName} - invalid coordinates',
          );
        }
      }

      debugPrint('✅ Valid pharmacies with coordinates: ${pharmacies.length}');
      return pharmacies;
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
      return [];
    }
  }
  static Future<PharmacyModel> getPharmacyWithBusinessHours(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final hoursDoc = await _firestore
        .collection('pharmacies')
        .doc(doc.id)
        .collection('settings')
        .doc('businessHours')
        .get();

    final businessHours = hoursDoc.data();

    return PharmacyModel.fromFirestore(
      doc,
      workingHours: businessHours,
    );
  }
  // حساب المسافة بين نقطتين بالمتر
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end);
  }

  // جلب الصيدليات القريبة
  static Future<List<PharmacyModel>> getNearbyPharmacies({
    required LatLng currentPosition,
    double radiusInKm = 4,
  }) async {
    debugPrint('🔍 Getting nearby pharmacies within $radiusInKm km');
    debugPrint(
      '📍 Current position: ${currentPosition.latitude}, ${currentPosition
          .longitude}',
    );

    final allPharmacies = await fetchAllPharmacies();
    final nearby = <PharmacyModel>[];

    if (allPharmacies.isEmpty) {
      debugPrint('⚠️ No pharmacies found in database');
      return [];
    }

    for (final pharmacy in allPharmacies) {
      final lat = pharmacy.latitude;
      final lng = pharmacy.longitude;

      if (lat == null || lng == null) {
        debugPrint('⚠️ Skipping ${pharmacy.displayName} - missing coordinates');
        continue;
      }

      final pharmacyPosition = LatLng(lat, lng);
      final distanceMeters = calculateDistance(
          currentPosition, pharmacyPosition);
      final distanceKm = distanceMeters / 1000;

      debugPrint(
        '📏 Distance to ${pharmacy.displayName}: ${distanceKm.toStringAsFixed(
            2)} km',
      );

      if (distanceMeters <= radiusInKm * 1000) {
        nearby.add(
          pharmacy.copyWith(distance: distanceMeters),
        );
        debugPrint(
          '✅ Added ${pharmacy.displayName} to nearby list (${distanceKm
              .toStringAsFixed(2)} km)',
        );
      } else {
        debugPrint(
          '❌ ${pharmacy.displayName} is too far (${distanceKm.toStringAsFixed(
              2)} km > $radiusInKm km)',
        );
      }
    }

    nearby.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

    debugPrint('🎯 Total nearby pharmacies found: ${nearby.length}');
    if (nearby.isNotEmpty) {
      debugPrint(
        '📋 Nearest pharmacy: ${nearby.first.displayName} '
            'at ${((nearby.first.distance ?? 0) / 1000).toStringAsFixed(2)} km',
      );
    }

    return nearby;
  }
}
class LocationDialog {
  static Future<void> showPermissionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("📍 نحتاج الوصول للموقع"),
        content: const Text(
          "التطبيق يحتاج الموقع لعرض أقرب الصيدليات إليك.\n\n"
              "يرجى تفعيل إذن الموقع.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text("فتح الإعدادات"),
          ),
        ],
      ),
    );
  }

  static Future<void> showServiceDisabledDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("⚠️ GPS غير مفعل"),
        content: const Text("يرجى تشغيل خدمة الموقع (GPS)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text("تشغيل GPS"),
          ),
        ],
      ),
    );
  }
}