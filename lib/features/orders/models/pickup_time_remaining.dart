class PickupTimeRemaining {
  const PickupTimeRemaining._();

  static bool isOverdue({
    required bool isReady,
    required bool serverMarkedOverdue,
    required DateTime? deadline,
    required DateTime now,
  }) {
    return isReady &&
        (serverMarkedOverdue || (deadline != null && !now.isBefore(deadline)));
  }

  static String? format({required DateTime? deadline, required DateTime now}) {
    if (deadline == null) return null;
    if (!now.isBefore(deadline)) return 'انتهت مهلة الاستلام';

    // Round up so a deadline that is still seconds away never displays zero.
    final microseconds = deadline.difference(now).inMicroseconds;
    final totalMinutes = (microseconds + 60000000 - 1) ~/ 60000000;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    if (minutes > 0 || parts.isEmpty) parts.add('$minutes دقيقة');
    return 'الوقت المتبقي: ${parts.join(' و')}';
  }
}
