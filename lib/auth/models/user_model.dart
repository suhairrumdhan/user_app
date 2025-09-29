import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  String name;
  String? email;
  String? phone;
  int? age;
  String? gender;
  String? bloodType;
  List<String> healthConditions;
  List<String> allergies;
  List<String> currentMedications;
  double? weight;
  double? height;
  DateTime createdAt;
  bool healthInfoCompleted;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.age,
    this.gender,
    this.bloodType,
    this.healthConditions = const [],
    this.allergies = const [],
    this.currentMedications = const [],
    this.weight,
    this.height,
    required this.createdAt,
    this.healthInfoCompleted = false,
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
    return UserModel(
      id: docId,
      name: json['name'] ?? 'مستخدم جديد',
      email: json['email'],
      phone: json['phone'],
      age: json['age'],
      gender: json['gender'],
      bloodType: json['bloodType'],
      healthConditions: List<String>.from(json['healthConditions'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      currentMedications: List<String>.from(json['currentMedications'] ?? []),
      weight: _safeDoubleConvert(json['weight']),
      height: _safeDoubleConvert(json['height']),
      createdAt: _safeTimestampConvert(json['createdAt']),
      healthInfoCompleted: json['healthInfoCompleted'] ?? false,
    );
  }

  static double? _safeDoubleConvert(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
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
      'age': age,
      'gender': gender,
      'bloodType': bloodType,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'currentMedications': currentMedications,
      'weight': weight,
      'height': height,
      'createdAt': Timestamp.fromDate(createdAt),
      'healthInfoCompleted': healthInfoCompleted,
    };
  }

  // Copy with method for easy updates
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    int? age,
    String? gender,
    String? bloodType,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
    double? weight,
    double? height,
    bool? healthInfoCompleted,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      currentMedications: currentMedications ?? this.currentMedications,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      createdAt: createdAt,
      healthInfoCompleted: healthInfoCompleted ?? this.healthInfoCompleted,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, healthInfoCompleted: $healthInfoCompleted)';
  }
}