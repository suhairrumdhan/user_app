// controllers/health_record_controller.dart
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_controller.dart';
import 'family_controller.dart';
import '../auth/user_repository.dart';

class HealthRecordController extends GetxController {
  final UserController userController = Get.find<UserController>();
  final FamilyController familyController = Get.find<FamilyController>();
  final UserRepository _userRepo = UserRepository.instance;

  // تحديث سجل المستخدم
  Future<void> updateUserHealthRecords({
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final Map<String, dynamic> updateData = {};

      if (healthConditions != null) updateData['healthConditions'] = healthConditions;
      if (allergies != null) updateData['allergies'] = allergies;
      if (currentMedications != null) updateData['currentMedications'] = currentMedications;

      await _userRepo.updateUserFields(currentUser.uid, updateData);
      await userController.loadUser(currentUser.uid);

      Get.snackbar('نجاح', 'تم تحديث السجل الصحي بنجاح');
      print('✅ تم تحديث السجل الصحي بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث السجل الصحي: $e');
      print('❌ خطأ في تحديث السجل الصحي: $e');
    }
  }

  // تحديث سجل فرد العائلة
  Future<void> updateFamilyMemberHealthRecords({
    required String memberId,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (healthConditions != null) updateData['healthConditions'] = healthConditions;
      if (allergies != null) updateData['allergies'] = allergies;
      if (currentMedications != null) updateData['currentMedications'] = currentMedications;

      await familyController.updateMemberHealthRecords(memberId, updateData);

      Get.snackbar('نجاح', 'تم تحديث السجل الصحي للفرد بنجاح');
      print('✅ تم تحديث السجل الصحي للفرد بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث السجل الصحي: $e');
      print('❌ خطأ في تحديث السجل الصحي: $e');
    }
  }

  // تحديث معلومات إضافية للمستخدم
  Future<void> updateAdditionalHealthInfo({
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
    String? phone,
  }) async {
    try {
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
        updateData['dateOfBirth'] = dateOfBirth;
      }
      if (phone != null && phone.isNotEmpty) {
        updateData['phone'] = phone;
      }

      await _userRepo.updateUserFields(currentUser.uid, updateData);
      await userController.loadUser(currentUser.uid);

      Get.snackbar('نجاح', 'تم تحديث المعلومات الإضافية بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث المعلومات: $e');
    }
  }

  List<String> parseItemsFromText(String text) {
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}