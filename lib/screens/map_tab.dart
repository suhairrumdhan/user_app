import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';

class MapTab extends StatelessWidget {
  final LatLng? currentPosition;
  final List<Map<String, dynamic>> pharmacies; // الصيدليات القريبة
  final List<Map<String, dynamic>> allPharmacies; // جميع الصيدليات
  final VoidCallback onRefresh;

  const MapTab({
    super.key,
    this.currentPosition,
    required this.pharmacies,
    required this.allPharmacies,
    required this.onRefresh,
  });

  // دالة مساعدة لاستخراج الإحداثيات من الـ location Map
  LatLng? _getPharmacyLocation(Map<String, dynamic> pharmacy) {
    // 🔥 استخدام الـ location Map مباشرة
    final location = pharmacy['location'];

    if (location != null && location is Map) {
      final lat = _parseDouble(location['latitude']);
      final lng = _parseDouble(location['longitude']);

      if (lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }

    // كـ fallback إذا لم يوجد location Map
    final lat = _parseDouble(pharmacy['latitude']);
    final lng = _parseDouble(pharmacy['longitude']);

    if (lat != 0.0 && lng != 0.0) {
      return LatLng(lat, lng);
    }

    return null;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // دالة مساعدة لحساب المسافة بشكل آمن
  String? _getFormattedDistance(Map<String, dynamic> pharmacy) {
    final distance = pharmacy['distance'];
    if (distance == null) return null;

    try {
      final distanceInKm = (distance / 1000);
      return '${distanceInKm.toStringAsFixed(1)}كم';
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🔥 إنشاء مجموعة من IDs الصيدليات القريبة للتمييز
    final nearbyIds = pharmacies.map((p) => p['id']).toSet();

    // 🔥 إنشاء قائمة الـ Markers
    final List<Marker> markers = [];

    // 🔥 إضافة marker موقع المستخدم - علامة موقع
    markers.add(
      Marker(
        point: currentPosition!,
        width: 50,
        height: 50,
        child: const Icon(
          Iconsax.location, // علامة موقع بسيطة
          color: Colors.blue,
          size: 40,
        ),
      ),
    );

    // 🔥 إضافة markers الصيدليات
    for (var pharmacy in allPharmacies) {
      final point = _getPharmacyLocation(pharmacy);
      if (point == null) continue; // تخطي إذا كان الموقع غير صالح

      final name = pharmacy['pharmacyName'] ?? pharmacy['name'] ?? 'صيدلية';
      final isNearby = nearbyIds.contains(pharmacy['id']);
      final isOpen247 = pharmacy['is24Hours'] == true; // إذا كانت الصيدلية تعمل 24 ساعة
      final distanceText = isNearby ? _getFormattedDistance(pharmacy) : null;

      markers.add(
        Marker(
          point: point,
          width: isNearby ? 45 : 40,
          height: isNearby ? 45 : 40,
          child: Tooltip(
            message: isNearby && distanceText != null
                ? '$name (قريبة - $distanceText)'
                : name,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main pharmacy icon
                Icon(
                  isOpen247 ? Iconsax.health : Iconsax.hospital,
                  color: isNearby
                      ? Colors.red // الصيدليات القريبة باللون الأحمر
                      : (isOpen247 ? Colors.orange : Colors.grey),
                  size: isNearby ? 35 : 30,
                ),

                // 24/7 badge for pharmacies that are open all day
                if (isOpen247 && !isNearby)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Iconsax.clock,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),

                // Distance indicator for nearby pharmacies
                if (isNearby && distanceText != null)
                  Positioned(
                    bottom: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Iconsax.location,
                            color: Colors.white,
                            size: 8,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            distanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        /// 🗺️ الخريطة
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FlutterMap(
            options: MapOptions(
              center: currentPosition!,
              zoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_application',
              ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
        ),

        /// 🔥 زر التحديث
        Positioned(
          top: 15,
          right: 15,
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: InkWell(
              onTap: onRefresh,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Iconsax.refresh_circle,
                  color: Color(0xFF4FC3F7),
                  size: 24,
                ),
              ),
            ),
          ),
        ),

        /// 🔥 مؤشر عدد الصيدليات
        Positioned(
          top: 15,
          left: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Iconsax.hospital,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${allPharmacies.length} صيدلية',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}