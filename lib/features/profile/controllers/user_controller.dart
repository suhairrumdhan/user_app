import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/features/profile/models/user_model.dart';
import 'package:user_application/features/auth/services/user_repository.dart';

import '../../../app/core/services/image_upload_service.dart';

class UserController extends GetxController {
  // المتغير اللي يحفظ بيانات المستخدم (Rx للتفاعلية)
  final Rx<UserModel?> user = Rx<UserModel?>(null);

  // مؤشر التحميل
  final RxBool isLoading = false.obs;

  // instance للـ Repository
  final UserRepository _userRepo = UserRepository.instance;

  @override
  void onInit() {
    super.onInit();
    // تحميل تلقائي عند فتح التطبيق إذا كان هناك مستخدم مسجل دخوله
    // _loadCurrentUser();
  }

  // تحميل المستخدم الحالي تلقائياً
  // void _loadCurrentUser() async {
  //   final currentUser = FirebaseAuth.instance.currentUser;
  //   if (currentUser != null) {
  //     await loadUser(currentUser.uid);
  //   }
  // }

  // جلب بيانات المستخدم من Firestore وتخزينها في الـ Controller
  Future<void> loadUser(String uid) async {
    try {
      isLoading.value = true;
      UserModel? fetchedUser = await _userRepo.getUser(uid);
      if (fetchedUser != null) {
        user.value = fetchedUser;
        print('✅ تم تحميل بيانات المستخدم بنجاح');
      } else {
        print("⚠️ المستخدم غير موجود في Firestore");
      }
    } catch (e) {
      print("❌ خطأ في تحميل بيانات المستخدم: $e");
    } finally {
      isLoading.value = false;
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

  // تحديث السجلات الصحية (الطريقة الموحدة)
  Future<void> updateHealthRecords({
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? currentMedications,
  }) async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل');
      throw Exception('لم يتم تحميل بيانات المستخدم');
    }

    try {
      isLoading.value = true;

      final currentUserId = user.value!.id;
      final Map<String, dynamic> updateData = {};

      if (healthConditions != null) {
        updateData['healthConditions'] = healthConditions;
      }
      if (allergies != null) {
        updateData['allergies'] = allergies;
      }
      if (currentMedications != null) {
        updateData['currentMedications'] = currentMedications;
      }

      if (updateData.isNotEmpty) {
        // تحديث في Firestore
        await _userRepo.updateUserFields(currentUserId, updateData);

        // تحديث البيانات محلياً
        final updatedUser = user.value!.copyWith(
          healthConditions: healthConditions ?? user.value!.healthConditions,
          allergies: allergies ?? user.value!.allergies,
          currentMedications: currentMedications ?? user.value!.currentMedications,
        );

        user.value = updatedUser;

        print('✅ تم تحديث السجل الصحي بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في تحديث السجل الصحي: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث المعلومات الإضافية
  Future<void> updateAdditionalHealthInfo({
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
    String? phone,
  }) async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل');
      throw Exception('لم يتم تحميل بيانات المستخدم');
    }

    try {
      isLoading.value = true;

      final currentUserId = user.value!.id;
      final Map<String, dynamic> updateData = {};

      if (bloodType != null && bloodType.isNotEmpty) {
        updateData['bloodType'] = bloodType;
      }
      if (gender != null && gender.isNotEmpty) {
        updateData['gender'] = gender;
      }
      if (dateOfBirth != null) {
        updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      }
      if (phone != null && phone.isNotEmpty) {
        updateData['phone'] = phone;
      }

      if (updateData.isNotEmpty) {
        // تحديث في Firestore
        await _userRepo.updateUserFields(currentUserId, updateData);

        // تحديث البيانات محلياً
        final updatedUser = user.value!.copyWith(
          bloodType: bloodType ?? user.value!.bloodType,
          gender: gender ?? user.value!.gender,
          dateOfBirth: dateOfBirth ?? user.value!.dateOfBirth,
          phone: phone ?? user.value!.phone,
        );

        user.value = updatedUser;

        print('✅ تم تحديث المعلومات الإضافية بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في تحديث المعلومات الإضافية: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث جميع المعلومات الصحية دفعة واحدة
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
      isLoading.value = true;

      print('🔄 جاري حفظ البيانات الصحية في Firestore...');

      // 1. تحديث البيانات محلياً
      final updatedUser = user.value!.copyWith(
        bloodType: bloodType,
        gender: gender,
        dateOfBirth: dateOfBirth,
        phone: phone,
        healthConditions: healthConditions,
        allergies: allergies,
        currentMedications: currentMedications,
        healthInfoCompleted: true,
      );

      // 2. حفظ في Firestore
      await _userRepo.saveUser(updatedUser);

      // 3. تحديث الـ Controller بالبيانات الجديدة
      user.value = updatedUser;

      print('✅ تم حفظ البيانات الصحية بنجاح في Firestore');
    } catch (e) {
      print('❌ خطأ في حفظ البيانات الصحية: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // تحديث صورة الملف الشخصي
  Future<void> updateProfileImage(File imageFile) async {
    if (user.value == null) {
      throw Exception('لم يتم تحميل بيانات المستخدم');
    }

    try {
      isLoading.value = true;

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
    } finally {
      isLoading.value = false;
    }
  }

  // حذف صورة الملف الشخصي
  Future<void> removeProfileImage() async {
    if (user.value == null) return;

    try {
      isLoading.value = true;

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
    } finally {
      isLoading.value = false;
    }
  }

  // اختيار صورة من المعرض
  Future<bool> updateUserProfileImage() async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل في الـ Controller');
      return false;
    }

    try {
      isLoading.value = true;

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
        await _userRepo.updateUserFields(userId, {
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
    } finally {
      isLoading.value = false;
    }
  }

  // التقاط صورة بالكاميرا
  Future<bool> captureProfileImage() async {
    if (user.value == null) {
      print('❌ لا يوجد مستخدم محمل في الـ Controller');
      return false;
    }

    try {
      isLoading.value = true;

      final userId = user.value!.id;

      // التقاط صورة بالكاميرا
      final File? capturedImage = await ImageUploadService().captureImage();
      if (capturedImage == null) {
        return false;
      }

      // رفع الصورة إلى Firebase Storage
      final String? imageUrl = await ImageUploadService().uploadProfileImage(capturedImage, userId);

      if (imageUrl != null) {
        // تحديث بيانات المستخدم في Firestore
        await _userRepo.updateUserFields(userId, {
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
    } finally {
      isLoading.value = false;
    }
  }

  // حذف صورة الملف الشخصي
  Future<bool> removeUserProfileImage() async {
    if (user.value == null) return false;

    try {
      isLoading.value = true;

      final userId = user.value!.id;

      // حذف الصورة من Storage
      await ImageUploadService().deleteProfileImage(userId);

      // تحديث بيانات المستخدم في Firestore
      await _userRepo.updateUserFields(userId, {
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
    } finally {
      isLoading.value = false;
    }
  }
}