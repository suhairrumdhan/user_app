import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:user_application/features/auth/services/user_repository.dart';
import 'package:user_application/features/profile/controllers/user_controller.dart';

import '../../../app/core/services/push_notification_service.dart';
import '../views/welcome_page.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepo = Get.find();
  final UserController _userController = Get.find();

  // حالة المستخدم
  var user = Rxn<User>();
  // حالة التحميل
  var isLoading = true.obs;
  var isGoogleLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final persistedUser = _auth.currentUser;
    user.value = persistedUser;
    isLoading.value = false;
    if (persistedUser != null) {
      unawaited(_userController.loadUser(persistedUser.uid));
    }
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? firebaseUser) {
    user.value = firebaseUser;
    isLoading.value = false;

    if (firebaseUser != null) {
      unawaited(_userController.loadUser(firebaseUser.uid));
    } else {
      _userController.clearUser();
    }
  }

  // التحقق من اكتمال المعلومات الصحية
  Future<bool> isHealthInfoComplete() async {
    if (user.value == null) return false;
    return await _userRepo.isHealthInfoComplete(user.value!.uid);
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await PushNotificationService.instance.unregisterCurrentDevice();
      await _auth.signOut();
      _userController.clearUser();
      Get.offAll(() => const WelcomeScreen());
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تسجيل الخروج: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // الحصول على UID المستخدم الحالي
  String? get currentUserId => user.value?.uid;

  // التحقق إذا كان المستخدم مسجل دخول
  bool get isLoggedIn => user.value != null;
}

extension AuthControllerExtensions on AuthController {
  // تحديث كلمة المرور
  Future<void> updatePassword(String newPassword) async {
    if (user.value == null) return;
    try {
      await user.value!.updatePassword(newPassword);
      Get.snackbar('نجاح', 'تم تحديث كلمة المرور بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث كلمة المرور: ${e.toString()}');
    }
  }

  // تحديث الصورة الشخصية
  Future<void> updatePhoto(String photoPath) async {
    if (user.value == null) return;
    try {
      // رفع الصورة إلى Firebase Storage لو موجود عندك
      // حالياً فقط نحدث الـ photoURL محليًا في FirebaseUser
      await user.value!.updatePhotoURL(photoPath);

      // تحديث في Firestore
      final uid = user.value!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': photoPath,
      });

      // إعادة تحميل المستخدم
      user.refresh();

      Get.snackbar('نجاح', 'تم تحديث الصورة الشخصية بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث الصورة: ${e.toString()}');
    }
  }
}
