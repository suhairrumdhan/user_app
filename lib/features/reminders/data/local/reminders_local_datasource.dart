import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';

import '../models/appointment_reminder_model.dart';
import '../models/medication_reminder_model.dart';
import '../models/reminder_log_model.dart';
import 'reminders_local_db.dart';

class RemindersLocalDataSource {
  Isar get _db => RemindersLocalDb.instance;

  String get _currentUserId {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('A signed-in user is required to access reminders.');
    }
    return uid;
  }

  // ========= Medication Reminders =========

  Future<int> addMedicationReminder(MedicationReminderModel reminder) async {
    reminder.ownerUserId = _currentUserId;
    return _db.writeTxn(() async {
      return _db.medicationReminderModels.put(reminder);
    });
  }

  Future<bool> updateMedicationReminder(
    MedicationReminderModel reminder,
  ) async {
    final uid = _currentUserId;
    if (reminder.ownerUserId != uid) return false;
    return _db.writeTxn(() async {
      final id = await _db.medicationReminderModels.put(reminder);
      return id > 0;
    });
  }

  Future<MedicationReminderModel?> getMedicationReminderById(int id) async {
    final item = await _db.medicationReminderModels.get(id);
    return item?.ownerUserId == _currentUserId ? item : null;
  }

  Future<List<MedicationReminderModel>> getAllMedicationReminders() {
    return _db.medicationReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<MedicationReminderModel>> getUnownedMedicationReminders() {
    return _db.medicationReminderModels.filter().ownerUserIdIsEmpty().findAll();
  }

  Future<List<MedicationReminderModel>> getMedicationRemindersByStatus(
    String status,
  ) {
    return _db.medicationReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .and()
        .statusEqualTo(status)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<MedicationReminderModel>> watchAllMedicationReminders() {
    return _db.medicationReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<MedicationReminderModel>> watchMedicationRemindersByStatus(
    String status,
  ) {
    return _db.medicationReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .and()
        .statusEqualTo(status)
        .watch(fireImmediately: true);
  }

  Future<void> deleteMedicationReminder(int id) async {
    final item = await getMedicationReminderById(id);
    if (item == null) return;
    await _db.writeTxn(() async {
      await _db.medicationReminderModels.delete(id);
    });
  }

  // ========= Appointment Reminders =========

  Future<int> addAppointmentReminder(AppointmentReminderModel reminder) async {
    reminder.ownerUserId = _currentUserId;
    return _db.writeTxn(() async {
      return _db.appointmentReminderModels.put(reminder);
    });
  }

  Future<bool> updateAppointmentReminder(
    AppointmentReminderModel reminder,
  ) async {
    final uid = _currentUserId;
    if (reminder.ownerUserId != uid) return false;
    return _db.writeTxn(() async {
      final id = await _db.appointmentReminderModels.put(reminder);
      return id > 0;
    });
  }

  Future<AppointmentReminderModel?> getAppointmentReminderById(int id) async {
    final item = await _db.appointmentReminderModels.get(id);
    return item?.ownerUserId == _currentUserId ? item : null;
  }

  Future<List<AppointmentReminderModel>> getAllAppointmentReminders() {
    return _db.appointmentReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<AppointmentReminderModel>> getUnownedAppointmentReminders() {
    return _db.appointmentReminderModels
        .filter()
        .ownerUserIdIsEmpty()
        .findAll();
  }

  Future<List<AppointmentReminderModel>> getAppointmentRemindersByStatus(
    String status,
  ) {
    return _db.appointmentReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .and()
        .statusEqualTo(status)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<AppointmentReminderModel>> watchAllAppointmentReminders() {
    return _db.appointmentReminderModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteAppointmentReminder(int id) async {
    final item = await getAppointmentReminderById(id);
    if (item == null) return;
    await _db.writeTxn(() async {
      await _db.appointmentReminderModels.delete(id);
    });
  }

  // ========= Reminder Logs =========

  Future<int> addLog(ReminderLogModel log) async {
    log.ownerUserId = _currentUserId;
    return _db.writeTxn(() async {
      return _db.reminderLogModels.put(log);
    });
  }

  Future<bool> recordMedicationAction({
    required MedicationReminderModel reminder,
    required String action,
    required DateTime actionAt,
    Duration duplicateWindow = const Duration(seconds: 30),
  }) async {
    final uid = _currentUserId;
    return _db.writeTxn(() async {
      final duplicate = await _db.reminderLogModels
          .filter()
          .ownerUserIdEqualTo(uid)
          .and()
          .reminderTypeEqualTo('medication')
          .and()
          .reminderLocalIdEqualTo(reminder.id)
          .and()
          .actionTypeEqualTo(action)
          .and()
          .createdAtGreaterThan(actionAt.subtract(duplicateWindow))
          .findFirst();
      if (duplicate != null) return false;

      final stored = await _db.medicationReminderModels.get(reminder.id);
      if (stored == null || stored.ownerUserId != uid) return false;

      if (action == 'taken') {
        stored.lastTakenAt = actionAt;
      } else if (action == 'snoozed') {
        stored.lastSnoozedAt = actionAt;
      }
      stored.updatedAt = actionAt;
      await _db.medicationReminderModels.put(stored);

      final log = ReminderLogModel()
        ..ownerUserId = uid
        ..reminderType = 'medication'
        ..reminderLocalId = stored.id
        ..ownerBeneficiaryId = stored.owner.beneficiaryId
        ..ownerName = stored.owner.name
        ..actionType = action
        ..scheduledAt = actionAt
        ..actionAt = actionAt
        ..title = stored.medicineName
        ..createdAt = actionAt;
      await _db.reminderLogModels.put(log);
      return true;
    });
  }

  Future<List<ReminderLogModel>> getAllLogs() {
    return _db.reminderLogModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<ReminderLogModel>> getLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) {
    return _db.reminderLogModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .and()
        .reminderTypeEqualTo(reminderType)
        .and()
        .reminderLocalIdEqualTo(reminderLocalId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Stream<List<ReminderLogModel>> watchAllLogs() {
    return _db.reminderLogModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteLogsByReminder({
    required String reminderType,
    required int reminderLocalId,
  }) async {
    final items = await _db.reminderLogModels
        .filter()
        .ownerUserIdEqualTo(_currentUserId)
        .and()
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
