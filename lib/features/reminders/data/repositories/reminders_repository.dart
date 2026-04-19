import '../local/reminders_local_datasource.dart';
import '../models/appointment_reminder_model.dart';
import '../models/medication_reminder_model.dart';
import '../models/reminder_log_model.dart';

class RemindersRepository {
  final RemindersLocalDataSource _local;

  RemindersRepository({RemindersLocalDataSource? local})
      : _local = local ?? RemindersLocalDataSource();

  // ========= Medication =========

  Future<int> addMedicationReminder(MedicationReminderModel reminder) {
    return _local.addMedicationReminder(reminder);
  }

  Future<bool> updateMedicationReminder(MedicationReminderModel reminder) {
    return _local.updateMedicationReminder(reminder);
  }

  Future<MedicationReminderModel?> getMedicationReminderById(int id) {
    return _local.getMedicationReminderById(id);
  }

  Future<List<MedicationReminderModel>> getAllMedicationReminders() {
    return _local.getAllMedicationReminders();
  }

  Future<List<MedicationReminderModel>> getMedicationRemindersByStatus(
      String status,
      ) {
    return _local.getMedicationRemindersByStatus(status);
  }

  Stream<List<MedicationReminderModel>> watchAllMedicationReminders() {
    return _local.watchAllMedicationReminders();
  }

  Stream<List<MedicationReminderModel>> watchMedicationRemindersByStatus(
      String status,
      ) {
    return _local.watchMedicationRemindersByStatus(status);
  }

  Future<void> deleteMedicationReminder(int id) {
    return _local.deleteMedicationReminder(id);
  }

  // ========= Appointment =========

  Future<int> addAppointmentReminder(AppointmentReminderModel reminder) {
    return _local.addAppointmentReminder(reminder);
  }

  Future<bool> updateAppointmentReminder(AppointmentReminderModel reminder) {
    return _local.updateAppointmentReminder(reminder);
  }

  Future<AppointmentReminderModel?> getAppointmentReminderById(int id) {
    return _local.getAppointmentReminderById(id);
  }

  Future<List<AppointmentReminderModel>> getAllAppointmentReminders() {
    return _local.getAllAppointmentReminders();
  }

  Future<List<AppointmentReminderModel>> getAppointmentRemindersByStatus(
      String status,
      ) {
    return _local.getAppointmentRemindersByStatus(status);
  }

  Stream<List<AppointmentReminderModel>> watchAllAppointmentReminders() {
    return _local.watchAllAppointmentReminders();
  }

  Future<void> deleteAppointmentReminder(int id) {
    return _local.deleteAppointmentReminder(id);
  }

  // ========= Logs =========

  Future<int> addLog(ReminderLogModel log) {
    return _local.addLog(log);
  }

  Future<List<ReminderLogModel>> getAllLogs() {
    return _local.getAllLogs();
  }

  Future<List<ReminderLogModel>> getLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) {
    return _local.getLogsByReminder(
      reminderType: reminderType,
      reminderLocalId: reminderLocalId,
    );
  }

  Stream<List<ReminderLogModel>> watchAllLogs() {
    return _local.watchAllLogs();
  }

  Future<void> deleteLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) {
    return _local.deleteLogsByReminder(
      reminderType: reminderType,
      reminderLocalId: reminderLocalId,
    );
  }
}