import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models/appointment_reminder_model.dart';
import '../data/models/medication_reminder_model.dart';
import '../domain/helpers/reminder_id_helper.dart';
import '../domain/helpers/reminder_time_helper.dart';
import 'local_notification_service.dart';

class ReminderSchedulerService {
  ReminderSchedulerService._();

  static Future<List<int>> scheduleMedicationReminder(
      MedicationReminderModel reminder,
      ) async {
    if (reminder.id <= 0) {
      throw StateError(
        'Medication reminder must be saved first before scheduling notifications.',
      );
    }

    debugPrint(
      '🟦 scheduleMedicationReminder -> reminderId=${reminder.id}, times=${reminder.times}',
    );

    await LocalNotificationService.cancelAll(reminder.notificationIds);

    final ids = <int>[];

    for (int i = 0; i < reminder.times.length; i++) {
      final time = ReminderTimeHelper.parseTimeString(reminder.times[i]);
      final notificationId = ReminderIdHelper.medicationNotificationId(
        reminderLocalId: reminder.id,
        timeIndex: i,
      );

      final scheduledAt = LocalNotificationService.nextInstanceOfTime(
        hour: time.hour,
        minute: time.minute,
      );

      debugPrint(
        '🟨 scheduling medication notification -> id=$notificationId, at=$scheduledAt, medicine=${reminder.medicineName}',
      );

      try {
        await LocalNotificationService.plugin.zonedSchedule(
          notificationId,
          '💊 ${reminder.medicineName}',
          'حان وقت تناول الدواء لـ ${reminder.owner.name}',
          scheduledAt,
          LocalNotificationService.medicationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'type=medication;id=${reminder.id};timeIndex=$i',
        );

        debugPrint('✅ medication notification scheduled -> id=$notificationId');
        ids.add(notificationId);
      } catch (e, st) {
        debugPrint('❌ failed to schedule medication notification: $e');
        debugPrint('$st');
      }
    }

    final pending = await LocalNotificationService.pendingRequests();
    debugPrint('📦 pending notifications after medication schedule: ${pending.length}');
    for (final item in pending) {
      debugPrint('   -> pending id=${item.id}, title=${item.title}, body=${item.body}');
    }

    return ids;
  }

  static Future<int?> scheduleAppointmentReminder(
      AppointmentReminderModel reminder,
      ) async {
    if (reminder.id <= 0) {
      throw StateError(
        'Appointment reminder must be saved first before scheduling notifications.',
      );
    }

    await LocalNotificationService.cancelSingle(reminder.notificationId);

    final scheduledAt = reminder.appointmentDateTime.subtract(
      Duration(minutes: reminder.remindBeforeMinutes),
    );

    debugPrint(
      '🟦 scheduleAppointmentReminder -> reminderId=${reminder.id}, appointment=${reminder.appointmentDateTime}, trigger=$scheduledAt',
    );

    if (!scheduledAt.isAfter(DateTime.now())) {
      debugPrint('⚠️ appointment trigger is in the past, skipping scheduling');
      return null;
    }

    final notificationId = ReminderIdHelper.appointmentNotificationId(
      reminderLocalId: reminder.id,
    );

    try {
      await LocalNotificationService.plugin.zonedSchedule(
        notificationId,
        '📅 ${reminder.title}',
        'لديك موعد قريب لـ ${reminder.owner.name}',
        LocalNotificationService.fromDateTime(scheduledAt),
        LocalNotificationService.appointmentDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'type=appointment;id=${reminder.id}',
      );

      debugPrint('✅ appointment notification scheduled -> id=$notificationId');
    } catch (e, st) {
      debugPrint('❌ failed to schedule appointment notification: $e');
      debugPrint('$st');
      rethrow;
    }

    final pending = await LocalNotificationService.pendingRequests();
    debugPrint('📦 pending notifications after appointment schedule: ${pending.length}');
    for (final item in pending) {
      debugPrint('   -> pending id=${item.id}, title=${item.title}, body=${item.body}');
    }

    return notificationId;
  }

  static Future<int> scheduleSnooze({
    required int reminderLocalId,
    required String title,
    required String body,
    required Duration duration,
  }) async {
    final seed = DateTime.now().millisecondsSinceEpoch % 10000;
    final notificationId = ReminderIdHelper.snoozeNotificationId(
      reminderLocalId: reminderLocalId,
      seed: seed,
    );

    final target = DateTime.now().add(duration);

    debugPrint('🟪 scheduleSnooze -> id=$notificationId, target=$target');

    await LocalNotificationService.plugin.zonedSchedule(
      notificationId,
      title,
      body,
      LocalNotificationService.fromDateTime(target),
      LocalNotificationService.snoozeDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'type=snooze;id=$reminderLocalId',
    );

    return notificationId;
  }

  static Future<void> cancelMedicationReminder(
      MedicationReminderModel reminder,
      ) async {
    await LocalNotificationService.cancelAll(reminder.notificationIds);
  }

  static Future<void> cancelAppointmentReminder(
      AppointmentReminderModel reminder,
      ) async {
    await LocalNotificationService.cancelSingle(reminder.notificationId);
  }

  static Future<void> cancelAllMedicationIds(List<int> ids) async {
    await LocalNotificationService.cancelAll(ids);
  }

  static TimeOfDay parseStoredTime(String value) {
    return ReminderTimeHelper.parseTimeString(value);
  }
}