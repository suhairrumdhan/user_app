import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  String id;
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
    this.id = "",
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
  Map<String, dynamic> toMap({bool includeCreatedAt = true}) {
    return {
      "name": name,
      "relation": relation,
      "gender": gender,
      "bloodType": bloodType,
      "dateOfBirth": dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      "age": age,
      "allergies": allergies,
      "healthConditions": healthConditions,
      "currentMedications": currentMedications,
      if (includeCreatedAt) "createdAt": FieldValue.serverTimestamp(),
    };
  }

  /// 🔹 نسخ البيانات مع تحديث بعض الحقول
  FamilyMemberModel copyWith({
    String? id,
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
      id: id ?? this.id,
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

  /// 🔹 دالة مساعدة للحصول على فصيلة الدم بشكل نصي
  String getBloodTypeDisplay() {
    return bloodType ?? 'غير محدد';
  }

  /// 🔹 دالة للتحقق من وجود فصيلة دم
  bool hasBloodType() {
    return bloodType != null && bloodType!.isNotEmpty;
  }

  /// 🔹 دالة للحصول على قائمة الأمراض المزمنة (مرادف للحالات الصحية)
  List<String> getChronicDiseases() {
    return healthConditions;
  }

  /// 🔹 دالة للتحقق من وجود حساسية معينة
  bool hasAllergy(String allergen) {
    return allergies.contains(allergen);
  }

  /// 🔹 دالة للتحقق من وجود دواء معين
  bool isTakingMedication(String medication) {
    return currentMedications.contains(medication);
  }

  /// 🔹 دالة للحصول على العمر بشكل نصي
  String getAgeDisplay() {
    if (age == null) return 'غير محدد';
    return '$age سنة';
  }

  /// 🔹 دالة للحصول على تاريخ الميلاد بشكل نصي
  String getDateOfBirthDisplay() {
    if (dateOfBirth == null) return 'غير محدد';
    return '${dateOfBirth!.year}/${dateOfBirth!.month}/${dateOfBirth!.day}';
  }

  /// 🔹 دالة للتحقق من صحة البيانات قبل الحفظ
  bool isValid() {
    return name.isNotEmpty;
  }

  /// 🔹 دالة للحصول على ملخص صحي للنموذج
  Map<String, dynamic> getHealthSummary() {
    return {
      'bloodType': bloodType,
      'allergies': allergies,
      'healthConditions': healthConditions,
      'currentMedications': currentMedications,
      'age': age,
      'gender': gender,
    };
  }
}
