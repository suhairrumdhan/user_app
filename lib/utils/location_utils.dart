import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<LatLng> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('خدمة تحديد الموقع غير مفعلة');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('تم رفض صلاحيات الموقع');
    }
    if (permission == LocationPermission.deniedForever) throw Exception('صلاحيات الموقع مرفوضة بشكل دائم');

    // إنشاء stream للحصول على الموقع بدقة عالية
    Position? lastPosition;
    final completer = Completer<LatLng>();

    final subscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // أعلى دقة ممكنة
        distanceFilter: 0, // التحديث لكل تغيير
      ),
    ).listen((Position position) {
      lastPosition = position;
      // نوقف الاستماع بعد أول تحديث دقيق
      completer.complete(LatLng(position.latitude, position.longitude));
    });

    final result = await completer.future;
    await subscription.cancel(); // نوقف الاستماع بعد الحصول على الموقع
    return result;
  }

  // جلب كل الصيدليات من Firebase
  static Future<List<Map<String, dynamic>>> fetchAllPharmacies() async {
    final snapshot = await _firestore.collection('pharmacies').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'address': data['address'] ?? '',
        'latitude': double.tryParse(data['latitude'].toString()) ?? 0.0,
        'longitude': double.tryParse(data['longitude'].toString()) ?? 0.0,
        'imageUrl': data['imageUrl'] ?? '',
        'isOnline': data['isOnline'] ?? false,
      };
    }).toList(); // فقط الصيدليات الفعالة
  }

  // حساب المسافة بين نقطتين بالمتر
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end);
  }

  // جلب الصيدليات القريبة (مثلاً ضمن 5 كم)
  static Future<List<Map<String, dynamic>>> getNearbyPharmacies({
    required LatLng currentPosition,
    double radiusInKm = 10,
  }) async {
    final allPharmacies = await fetchAllPharmacies();
    List<Map<String, dynamic>> nearby = [];

    for (var pharmacy in allPharmacies) {
      final pos = LatLng(pharmacy['latitude'], pharmacy['longitude']);
      final distanceMeters = calculateDistance(currentPosition, pos);
      if (distanceMeters <= radiusInKm * 1000) {
        pharmacy['distance'] = distanceMeters;
        nearby.add(pharmacy);
      }
    }

    nearby.sort((a, b) => a['distance'].compareTo(b['distance']));
    return nearby;
  }
}
