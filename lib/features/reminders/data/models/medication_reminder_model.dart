import 'package:isar/isar.dart';
import 'reminder_owner_embedded.dart';

part 'medication_reminder_model.g.dart';

@collection
class MedicationReminderModel {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: true)
  String ownerUserId = '';

  @Index(caseSensitive: false)
  late String medicineName;

  String? dosage;
  String? route;
  String? notes;

  late ReminderOwnerEmbedded owner;

  late DateTime startDate;
  DateTime? endDate;

  /// مثال: ["08:00", "14:30", "21:00"]
  late List<String> times;

  /// IDs الخاصة بالإشعارات المجدولة لهذا التذكير
  late List<int> notificationIds;

  /// active | paused | completed | expired
  @Index()
  late String status;

  /// لو المستخدم حب يضيف الدواء للسجل الصحي
  bool saveToHealthRecord = false;

  DateTime? lastTakenAt;
  DateTime? lastSnoozedAt;

  late DateTime createdAt;
  DateTime? updatedAt;

  bool get isActive => status == 'active';
}
