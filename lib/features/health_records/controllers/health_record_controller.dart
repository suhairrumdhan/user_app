// controllers/health_record_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile/controllers/user_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../auth/services/user_repository.dart';

class HealthRecordController extends GetxController {
  final UserController userController = Get.find<UserController>();
  final FamilyController familyController = Get.find<FamilyController>();
  final UserRepository _userRepo = UserRepository.instance;

  // إضافة Rx للتحديثات
  final RxBool isUpdating = false.obs;

  // تحديث سجل المستخدم
  Future<void> updateUserHealthRecords({
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
    String? bloodType, // Added bloodType parameter
  }) async {
    try {
      isUpdating.value = true;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final Map<String, dynamic> updateData = {};

      if (healthConditions != null) updateData['healthConditions'] = healthConditions;
      if (allergies != null) updateData['allergies'] = allergies;
      if (currentMedications != null) updateData['currentMedications'] = currentMedications;
      if (bloodType != null && bloodType.isNotEmpty) updateData['bloodType'] = bloodType; // Added bloodType

      await _userRepo.updateUserFields(currentUser.uid, updateData);

      // إعادة تحميل بيانات المستخدم
      await userController.loadUser(currentUser.uid);

      // تحديث الـ UI تلقائياً
      userController.user.refresh();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث السجل الصحي: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  // تحديث سجل فرد العائلة
  Future<void> updateFamilyMemberHealthRecords({
    required String memberId,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
    String? bloodType, // Added bloodType parameter
  }) async {
    try {
      isUpdating.value = true;

      final Map<String, dynamic> updateData = {};

      if (healthConditions != null) updateData['healthConditions'] = healthConditions;
      if (allergies != null) updateData['allergies'] = allergies;
      if (currentMedications != null) updateData['currentMedications'] = currentMedications;
      if (bloodType != null && bloodType.isNotEmpty) updateData['bloodType'] = bloodType; // Added bloodType

      await familyController.updateMemberHealthRecords(memberId, updateData);

      // تحديث الـ UI تلقائياً (بفضل الـ Observable في FamilyController)
      familyController.refresh();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث السجل الصحي: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  // تحديث معلومات إضافية للمستخدم
  Future<void> updateAdditionalHealthInfo({
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? weight,
    String? height,
    String? chronicDiseases,
  }) async {
    try {
      isUpdating.value = true;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final Map<String, dynamic> updateData = {};

      if (bloodType != null && bloodType.isNotEmpty) {
        updateData['bloodType'] = bloodType;
      }
      if (gender != null && gender.isNotEmpty) {
        updateData['gender'] = gender;
      }
      if (dateOfBirth != null) {
        updateData['dateOfBirth'] = dateOfBirth.toIso8601String();
      }
      if (phone != null && phone.isNotEmpty) {
        updateData['phone'] = phone;
      }
      if (weight != null && weight.isNotEmpty) {
        updateData['weight'] = weight;
      }
      if (height != null && height.isNotEmpty) {
        updateData['height'] = height;
      }
      if (chronicDiseases != null && chronicDiseases.isNotEmpty) {
        updateData['chronicDiseases'] = chronicDiseases;
      }

      await _userRepo.updateUserFields(currentUser.uid, updateData);
      await userController.loadUser(currentUser.uid);
      userController.user.refresh();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث المعلومات: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  // دالة لتحديث فصيلة الدم فقط للمستخدم
  Future<void> updateUserBloodType(String bloodType) async {
    try {
      isUpdating.value = true;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final Map<String, dynamic> updateData = {
        'bloodType': bloodType,
      };

      await _userRepo.updateUserFields(currentUser.uid, updateData);
      await userController.loadUser(currentUser.uid);
      userController.user.refresh();


    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث فصيلة الدم: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  // دالة لتحديث فصيلة الدم لفرد العائلة
  Future<void> updateFamilyMemberBloodType({
    required String memberId,
    required String bloodType,
  }) async {
    try {
      isUpdating.value = true;

      final Map<String, dynamic> updateData = {
        'bloodType': bloodType,
      };

      await familyController.updateMemberHealthRecords(memberId, updateData);
      familyController.refresh();


    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث فصيلة الدم: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isUpdating.value = false;
    }
  }

  // دالة لتحويل النص إلى قائمة عناصر (للاستخدام مع الفاصلة إذا أردت)
  List<String> parseItemsFromText(String text) {
    if (text.isEmpty) return [];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  // دالة لتحويل القائمة إلى نص مفصول بفاصلة
  String parseItemsToListText(List<String> items) {
    return items.join(', ');
  }

  // دالة للتحقق من صحة فصيلة الدم
  bool isValidBloodType(String bloodType) {
    const validTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return validTypes.contains(bloodType);
  }
}