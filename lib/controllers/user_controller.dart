import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:user_application/auth/models/user_model.dart';
import 'package:user_application/auth/user_repository.dart';

class UserController extends GetxController {
  // المتغير اللي يحفظ بيانات المستخدم
  var user = Rxn<UserModel>();

  // instance للـ Repository
  final UserRepository _userRepo = UserRepository.instance;

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
  // تحديث الاسم
  Future<void> updateName(String newName) async {
    if (user.value == null) return; // نتأكد أن user مش null

    // ناخذ نسخة آمنة
    final currentUser = user.value!;

    final updatedUser = UserModel(
      id: currentUser.id,
      name: newName,
      email: currentUser.email,
      phone: currentUser.phone,
      age: currentUser.age,
      gender: currentUser.gender,
      bloodType: currentUser.bloodType,
      healthConditions: currentUser.healthConditions,
      allergies: currentUser.allergies,
      currentMedications: currentUser.currentMedications,
      weight: currentUser.weight,
      height: currentUser.height,
      createdAt: currentUser.createdAt,
      healthInfoCompleted: currentUser.healthInfoCompleted,
    );

    user.value = updatedUser; // نحدث الـ Rx
    await UserRepository.instance.saveUser(updatedUser);

    Get.snackbar('نجاح', 'تم تحديث الاسم بنجاح');
  }


  // تحديث البريد الإلكتروني
  Future<void> updateEmail(String newEmail) async {
    if (user.value == null) return;

    final currentUser = user.value!;

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updateEmail(newEmail);
      }

      final updatedUser = UserModel(
        id: currentUser.id,
        name: currentUser.name,
        email: newEmail,
        phone: currentUser.phone,
        age: currentUser.age,
        gender: currentUser.gender,
        bloodType: currentUser.bloodType,
        healthConditions: currentUser.healthConditions,
        allergies: currentUser.allergies,
        currentMedications: currentUser.currentMedications,
        weight: currentUser.weight,
        height: currentUser.height,
        createdAt: currentUser.createdAt,
        healthInfoCompleted: currentUser.healthInfoCompleted,
      );

      user.value = updatedUser;
      await UserRepository.instance.saveUser(updatedUser);

      Get.snackbar('نجاح', 'تم تحديث البريد الإلكتروني بنجاح');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث البريد الإلكتروني: ${e.toString()}');
    }
  }

}
