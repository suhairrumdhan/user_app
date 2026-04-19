import 'package:isar/isar.dart';

part 'reminder_log_model.g.dart';

@collection
class ReminderLogModel {
  Id id = Isar.autoIncrement;

  /// medication أو appointment
  @Index()
  late String reminderType;

  /// id من Isar
  @Index()
  late int reminderLocalId;

  @Index()
  late String ownerBeneficiaryId;

  late String ownerName;

  late DateTime scheduledAt;
  DateTime? actionAt;

  /// taken | snoozed | skipped | missed | opened
  @Index()
  late String actionType;

  String? title;
  String? notes;

  late DateTime createdAt;
}