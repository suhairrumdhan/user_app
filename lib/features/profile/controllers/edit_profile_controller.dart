import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/services/user_repository.dart';
import 'user_controller.dart';

class EditProfileController extends GetxController {
  final UserController userController = Get.find<UserController>();
  final UserRepository _userRepo = UserRepository.instance;

  final formKey = GlobalKey<FormState>();

  var isLoading = false.obs;

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  var showCurrentPassword = false.obs;
  var showPassword = false.obs;
  var showConfirmPassword = false.obs;

  var isPersonalInfoExpanded = false.obs;
  var isPasswordExpanded = false.obs;

  @override
  void onInit() {
    final user = userController.user.value;

    nameController = TextEditingController(text: user?.name ?? '');
    emailController = TextEditingController(text: user?.email ?? '');
    phoneController = TextEditingController(text: user?.phone ?? '');

    super.onInit();
  }

  Future<bool> verifyCurrentPassword(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> saveChanges() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userModel = userController.user.value;

      if (user == null || userModel == null) return;

      final newName = nameController.text.trim();
      final newEmail = emailController.text.trim();
      final newPhone = phoneController.text.trim();

      final currentPassword = currentPasswordController.text.trim();
      final newPassword = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();

      // تحديث البيانات
      if (newName != userModel.name) {
        await _userRepo.updateUserFields(userModel.id, {'name': newName});
        await user.updateDisplayName(newName);
      }

      if (newEmail != userModel.email) {
        await user.updateEmail(newEmail);
        await _userRepo.updateUserFields(userModel.id, {'email': newEmail});
      }

      if (newPhone != userModel.phone) {
        await _userRepo.updateUserFields(userModel.id, {'phone': newPhone});
      }

      // كلمة المرور
      if (isPasswordExpanded.value && newPassword.isNotEmpty) {
        if (currentPassword.isEmpty) {
          Get.snackbar('خطأ', 'يرجى إدخال كلمة المرور الحالية');
          return;
        }

        if (newPassword != confirmPassword) {
          Get.snackbar('خطأ', 'كلمة المرور غير متطابقة');
          return;
        }

        final valid = await verifyCurrentPassword(currentPassword);
        if (!valid) {
          Get.snackbar('خطأ', 'كلمة المرور الحالية غير صحيحة');
          return;
        }

        await user.updatePassword(newPassword);
      }

      await userController.loadUser(userModel.id);

      Get.snackbar('نجاح', 'تم حفظ التغييرات ✅');
      Get.back();
    } catch (e) {
      Get.snackbar('خطأ', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}