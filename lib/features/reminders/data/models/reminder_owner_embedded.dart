import 'package:isar/isar.dart';
import '../../../prescription/models/beneficiary_model.dart';
part 'reminder_owner_embedded.g.dart';

@embedded
class ReminderOwnerEmbedded {
  late String beneficiaryId;
  late String name;
  late String type; // self | family
  late String relation;

  ReminderOwnerEmbedded();

  factory ReminderOwnerEmbedded.fromBeneficiary(BeneficiaryModel beneficiary) {
    return ReminderOwnerEmbedded()
      ..beneficiaryId = beneficiary.id
      ..name = beneficiary.name
      ..type = beneficiary.type
      ..relation = beneficiary.relation;
  }
}