import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import 'search_ui_colors.dart';

class SearchResultsMap extends StatefulWidget {
  final List<PharmacyModel> pharmacies;
  final LatLng? userPosition;
  final PharmacyModel? focusedPharmacy;
  final ValueChanged<PharmacyModel> onOrder;
  final ValueChanged<PharmacyModel> onDetails;
  final bool interactive;
  final bool expanded;
  final VoidCallback? onOpenInteractive;

  const SearchResultsMap({
    super.key,
    required this.pharmacies,
    required this.userPosition,
    this.focusedPharmacy,
    required this.onOrder,
    required this.onDetails,
    this.interactive = true,
    this.expanded = false,
    this.onOpenInteractive,
  });

  @override
  State<SearchResultsMap> createState() => _SearchResultsMapState();
}

class _SearchResultsMapState extends State<SearchResultsMap> {
  final MapController _mapController = MapController();
  PharmacyModel? _selectedPharmacy;

  @override
  void initState() {
    super.initState();
    _selectedPharmacy = widget.focusedPharmacy;
  }

  List<PharmacyModel> get _mappablePharmacies {
    return widget.pharmacies.where((pharmacy) {
      final lat = pharmacy.latitude;
      final lng = pharmacy.longitude;
      return lat != null &&
          lng != null &&
          lat != 0 &&
          lng != 0 &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180;
    }).toList();
  }

  LatLng? _pharmacyPoint(PharmacyModel pharmacy) {
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  List<LatLng> get _allPoints => [
    if (widget.userPosition != null) widget.userPosition!,
    ..._mappablePharmacies.map((pharmacy) => _pharmacyPoint(pharmacy)!),
  ];

  LatLng get _initialCenter {
    final focusedPharmacy = widget.focusedPharmacy;
    if (focusedPharmacy != null) {
      final focusedPoint = _pharmacyPoint(focusedPharmacy);
      if (focusedPoint != null) return focusedPoint;
    }
    if (widget.userPosition != null) return widget.userPosition!;
    final pharmacies = _mappablePharmacies;
    if (pharmacies.isNotEmpty) return _pharmacyPoint(pharmacies.first)!;
    return const LatLng(32.8872, 13.1913);
  }

  double get _initialZoom {
    if (widget.focusedPharmacy != null) return 15.5;
    if (_mappablePharmacies.length > 5) return 11.5;
    if (_mappablePharmacies.length > 1) return 12.5;
    return 14;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    final userPosition = widget.userPosition;
    if (userPosition != null) {
      markers.add(
        Marker(
          point: userPosition,
          width: 52,
          height: 52,
          child: const _UserLocationMarker(),
        ),
      );
    }

    for (final pharmacy in _mappablePharmacies) {
      final point = _pharmacyPoint(pharmacy);
      if (point == null) continue;

      final isSelected = _selectedPharmacy?.id == pharmacy.id;
      markers.add(
        Marker(
          point: point,
          width: 92,
          height: 82,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedPharmacy = pharmacy),
            child: _PharmacyMapMarker(
              pharmacy: pharmacy,
              isSelected: isSelected,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _recenter() {
    if (_allPoints.length > 1) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_allPoints),
          padding: const EdgeInsets.all(48),
          maxZoom: 15.5,
        ),
      );
    } else {
      _mapController.move(_initialCenter, _initialZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mappablePharmacies.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: SearchUiColors.primary.withOpacity(0.10)),
        ),
        child: const Column(
          children: [
            Icon(Icons.location_off_rounded, size: 34, color: Colors.orange),
            SizedBox(height: 12),
            Text(
              'لا تتوفر إحداثيات صحيحة لنتائج البحث',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: SearchUiColors.darkText,
              ),
            ),
          ],
        ),
      );
    }

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 0 : 22),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              initialCameraFit:
                  widget.focusedPharmacy == null && _allPoints.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(_allPoints),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 15.5,
                    )
                  : null,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              onTap: widget.interactive
                  ? (_, __) {
                      if (_selectedPharmacy != null) {
                        setState(() => _selectedPharmacy = null);
                      }
                    }
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.user_application',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          if (widget.interactive)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'إعادة توسيط الخريطة',
                  onPressed: _recenter,
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: SearchUiColors.primary,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 14,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ),
          if (!widget.interactive && widget.onOpenInteractive != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: widget.onOpenInteractive,
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('خريطة تفاعلية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SearchUiColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (widget.interactive && _selectedPharmacy != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _SelectedPharmacyCard(
                pharmacy: _selectedPharmacy!,
                onClose: () => setState(() => _selectedPharmacy = null),
                onOrder: () => widget.onOrder(_selectedPharmacy!),
                onDetails: () => widget.onDetails(_selectedPharmacy!),
              ),
            ),
        ],
      ),
    );

    if (widget.expanded) {
      return SizedBox.expand(child: map);
    }

    return SizedBox(height: 340, child: map);
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 34),
    );
  }
}

class _PharmacyMapMarker extends StatelessWidget {
  final PharmacyModel pharmacy;
  final bool isSelected;

  const _PharmacyMapMarker({required this.pharmacy, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = pharmacy.isOpenNow || pharmacy.is24Hours
        ? SearchUiColors.success
        : SearchUiColors.danger;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 48 : 42,
          height: isSelected ? 48 : 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: isSelected ? 14 : 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_pharmacy_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          constraints: const BoxConstraints(maxWidth: 90),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 5),
            ],
          ),
          child: Text(
            pharmacy.distanceKm >= 0
                ? pharmacy.displayDistance
                : pharmacy.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: SearchUiColors.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedPharmacyCard extends StatelessWidget {
  final PharmacyModel pharmacy;
  final VoidCallback onClose;
  final VoidCallback onOrder;
  final VoidCallback onDetails;

  const _SelectedPharmacyCard({
    required this.pharmacy,
    required this.onClose,
    required this.onOrder,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SearchUiColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: pharmacy.imageUrl.isNotEmpty
                      ? Image.network(
                          pharmacy.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_pharmacy_rounded,
                            color: SearchUiColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.local_pharmacy_rounded,
                          color: SearchUiColors.primary,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacy.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SearchUiColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pharmacy.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pharmacy.isOpenNow || pharmacy.is24Hours
                              ? SearchUiColors.success
                              : SearchUiColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MapInfoItem(
                    label: 'المسافة',
                    value: pharmacy.displayDistance,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _MapInfoItem(
                    label: 'السعر التقديري',
                    value: pharmacy.displayPrice,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _MapInfoItem(
                    label: 'التوفر',
                    value:
                        '${pharmacy.matchedCount}/${pharmacy.requestedCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onOrder,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                    label: const Text('إتمام الطلب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SearchUiColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('التفاصيل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SearchUiColors.primary,
                      side: BorderSide(
                        color: SearchUiColors.primary.withOpacity(0.22),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _MapInfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: SearchUiColors.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: SearchUiColors.darkText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
