import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

User? user = FirebaseAuth.instance.currentUser;

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final int? age;
  final String? gender;
  final String? bloodType;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> currentMedications;
  final double? weight;
  final double? height;
  final DateTime createdAt;
  final bool healthInfoCompleted;

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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'مستخدم جديد',
      email: json['email'],
      phone: json['phone'],
      age: json['age'],
      gender: json['gender'],
      bloodType: json['bloodType'],
      healthConditions: List<String>.from(json['healthConditions'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      currentMedications: List<String>.from(json['currentMedications'] ?? []),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      healthInfoCompleted: json['healthInfoCompleted'] ?? false,
    );
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
}
