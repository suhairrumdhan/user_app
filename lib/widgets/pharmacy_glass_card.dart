import 'dart:ui';
import 'package:flutter/material.dart';

class PharmacyGlassCard extends StatelessWidget {
  final Map<String, dynamic> pharmacy;

  const PharmacyGlassCard({super.key, required this.pharmacy});

  bool get is24Hours => pharmacy['is24Hours'] == true;

  String get workingStatus {
    if (is24Hours) return 'مفتوح 24 ساعة';

    final now = TimeOfDay.now();
    final today = _getTodayWeekday();
    final hours = pharmacy['workingHours']?[today];

    if (hours != null && hours['isOpen'] == true) {
      final openTime = _parseTime(hours['open']);
      final closeTime = _parseTime(hours['close']);
      final isOpen = _isTimeBetween(now, openTime, closeTime);

      return isOpen ? 'مفتوح الآن' : 'مغلق الآن';
    }

    return 'مغلق الآن';
  }

  Color get statusColor {
    switch (workingStatus) {
      case 'مفتوح الآن':
      case 'مفتوح 24 ساعة':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = pharmacy['distance'] != null
        ? (pharmacy['distance'] / 1000).toStringAsFixed(1)
        : '0.0';

    final imageUrl = pharmacy['imageUrl'] ?? '';
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image/icon and name
              Row(
                children: [
                  // Pharmacy Image/Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: hasImage
                          ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                          : null,
                      gradient: hasImage
                          ? null
                          : const LinearGradient(
                        colors: [Color(0xFF5EABD6), Color(0xFF7FCFEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: hasImage
                        ? null
                        : const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Pharmacy Name and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pharmacy["name"] ?? "صيدلية",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(),
                                color: statusColor,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                workingStatus,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address with icon
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pharmacy["address"] ?? "العنوان غير متوفر",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Working hours info
              if (!is24Hours) ...[
                Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getWorkingHoursText(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              const Spacer(),

              // Footer with distance and phone
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Distance
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$distance كم",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Phone icon (if available)
                  if (pharmacy['phone'] != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.phone_outlined,
                        color: Colors.white.withOpacity(0.9),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (workingStatus) {
      case 'مفتوح الآن':
      case 'مفتوح 24 ساعة':
        return Icons.circle;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getTodayWeekday() {
    final days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday'
    ];
    return days[DateTime.now().weekday % 7];
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  bool _isTimeBetween(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowInMinutes = now.hour * 60 + now.minute;
    final startInMinutes = start.hour * 60 + start.minute;
    final endInMinutes = end.hour * 60 + end.minute;

    return nowInMinutes >= startInMinutes && nowInMinutes <= endInMinutes;
  }

  String _getWorkingHoursText() {
    final today = _getTodayWeekday();
    final hours = pharmacy['workingHours']?[today];

    if (hours != null && hours['isOpen'] == true) {
      return '${hours['open']} - ${hours['close']}';
    }

    return 'مغلق اليوم';
  }
}