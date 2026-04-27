import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:iconsax/iconsax.dart';

import '../models/pharmacy_model.dart';

class MapTab extends StatelessWidget {
  final LatLng? currentPosition;
  final List<PharmacyModel> pharmacies;
  final List<PharmacyModel> allPharmacies;
  final VoidCallback onRefresh;
  final double selectedDistance;

  const MapTab({
    super.key,
    this.currentPosition,
    required this.pharmacies,
    required this.allPharmacies,
    required this.onRefresh,
    required this.selectedDistance,
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
      final isOpen247 = pharmacy.is24Hours;
      final distanceText = isNearby ? _getFormattedDistance(pharmacy) : null;

      markers.add(
        Marker(
          point: point,
          width: isNearby ? 45 : 40,
          height: isNearby ? 45 : 40,
          child: Tooltip(
            message: isNearby && distanceText != null
                ? '$name (ضمن ${selectedDistance.toStringAsFixed(0)} كم - $distanceText)'
                : name,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  isOpen247 ? Iconsax.health : Iconsax.hospital,
                  color: isNearby
                      ? Colors.red
                      : (isOpen247 ? Colors.orange : Colors.grey),
                  size: isNearby ? 35 : 30,
                ),

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
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FlutterMap(
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