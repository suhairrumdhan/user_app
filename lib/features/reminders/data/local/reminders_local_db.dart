import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/appointment_reminder_model.dart';
import '../models/medication_reminder_model.dart';
import '../models/reminder_log_model.dart';

class RemindersLocalDb {
  RemindersLocalDb._();

  static Isar? _isar;

  static Future<Isar> init() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        MedicationReminderModelSchema,
        AppointmentReminderModelSchema,
        ReminderLogModelSchema,
      ],
      directory: dir.path,
      inspector: true,
      name: 'health_reminders_db',
    );

    return _isar!;
  }

  static Isar get instance {
    final db = _isar;
    if (db == null) {
      throw StateError(
        'RemindersLocalDb not initialized. Call RemindersLocalDb.init() first.',
      );
    }
    return db;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}