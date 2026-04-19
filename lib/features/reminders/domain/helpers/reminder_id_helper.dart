class ReminderIdHelper {
  ReminderIdHelper._();

  /// يولد ID ثابت نسبيًا لكل reminder + index
  static int medicationNotificationId({
    required int reminderLocalId,
    required int timeIndex,
  }) {
    return (reminderLocalId * 100) + timeIndex;
  }

  static int appointmentNotificationId({
    required int reminderLocalId,
  }) {
    return (reminderLocalId * 1000) + 1;
  }

  static int snoozeNotificationId({
    required int reminderLocalId,
    required int seed,
  }) {
    return (reminderLocalId * 100000) + seed;
  }
}