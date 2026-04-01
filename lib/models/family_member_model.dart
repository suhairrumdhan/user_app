import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  String? id;
  String name;
  String? relation;
  String? gender;
  String? bloodType;
  DateTime? dateOfBirth;
  int? age;
  List<String> allergies;
  List<String> healthConditions;
  List<String> currentMedications;

  FamilyMemberModel({
    this.id,
    required this.name,
    this.relation,
    this.gender,
    this.bloodType,
    this.dateOfBirth,
    this.age,
    this.allergies = const [],
    this.healthConditions = const [],
    this.currentMedications = const [],
  });

  /// 🔹 تحويل من Firestore
  factory FamilyMemberModel.fromMap(String id, Map<String, dynamic> data) {
    return FamilyMemberModel(
      id: id,
      name: data['name'] ?? '',
      relation: data['relation'],
      gender: data['gender'],
      bloodType: data['bloodType'],
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'],
      allergies: List<String>.from(data['allergies'] ?? []),
      healthConditions: List<String>.from(data['healthConditions'] ?? []),
      currentMedications: List<String>.from(data['currentMedications'] ?? []),
    );
  }

  /// 🔹 تحويل إلى Firestore
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "relation": relation,
      "gender": gender,
      "bloodType": bloodType,
      "dateOfBirth": dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      "age": age,
      "allergies": allergies,
      "healthConditions": healthConditions,
      "currentMedications": currentMedications,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }

  /// 🔹 نسخ البيانات مع تحديث بعض الحقول
  FamilyMemberModel copyWith({
    String? name,
    String? relation,
    String? gender,
    String? bloodType,
    DateTime? dateOfBirth,
    int? age,
    List<String>? allergies,
    List<String>? healthConditions,
    List<String>? currentMedications,
  }) {
    return FamilyMemberModel(
      id: id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      allergies: allergies ?? this.allergies,
      healthConditions: healthConditions ?? this.healthConditions,
      currentMedications: currentMedications ?? this.currentMedications,
    );
  }
}