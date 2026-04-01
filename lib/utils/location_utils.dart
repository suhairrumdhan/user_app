import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/material.dart';

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
      debugPrint('📍 Current position: ${position.latitude}, ${position.longitude}');
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
        debugPrint('📍 Extracted from location map: lat=$latitude, lng=$longitude');
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
      debugPrint('📍 Extracted from separate fields: lat=$latitude, lng=$longitude');
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
  static Future<List<Map<String, dynamic>>> fetchAllPharmacies() async {
    try {
      final snapshot = await _firestore.collection('pharmacies').get();
      debugPrint('📦 Total pharmacies in Firebase: ${snapshot.docs.length}');

      final pharmacies = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // استخراج الإحداثيات
        final coordinates = _extractCoordinates(data);
        final latitude = coordinates['latitude']!;
        final longitude = coordinates['longitude']!;

        // اسم الصيدلية
        final pharmacyName = data['pharmacyName'] ?? data['name'] ?? 'صيدلية بدون اسم';

        debugPrint('🏪 Pharmacy: $pharmacyName, Lat: $latitude, Lng: $longitude');

        // إضافة الصيدلية فقط إذا كانت الإحداثيات صالحة
        if (latitude != 0.0 && longitude != 0.0) {
          pharmacies.add({
            'id': doc.id,
            'pharmacyName': pharmacyName,
            'name': pharmacyName, // للحفاظ على التوافق
            'address': data['address'] ?? 'العنوان غير متوفر',
            'latitude': latitude,
            'longitude': longitude,
            'imageUrl': data['imageUrl'] ?? '',
            'isOnline': data['isOnline'] ?? false,
            'location': data['location'], // الاحتفاظ بالبيانات الأصلية
          });
        } else {
          debugPrint('⚠️ Skipping pharmacy: $pharmacyName - invalid coordinates');
        }
      }

      debugPrint('✅ Valid pharmacies with coordinates: ${pharmacies.length}');
      return pharmacies;

    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
      return [];
    }
  }

  // حساب المسافة بين نقطتين بالمتر
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end);
  }

  // جلب الصيدليات القريبة
  static Future<List<Map<String, dynamic>>> getNearbyPharmacies({
    required LatLng currentPosition,
    double radiusInKm = 4,
  }) async {
    debugPrint('🔍 Getting nearby pharmacies within $radiusInKm km');
    debugPrint('📍 Current position: ${currentPosition.latitude}, ${currentPosition.longitude}');

    final allPharmacies = await fetchAllPharmacies();
    List<Map<String, dynamic>> nearby = [];

    if (allPharmacies.isEmpty) {
      debugPrint('⚠️ No pharmacies found in database');
      return [];
    }

    for (var pharmacy in allPharmacies) {
      // الحصول على الإحداثيات من الصيدلية
      final lat = pharmacy['latitude'] as double;
      final lng = pharmacy['longitude'] as double;
      final pharmacyName = pharmacy['pharmacyName'] as String;

      debugPrint('📊 Checking pharmacy: $pharmacyName at ($lat, $lng)');

      // التحقق من صحة الإحداثيات
      if (lat == 0.0 && lng == 0.0) {
        debugPrint('⚠️ Skipping pharmacy $pharmacyName - invalid coordinates (0,0)');
        continue;
      }

      // حساب المسافة
      final pharmacyPosition = LatLng(lat, lng);
      final distanceMeters = calculateDistance(currentPosition, pharmacyPosition);
      final distanceKm = distanceMeters / 1000;

      debugPrint('📏 Distance to $pharmacyName: ${distanceKm.toStringAsFixed(2)} km');

      // التحقق إذا كانت ضمن النطاق المطلوب
      if (distanceMeters <= radiusInKm * 1000) {
        final pharmacyWithDistance = Map<String, dynamic>.from(pharmacy);
        pharmacyWithDistance['distance'] = distanceMeters;
        pharmacyWithDistance['distanceKm'] = distanceKm;
        nearby.add(pharmacyWithDistance);
        debugPrint('✅ Added $pharmacyName to nearby list (${distanceKm.toStringAsFixed(2)} km)');
      } else {
        debugPrint('❌ $pharmacyName is too far (${distanceKm.toStringAsFixed(2)} km > $radiusInKm km)');
      }
    }

    // ترتيب حسب المسافة
    nearby.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    debugPrint('🎯 Total nearby pharmacies found: ${nearby.length}');
    if (nearby.isNotEmpty) {
      debugPrint('📋 Nearest pharmacy: ${nearby.first['pharmacyName']} at ${nearby.first['distanceKm']} km');
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