import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  String name;
  String? email;
  String? phone;
  DateTime? dateOfBirth;
  String? gender;
  String? bloodType;
  List<String> healthConditions;
  List<String> allergies;
  List<String> currentMedications;
  DateTime createdAt;
  bool healthInfoCompleted;
  String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.healthConditions = const [],
    this.allergies = const [],
    this.currentMedications = const [],
    required this.createdAt,
    this.healthInfoCompleted = false,
    this.profileImageUrl,
  });

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName ?? 'مستخدم جديد',
      email: user.email,
      phone: user.phoneNumber,
      createdAt: DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    try {
      return UserModel(
        id: docId,
        name: json['name']?.toString() ?? 'مستخدم جديد',
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        dateOfBirth: _safeDateConvert(json['dateOfBirth']),
        gender: json['gender']?.toString(),
        bloodType: json['bloodType']?.toString(),
        healthConditions: _safeListConvert(json['healthConditions']),
        allergies: _safeListConvert(json['allergies']),
        currentMedications: _safeListConvert(json['currentMedications']),
        createdAt: _safeTimestampConvert(json['createdAt']),
        healthInfoCompleted: json['healthInfoCompleted'] == true,
        profileImageUrl: json['profileImageUrl']?.toString(),
      );
    } catch (e) {
      print('❌ خطأ في تحويل JSON إلى UserModel: $e');
      print('📊 البيانات المستلمة: $json');
      rethrow;
    }
  }

  // Helper: يحول أي بيانات إلى List<String> بشكل آمن
  static List<String> _safeListConvert(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  // Helper: يحول أي شكل ممكن لتاريخ إلى DateTime?
  static DateTime? _safeDateConvert(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static DateTime _safeTimestampConvert(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'bloodType': bloodType,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'currentMedications': currentMedications,
      'createdAt': Timestamp.fromDate(createdAt),
      'healthInfoCompleted': healthInfoCompleted,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Copy with method for easy updates
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
    bool? healthInfoCompleted,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      currentMedications: currentMedications ?? this.currentMedications,
      createdAt: createdAt,
      healthInfoCompleted: healthInfoCompleted ?? this.healthInfoCompleted,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, healthInfoCompleted: $healthInfoCompleted)';
  }
}