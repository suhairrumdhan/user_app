import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapTab extends StatelessWidget {
  final LatLng? currentPosition;
  final List<LatLng> pharmacies;

  const MapTab({
    super.key,
    this.currentPosition,
    required this.pharmacies,
  });

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: currentPosition!,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.user_application',
          ),
          MarkerLayer(
            markers: [
              // موقع المستخدم الحالي
              Marker(
                point: currentPosition!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              // الصيدليات
              ...pharmacies.map(
                    (pharmacy) => Marker(
                  point: pharmacy,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.local_pharmacy,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
