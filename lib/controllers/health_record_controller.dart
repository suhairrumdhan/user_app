// controllers/health_record_controller.dart
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_controller.dart';
import '../auth/user_repository.dart';

class HealthRecordController extends GetxController {
  final UserController userController = Get.find<UserController>();
  final UserRepository _userRepo = UserRepository.instance;

  Future<void> updateHealthRecords({
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

      // كل الحقول optional - nullable
      if (bloodType != null && bloodType.isNotEmpty) {
        updateData['bloodType'] = bloodType;
      } else {
        updateData['bloodType'] = null; // أو احذفي هذا السطر إذا ما تبغيش تحذفي القيمة
      }

      if (gender != null && gender.isNotEmpty) {
        updateData['gender'] = gender;
      } else {
        updateData['gender'] = null;
      }

      if (dateOfBirth != null) {
        updateData['dateOfBirth'] = dateOfBirth;
      } else {
        updateData['dateOfBirth'] = null;
      }

      if (phone != null && phone.isNotEmpty) {
        updateData['phone'] = phone;
      } else {
        updateData['phone'] = null;
      }

      print('📝 بيانات التحديث: $updateData');

      await _userRepo.updateUserFields(currentUser.uid, updateData);
      await userController.loadUser(currentUser.uid);

      Get.snackbar('نجاح', 'تم تحديث المعلومات الإضافية بنجاح');
      print('✅ تم تحديث المعلومات الإضافية بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث المعلومات: $e');
      print('❌ خطأ في تحديث المعلومات: $e');
    }
  }

  List<String> parseItemsFromText(String text) {
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}