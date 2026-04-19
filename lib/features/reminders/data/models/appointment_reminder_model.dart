import 'package:isar/isar.dart';
import 'reminder_owner_embedded.dart';

part 'appointment_reminder_model.g.dart';

@collection
class AppointmentReminderModel {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String title;

  String? notes;
  String? location;

  late ReminderOwnerEmbedded owner;

  late DateTime appointmentDateTime;

  /// قبل الموعد بكم دقيقة
  int remindBeforeMinutes = 30;

  /// إشعار واحد غالبًا
  int? notificationId;

  /// active | paused | completed | expired
  @Index()
  late String status;

  /// لو المستخدم حب يضيف الموعد للسجل الصحي
  bool saveToHealthRecord = false;

  late DateTime createdAt;
  DateTime? updatedAt;

  bool get isActive => status == 'active';
}