import 'package:isar/isar.dart';

import '../models/appointment_reminder_model.dart';
import '../models/medication_reminder_model.dart';
import '../models/reminder_log_model.dart';
import 'reminders_local_db.dart';

class RemindersLocalDataSource {
  Isar get _db => RemindersLocalDb.instance;

  // ========= Medication Reminders =========

  Future<int> addMedicationReminder(MedicationReminderModel reminder) async {
    return _db.writeTxn(() async {
      return _db.medicationReminderModels.put(reminder);
    });
  }

  Future<bool> updateMedicationReminder(MedicationReminderModel reminder) async {
    return _db.writeTxn(() async {
      final id = await _db.medicationReminderModels.put(reminder);
      return id > 0;
    });
  }

  Future<MedicationReminderModel?> getMedicationReminderById(int id) {
    return _db.medicationReminderModels.get(id);
  }

  Future<List<MedicationReminderModel>> getAllMedicationReminders() {
    return _db.medicationReminderModels.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<MedicationReminderModel>> getMedicationRemindersByStatus(
      String status,
      ) {
    return _db.medicationReminderModels
        .filter()
        .statusEqualTo(status)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<MedicationReminderModel>> watchAllMedicationReminders() {
    return _db.medicationReminderModels.where().sortByCreatedAtDesc().watch(
      fireImmediately: true,
    );
  }

  Stream<List<MedicationReminderModel>> watchMedicationRemindersByStatus(
      String status,
      ) {
    return _db.medicationReminderModels
        .filter()
        .statusEqualTo(status)
        .watch(fireImmediately: true);
  }

  Future<void> deleteMedicationReminder(int id) async {
    await _db.writeTxn(() async {
      await _db.medicationReminderModels.delete(id);
    });
  }

  // ========= Appointment Reminders =========

  Future<int> addAppointmentReminder(AppointmentReminderModel reminder) async {
    return _db.writeTxn(() async {
      return _db.appointmentReminderModels.put(reminder);
    });
  }

  Future<bool> updateAppointmentReminder(
      AppointmentReminderModel reminder,
      ) async {
    return _db.writeTxn(() async {
      final id = await _db.appointmentReminderModels.put(reminder);
      return id > 0;
    });
  }

  Future<AppointmentReminderModel?> getAppointmentReminderById(int id) {
    return _db.appointmentReminderModels.get(id);
  }

  Future<List<AppointmentReminderModel>> getAllAppointmentReminders() {
    return _db.appointmentReminderModels.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<AppointmentReminderModel>> getAppointmentRemindersByStatus(
      String status,
      ) {
    return _db.appointmentReminderModels
        .filter()
        .statusEqualTo(status)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<AppointmentReminderModel>> watchAllAppointmentReminders() {
    return _db.appointmentReminderModels.where().sortByCreatedAtDesc().watch(
      fireImmediately: true,
    );
  }

  Future<void> deleteAppointmentReminder(int id) async {
    await _db.writeTxn(() async {
      await _db.appointmentReminderModels.delete(id);
    });
  }

  // ========= Reminder Logs =========

  Future<int> addLog(ReminderLogModel log) async {
    return _db.writeTxn(() async {
      return _db.reminderLogModels.put(log);
    });
  }

  Future<List<ReminderLogModel>> getAllLogs() {
    return _db.reminderLogModels.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<ReminderLogModel>> getLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) {
    return _db.reminderLogModels
        .filter()
        .reminderTypeEqualTo(reminderType)
        .and()
        .reminderLocalIdEqualTo(reminderLocalId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<ReminderLogModel>> watchAllLogs() {
    return _db.reminderLogModels.where().sortByCreatedAtDesc().watch(
      fireImmediately: true,
    );
  }

  Future<void> deleteLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) async {
    final items = await _db.reminderLogModels
        .filter()
        .reminderTypeEqualTo(reminderType)
        .and()
        .reminderLocalIdEqualTo(reminderLocalId)
        .findAll();

    final ids = items.map((e) => e.id).toList();

    await _db.writeTxn(() async {
      await _db.reminderLogModels.deleteAll(ids);
    });
  }
}