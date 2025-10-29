import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/models/user_model.dart';
import 'package:user_application/auth/user_repository.dart';

import '../services/image_upload_service.dart';

class UserController extends GetxController {
  // المتغير اللي يحفظ بيانات المستخدم
  var user = Rxn<UserModel>();

  // instance للـ Repository
  final UserRepository _userRepo = UserRepository.instance;


  @override
  void onInit() {
    super.onInit();
    // تحميل تلقائي عند فتح التطبيق إذا كان هناك مستخدم مسجل دخوله
    _loadCurrentUser();
  }

  // تحميل المستخدم الحالي تلقائياً
  void _loadCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await loadUser(currentUser.uid);
    }
  }

  // جلب بيانات المستخدم من Firestore وتخزينها في الـ Controller
  Future<void> loadUser(String uid) async {
    try {
      UserModel? fetchedUser = await _userRepo.getUser(uid);
      if (fetchedUser != null) {
        user.value = fetchedUser;
      } else {
        print("المستخدم غير موجود في Firestore");
      }
    } catch (e) {
      print("خطأ في تحميل بيانات المستخدم: $e");
    }
  }

  // تحديث بيانات المستخدم محليًا (مثلاً بعد تعديل في Profile)
  void setUser(UserModel newUser) {
    user.value = newUser;
  }

  // مسح بيانات المستخدم عند تسجيل الخروج
  void clearUser() {
    user.value = null;
  }

  // التحقق إذا كانت معلومات المستخدم الصحية مكتملة
  Future<bool> isHealthInfoComplete() async {
    if (user.value == null) return false;
    return await _userRepo.isHealthInfoComplete(user.value!.id);
  }

  // التحقق إذا كان المستخدم موجود مسبقًا
  Future<bool> checkUserExists() async {
    if (user.value == null) return false;
    return await _userRepo.checkUserExists(user.value!.id);
  }
}

// ------------------- Extension لتحديث البيانات -------------------
extension UserControllerExtensions on UserController {
  Future<void> updateHealthInfo({
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
    String? phone,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
  }) async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل في الـ Controller');
      throw Exception('لم يتم تحميل بيانات المستخدم في الـ Controller');
    }

    try {
      final currentUser = user.value!;

      // 1. تحديث البيانات محلياً
      final updatedUser = currentUser.copyWith(
        bloodType: bloodType,
        gender: gender,
        dateOfBirth: dateOfBirth,
        phone: phone,
        healthConditions: healthConditions,
        allergies: allergies,
        currentMedications: currentMedications,
        healthInfoCompleted: true,
      );

      print('🔄 جاري حفظ البيانات الصحية في Firestore...');
      print('📊 البيانات: ${updatedUser.toJson()}');

      // 2. حفظ في Firestore
      await _userRepo.saveUser(updatedUser);

      // 3. تحديث الـ Controller بالبيانات الجديدة
      user.value = updatedUser;

      print('✅ تم حفظ البيانات الصحية بنجاح في Firestore');

    } catch (e) {
      print('❌ خطأ في حفظ البيانات الصحية: $e');
      rethrow;
    }
  }
  Future<void> updateProfileImage(File imageFile) async {
    if (user.value == null) {
      throw Exception('لم يتم تحميل بيانات المستخدم');
    }

    try {
      final userId = user.value!.id;

      // رفع الصورة
      final String? imageUrl = await ImageUploadService().uploadProfileImage(imageFile, userId);

      if (imageUrl != null) {
        // تحديث بيانات المستخدم
        final updatedUser = user.value!.copyWith(profileImageUrl: imageUrl);
        await _userRepo.saveUser(updatedUser);
        user.value = updatedUser;

        print('✅ تم تحديث صورة الملف الشخصي بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في تحديث صورة الملف الشخصي: $e');
      rethrow;
    }
  }

  Future<void> removeProfileImage() async {
    if (user.value == null) return;

    try {
      final userId = user.value!.id;

      // حذف الصورة من Storage
      await ImageUploadService().deleteProfileImage(userId);

      // تحديث بيانات المستخدم
      final updatedUser = user.value!.copyWith(profileImageUrl: null);
      await _userRepo.saveUser(updatedUser);
      user.value = updatedUser;

      print('✅ تم حذف صورة الملف الشخصي بنجاح');
    } catch (e) {
      print('❌ خطأ في حذف صورة الملف الشخصي: $e');
      rethrow;
    }
  }
  Future<bool> updateUserProfileImage() async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل في الـ Controller');
      return false;
    }

    try {
      final userId = user.value!.id;
      print('🔄 جاري تحديث صورة الملف الشخصي...');

      // اختيار صورة جديدة من المعرض
      final File? newImage = await ImageUploadService().pickImage();
      if (newImage == null) {
        print('⚠️ لم يتم اختيار أي صورة');
        return false;
      }

      // رفع الصورة إلى Firebase Storage
      final String? imageUrl = await ImageUploadService().uploadProfileImage(newImage, userId);

      if (imageUrl != null) {
        // تحديث بيانات المستخدم في Firestore
        await UserRepository.instance.updateUserFields(userId, {
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // تحديث الـ Controller محلياً
        final updatedUser = user.value!.copyWith(profileImageUrl: imageUrl);
        user.value = updatedUser;

        print('✅ تم تحديث صورة الملف الشخصي بنجاح');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ خطأ في تحديث صورة الملف الشخصي: $e');
      return false;
    }
  }

  Future<bool> captureProfileImage() async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل في الـ Controller');
      return false;
    }

    try {
      final userId = user.value!.id;
      print('🔄 جاري التقاط صورة جديدة...');

      // التقاط صورة بالكاميرا
      final File? capturedImage = await ImageUploadService().captureImage();
      if (capturedImage == null) {
        print('⚠️ لم يتم التقاط أي صورة');
        return false;
      }

      // رفع الصورة إلى Firebase Storage
      final String? imageUrl = await ImageUploadService().uploadProfileImage(capturedImage, userId);

      if (imageUrl != null) {
        // تحديث بيانات المستخدم في Firestore
        await UserRepository.instance.updateUserFields(userId, {
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // تحديث الـ Controller محلياً
        final updatedUser = user.value!.copyWith(profileImageUrl: imageUrl);
        user.value = updatedUser;

        print('✅ تم تحديث صورة الملف الشخصي بنجاح');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ خطأ في التقاط صورة الملف الشخصي: $e');
      return false;
    }
  }

  Future<bool> removeUserProfileImage() async {
    if (user.value == null) return false;

    try {
      final userId = user.value!.id;

      // حذف الصورة من Storage
      await ImageUploadService().deleteProfileImage(userId);

      // تحديث بيانات المستخدم في Firestore
      await UserRepository.instance.updateUserFields(userId, {
        'profileImageUrl': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // تحديث الـ Controller محلياً
      final updatedUser = user.value!.copyWith(profileImageUrl: null);
      user.value = updatedUser;

      print('✅ تم حذف صورة الملف الشخصي بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف صورة الملف الشخصي: $e');
      return false;
    }
  }
}

