import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/pharmacy_model.dart';

class PharmacyGlassCard extends StatelessWidget {
  final PharmacyModel pharmacy;
  const PharmacyGlassCard({super.key, required this.pharmacy});

  bool get is24Hours => pharmacy.is24Hours;

  String get workingStatus {
    if (is24Hours) return 'مفتوح 24 ساعة';

    final today = _getTodayWeekday();
    final rawHours = pharmacy.workingHours?[today];

    final range = _parseBusinessHoursRange(rawHours);
    if (range == null) return 'مغلق الآن';

    final now = TimeOfDay.now();
    final isOpen = _isTimeBetween(now, range.open, range.close);

    return isOpen ? 'مفتوح الآن' : 'مغلق الآن';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;

    final distance = pharmacy.distance != null
        ? (pharmacy.distance! / 1000).toStringAsFixed(1)
        : '0.0';

    final imageUrl = pharmacy.imageUrl;
    final hasImage = imageUrl.isNotEmpty;

    return LayoutBuilder(
        builder: (context, constraints) {
          return FractionallySizedBox(
            widthFactor: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.all(
                    isSmallScreen ? 12 : (isLargeScreen ? 24 : 16),
                  ),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with image/icon and name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Pharmacy Image/Icon
                          Container(
                            width: isSmallScreen ? 44 : (isLargeScreen ? 60 : 52),
                            height: isSmallScreen ? 44 : (isLargeScreen ? 60 : 52),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                isSmallScreen ? 12 : (isLargeScreen ? 20 : 16),
                              ),
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
                                : Icon(
                              Icons.local_pharmacy_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 22 : (isLargeScreen ? 32 : 28),
                            ),
                          ),

                          SizedBox(width: isSmallScreen ? 8 : (isLargeScreen ? 20 : 12)),

                          // Pharmacy Name and Status
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                pharmacy.displayName,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 16 : (isLargeScreen ? 20 : 18),
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                SizedBox(height: isSmallScreen ? 2 : 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: isSmallScreen ? 2 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
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
                                        size: isSmallScreen ? 12 : 14,
                                      ),
                                      SizedBox(width: isSmallScreen ? 2 : 4),
                                      Flexible(
                                        child: Text(
                                          workingStatus,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: isSmallScreen ? 11 : 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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

                      SizedBox(height: isSmallScreen ? 8 : (isLargeScreen ? 16 : 12)),

                      // Address with icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: Colors.white.withOpacity(0.8),
                            size: isSmallScreen ? 16 : (isLargeScreen ? 20 : 18),
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 8),
                          Expanded(
                            child: Text(
                                pharmacy.displayAddress,
                                style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isSmallScreen ? 12 : (isLargeScreen ? 16 : 14),
                                height: 1.3, // تقليل الـ height قليلاً
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 6 : (isLargeScreen ? 12 : 8)),

                      // Working hours info
                      if (!is24Hours) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              color: Colors.white.withOpacity(0.8),
                              size: isSmallScreen ? 14 : (isLargeScreen ? 18 : 16),
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 8),
                            Flexible(
                              child: Text(
                                _getWorkingHoursText(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: isSmallScreen ? 11 : (isLargeScreen ? 15 : 13),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 4 : (isLargeScreen ? 10 : 6)),
                      ],

                      // Footer with distance and phone
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Distance
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : (isLargeScreen ? 16 : 10),
                              vertical: isSmallScreen ? 3 : (isLargeScreen ? 8 : 5), // تقليل الـ padding الرأسي
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_car_outlined,
                                  color: Colors.white.withOpacity(0.9),
                                  size: isSmallScreen ? 14 : (isLargeScreen ? 18 : 16),
                                ),
                                SizedBox(width: isSmallScreen ? 4 : 6),
                                Text(
                                  "$distance كم",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : (isLargeScreen ? 16 : 14),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Phone icon (if available)
                          if (pharmacy.hasPhone)
                            GestureDetector(
                              onTap: () async {
                                final phone = pharmacy.phoneNumber;

                                final uri = Uri(scheme: 'tel', path: phone);

                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('لا يمكن فتح الاتصال')),
                                  );
                                }
                              },
                              onLongPress: () async {
                                await Clipboard.setData(ClipboardData(text: pharmacy.phoneNumber));

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ رقم الهاتف')),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                  isSmallScreen ? 5 : (isLargeScreen ? 10 : 7),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 8 : (isLargeScreen ? 12 : 10),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      color: Colors.white.withOpacity(0.9),
                                      size: isSmallScreen ? 16 : (isLargeScreen ? 22 : 18),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pharmacy.phoneNumber,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 10 : 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
    );
  }

  _BusinessHourRange? _parseBusinessHoursRange(dynamic value) {
    if (value == null) return null;

    // يدعم الشكل القديم لو كان Map
    if (value is Map) {
      final isOpen = value['isOpen'] == true;
      if (!isOpen) return null;

      final open = _parseFlexibleTime(value['open']?.toString());
      final close = _parseFlexibleTime(value['close']?.toString());

      if (open == null || close == null) return null;

      return _BusinessHourRange(open: open, close: close);
    }

    // يدعم الشكل الموجود عندك: "09:00 - 18:00" أو "3:00 ص - 6:00 م"
    final text = value.toString().trim();

    if (text.isEmpty) return null;

    final lowerText = text.toLowerCase();

    if (
    lowerText == 'closed' ||
        lowerText == 'مغلق' ||
        lowerText == 'مغلق اليوم' ||
        lowerText == 'close'
    ) {
      return null;
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

    if (isPm && hour < 12) {
      hour += 12;
    }

    if (isAm && hour == 12) {
      hour = 0;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
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

    // دوام عادي في نفس اليوم
    if (startInMinutes <= endInMinutes) {
      return nowInMinutes >= startInMinutes && nowInMinutes <= endInMinutes;
    }

    // دوام يعبر منتصف الليل
    return nowInMinutes >= startInMinutes || nowInMinutes <= endInMinutes;
  }

  String _getWorkingHoursText() {
    final today = _getTodayWeekday();
    final rawHours = pharmacy.workingHours?[today];

    final range = _parseBusinessHoursRange(rawHours);
    if (range == null) return 'مغلق اليوم';

    return rawHours.toString();
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