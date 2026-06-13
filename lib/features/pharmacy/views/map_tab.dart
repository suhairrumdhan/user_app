import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';

import '../models/pharmacy_model.dart';
import 'package:url_launcher/url_launcher.dart';

class MapTab extends StatelessWidget {
  final LatLng? currentPosition;
  final List<PharmacyModel> pharmacies;
  final List<PharmacyModel> allPharmacies;
  final VoidCallback onRefresh;
  final double selectedDistance;
  final MapController mapController;

  const MapTab({
    super.key,
    this.currentPosition,
    required this.pharmacies,
    required this.allPharmacies,
    required this.onRefresh,
    required this.selectedDistance,
    required this.mapController,
  });

  LatLng? _getPharmacyLocation(PharmacyModel pharmacy) {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;

    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      return LatLng(lat, lng);
    }

    return null;
  }

  String? _getFormattedDistance(PharmacyModel pharmacy) {
    final distance = pharmacy.distance;
    if (distance == null) return null;

    final km = distance / 1000;
    return '${km.toStringAsFixed(1)} كم';
  }

  Future<void> _openInGoogleMaps(PharmacyModel pharmacy) async {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;

    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }
  bool _isPharmacyOpen(PharmacyModel pharmacy) {
    if (pharmacy.is24Hours) return true;

    final today = _getTodayWeekday();
    final rawHours = pharmacy.workingHours?[today];

    final range = _parseBusinessHoursRange(rawHours);
    if (range == null) return false;

    return _isTimeBetween(TimeOfDay.now(), range.open, range.close);
  }

  String _getTodayWeekday() {
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];

    return days[DateTime.now().weekday % 7];
  }

  _BusinessHourRange? _parseBusinessHoursRange(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final lowerText = text.toLowerCase();

    if (lowerText == 'closed' ||
        lowerText == 'close' ||
        lowerText == 'مغلق' ||
        lowerText == 'مغلق اليوم') {
      return null;
    }

    if (lowerText == '24 hours' || lowerText == '24 ساعة') {
      return const _BusinessHourRange(
        open: TimeOfDay(hour: 0, minute: 0),
        close: TimeOfDay(hour: 23, minute: 59),
      );
    }

    final parts = text.split(RegExp(r'\s*-\s*'));
    if (parts.length != 2) return null;

    final open = _parseFlexibleTime(parts[0]);
    final close = _parseFlexibleTime(parts[1]);

    if (open == null || close == null) return null;

    return _BusinessHourRange(open: open, close: close);
  }

  TimeOfDay? _parseFlexibleTime(String? value) {
    if (value == null) return null;

    var text = value.trim();
    if (text.isEmpty) return null;

    final isArabicPm = text.contains('م');
    final isArabicAm = text.contains('ص');
    final isEnglishPm = text.toLowerCase().contains('pm');
    final isEnglishAm = text.toLowerCase().contains('am');

    text = text
        .replaceAll('ص', '')
        .replaceAll('م', '')
        .replaceAll('AM', '')
        .replaceAll('PM', '')
        .replaceAll('am', '')
        .replaceAll('pm', '')
        .trim();

    final parts = text.split(':');
    if (parts.isEmpty) return null;

    int? hour = int.tryParse(parts[0].trim());
    int minute = 0;

    if (parts.length > 1) {
      minute = int.tryParse(parts[1].trim()) ?? 0;
    }

    if (hour == null) return null;

    final isPm = isArabicPm || isEnglishPm;
    final isAm = isArabicAm || isEnglishAm;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeBetween(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowInMinutes = now.hour * 60 + now.minute;
    final startInMinutes = start.hour * 60 + start.minute;
    final endInMinutes = end.hour * 60 + end.minute;

    if (startInMinutes <= endInMinutes) {
      return nowInMinutes >= startInMinutes && nowInMinutes <= endInMinutes;
    }

    return nowInMinutes >= startInMinutes || nowInMinutes <= endInMinutes;
  }


  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final nearbyIds = pharmacies.map((p) => p.id).toSet();

    final List<Marker> markers = [];

    // 📍 موقع المستخدم
    markers.add(
      Marker(
        point: currentPosition!,
        width: 50,
        height: 50,
        child: const Icon(
          Iconsax.location,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );


    // 🏥 الصيدليات
    for (final pharmacy in allPharmacies) {
      final point = _getPharmacyLocation(pharmacy);
      if (point == null) continue;

      final name = pharmacy.displayName;
      final isNearby = nearbyIds.contains(pharmacy.id);
      final distanceText = isNearby ? _getFormattedDistance(pharmacy) : null;

      final isOpen = _isPharmacyOpen(pharmacy);

      final markerColor = isOpen ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
      final softColor = isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

      markers.add(
        Marker(
          point: point,
          width: 76,
          height: 86,
          child: Tooltip(
            message: isNearby && distanceText != null
                ? '$name - $distanceText'
                : name,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // زر فتح Google Maps
                Positioned(
                  top: 0,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _openInGoogleMaps(pharmacy),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: markerColor.withOpacity(0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        color: markerColor,
                        size: 15,
                      ),
                    ),
                  ),
                ),

                // أيقونة الصيدلية الأساسية
                Positioned(
                  top: 20,
                  child: Container(
                    width: isNearby ? 46 : 42,
                    height: isNearby ? 46 : 42,
                    decoration: BoxDecoration(
                      color: softColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_pharmacy_rounded,
                      color: markerColor,
                      size: isNearby ? 26 : 24,
                    ),
                  ),
                ),

                // شارة 24 ساعة
                if (pharmacy.is24Hours)
                  Positioned(
                    top: 18,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: const Text(
                        '24h',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // نقطة حالة مفتوح/مغلق
                Positioned(
                  top: 52,
                  right: 17,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),

                // المسافة
                if (isNearby && distanceText != null)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: markerColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Iconsax.location,
                            color: Colors.white,
                            size: 9,
                          ),
                          const SizedBox(width: 3),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: currentPosition!,
              zoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_application',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),

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
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Iconsax.refresh_circle,
                  color: Color(0xFF4FC3F7),
                  size: 24,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 15,
          left: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
        ),
      ],
    );
  }
}
class _BusinessHourRange {
  final TimeOfDay open;
  final TimeOfDay close;

  const _BusinessHourRange({
    required this.open,
    required this.close,
  });
}