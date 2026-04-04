// lib/services/profile_image_service.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../features/profile/controllers/user_controller.dart';

class ProfileImageService {

  // عرض قائمة خيارات الصورة
  static void showImagePickerBottomSheet(BuildContext context, UserController userController) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'تغيير صورة الملف الشخصي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // خيار المعرض
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.blue.shade600),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _updateProfileImage(userController);
              },
            ),

            // خيار الكاميرا
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.green.shade600),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _captureProfileImage(userController);
              },
            ),

            // خيار الحذف (إذا كانت هناك صورة حالية)
            Obx(() {
              final hasImage = userController.user.value?.profileImageUrl != null;
              return hasImage
                  ? ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade600),
                title: const Text('حذف الصورة', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage(userController);
                },
              )
                  : const SizedBox.shrink();
            }),

            const SizedBox(height: 16),
            // زر الإلغاء
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تحديث الصورة من المعرض
  static Future<void> _updateProfileImage(UserController userController) async {
    try {
      final success = await userController.updateUserProfileImage();
      if (success) {
        _showSuccessSnackbar('تم تحديث صورة الملف الشخصي بنجاح');
      }
    } catch (e) {
      _showErrorSnackbar('فشل في تحديث الصورة: $e');
    }
  }

  // التقاط صورة بالكاميرا
  static Future<void> _captureProfileImage(UserController userController) async {
    try {
      final success = await userController.captureProfileImage();
      if (success) {
        _showSuccessSnackbar('تم تحديث الصورة بنجاح');
      }
    } catch (e) {
      _showErrorSnackbar('فشل في التقاط الصورة: $e');
    }
  }

  // حذف الصورة
  static Future<void> _removeProfileImage(UserController userController) async {
    try {
      final success = await userController.removeUserProfileImage();
      if (success) {
        _showSuccessSnackbar('تم حذف الصورة بنجاح');
      }
    } catch (e) {
      _showErrorSnackbar('فشل في حذف الصورة: $e');
    }
  }

  // عرض رسالة نجاح
  static void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'نجاح',
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // عرض رسالة خطأ
  static void _showErrorSnackbar(String message) {
    Get.snackbar(
      'خطأ',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}