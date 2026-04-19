import 'package:flutter/material.dart';

class ReminderTimeHelper {
  ReminderTimeHelper._();

  static String formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static TimeOfDay parseTimeString(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static DateTime combineDateAndTime(DateTime date, String timeString) {
    final time = parseTimeString(timeString);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  static List<String> normalizeAndSortTimes(List<String> times) {
    final unique = times.toSet().toList();
    unique.sort((a, b) {
      final ta = parseTimeString(a);
      final tb = parseTimeString(b);
      final ma = ta.hour * 60 + ta.minute;
      final mb = tb.hour * 60 + tb.minute;
      return ma.compareTo(mb);
    });
    return unique;
  }
}