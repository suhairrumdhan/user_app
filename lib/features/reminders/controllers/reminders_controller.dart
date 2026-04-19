import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/appointment_reminder_model.dart';
import '../data/models/medication_reminder_model.dart';
import '../data/models/reminder_log_model.dart';
import '../data/repositories/reminders_repository.dart';
import '../services/local_notification_service.dart';
import '../services/reminder_scheduler_service.dart';
import '../domain/helpers/reminder_time_helper.dart';

class RemindersController extends GetxController {
  final RemindersRepository _repo = RemindersRepository();

  // ========= Streams =========

  final RxList<MedicationReminderModel> medicationReminders =
      <MedicationReminderModel>[].obs;

  final RxList<AppointmentReminderModel> appointmentReminders =
      <AppointmentReminderModel>[].obs;

  final RxList<ReminderLogModel> logs = <ReminderLogModel>[].obs;

  @override
  void onInit() {
    super.onInit();

    // watch medication
    _repo.watchAllMedicationReminders().listen((data) {
      medicationReminders.value = data;
    });

    // watch appointment
    _repo.watchAllAppointmentReminders().listen((data) {
      appointmentReminders.value = data;
    });

    // watch logs
    _repo.watchAllLogs().listen((data) {
      logs.value = data;
    });
  }

  // ========= CREATE =========

  Future<void> addMedicationReminder(
      MedicationReminderModel reminder,
      ) async {
    reminder.times = ReminderTimeHelper.normalizeAndSortTimes(reminder.times);
    reminder.status = 'active';
    reminder.createdAt = DateTime.now();

    debugPrint('🟦 addMedicationReminder -> before save, times=${reminder.times}');

    final id = await _repo.addMedicationReminder(reminder);
    reminder.id = id;

    debugPrint('🟨 addMedicationReminder -> saved with id=${reminder.id}');

    final notificationIds =
    await ReminderSchedulerService.scheduleMedicationReminder(reminder);

    reminder.notificationIds = notificationIds;

    debugPrint('🟩 addMedicationReminder -> notificationIds=$notificationIds');

    await _repo.updateMedicationReminder(reminder);
  }

  Future<void> addAppointmentReminder(
      AppointmentReminderModel reminder,
      ) async {
    reminder.status = 'active';
    reminder.createdAt = DateTime.now();

    debugPrint(
      '🟦 addAppointmentReminder -> before save, appointment=${reminder.appointmentDateTime}, remindBefore=${reminder.remindBeforeMinutes}',
    );

    final id = await _repo.addAppointmentReminder(reminder);
    reminder.id = id;

    debugPrint('🟨 addAppointmentReminder -> saved with id=${reminder.id}');

    final notificationId =
    await ReminderSchedulerService.scheduleAppointmentReminder(reminder);

    reminder.notificationId = notificationId;

    debugPrint('🟩 addAppointmentReminder -> notificationId=$notificationId');

    await _repo.updateAppointmentReminder(reminder);
  }

  // ========= DELETE =========

  Future<void> deleteMedicationReminder(
      MedicationReminderModel reminder,
      ) async {
    await ReminderSchedulerService.cancelMedicationReminder(reminder);
    await _repo.deleteMedicationReminder(reminder.id);

    await _repo.deleteLogsByReminder(
      reminderType: 'medication',
      reminderLocalId: reminder.id,
    );
  }

  Future<void> deleteAppointmentReminder(
      AppointmentReminderModel reminder,
      ) async {
    await ReminderSchedulerService.cancelAppointmentReminder(reminder);
    await _repo.deleteAppointmentReminder(reminder.id);

    await _repo.deleteLogsByReminder(
      reminderType: 'appointment',
      reminderLocalId: reminder.id,
    );
  }

  // ========= PAUSE / RESUME =========

  Future<void> pauseMedication(MedicationReminderModel reminder) async {
    await ReminderSchedulerService.cancelMedicationReminder(reminder);

    reminder.status = 'paused';
    reminder.updatedAt = DateTime.now();

    await _repo.updateMedicationReminder(reminder);
  }

  Future<void> resumeMedication(MedicationReminderModel reminder) async {
    final notificationIds =
    await ReminderSchedulerService.scheduleMedicationReminder(reminder);

    reminder.notificationIds = notificationIds;
    reminder.status = 'active';
    reminder.updatedAt = DateTime.now();

    await _repo.updateMedicationReminder(reminder);
  }

  Future<void> pauseAppointment(AppointmentReminderModel reminder) async {
    await ReminderSchedulerService.cancelAppointmentReminder(reminder);

    reminder.status = 'paused';
    reminder.updatedAt = DateTime.now();

    await _repo.updateAppointmentReminder(reminder);
  }

  Future<void> resumeAppointment(AppointmentReminderModel reminder) async {
    final notificationId =
    await ReminderSchedulerService.scheduleAppointmentReminder(reminder);

    reminder.notificationId = notificationId;
    reminder.status = 'active';
    reminder.updatedAt = DateTime.now();

    await _repo.updateAppointmentReminder(reminder);
  }

  // ========= ACTIONS =========

  Future<void> markMedicationTaken(
      MedicationReminderModel reminder,
      ) async {
    reminder.lastTakenAt = DateTime.now();

    await _repo.updateMedicationReminder(reminder);

    await _addLog(
      reminderType: 'medication',
      reminderId: reminder.id,
      ownerId: reminder.owner.beneficiaryId,
      ownerName: reminder.owner.name,
      action: 'taken',
      title: reminder.medicineName,
    );
  }

  Future<void> snoozeMedication(
      MedicationReminderModel reminder, {
        Duration duration = const Duration(minutes: 10),
      }) async {
    await ReminderSchedulerService.scheduleSnooze(
      reminderLocalId: reminder.id,
      title: '💊 ${reminder.medicineName}',
      body: 'تم تأجيل التذكير',
      duration: duration,
    );

    reminder.lastSnoozedAt = DateTime.now();

    await _repo.updateMedicationReminder(reminder);

    await _addLog(
      reminderType: 'medication',
      reminderId: reminder.id,
      ownerId: reminder.owner.beneficiaryId,
      ownerName: reminder.owner.name,
      action: 'snoozed',
      title: reminder.medicineName,
    );
  }

  Future<void> skipMedication(MedicationReminderModel reminder) async {
    await _addLog(
      reminderType: 'medication',
      reminderId: reminder.id,
      ownerId: reminder.owner.beneficiaryId,
      ownerName: reminder.owner.name,
      action: 'skipped',
      title: reminder.medicineName,
    );
  }

  // ========= LOG =========

  Future<void> _addLog({
    required String reminderType,
    required int reminderId,
    required String ownerId,
    required String ownerName,
    required String action,
    String? title,
  }) async {
    final log = ReminderLogModel()
      ..reminderType = reminderType
      ..reminderLocalId = reminderId
      ..ownerBeneficiaryId = ownerId
      ..ownerName = ownerName
      ..actionType = action
      ..scheduledAt = DateTime.now()
      ..actionAt = DateTime.now()
      ..title = title
      ..createdAt = DateTime.now();

    await _repo.addLog(log);
  }
}