import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/auth/models/user_model.dart';

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find<UserRepository>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // التحقق مما إذا كان المستخدم موجود مسبقًا في Firestore
  Future<bool> checkUserExists(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.exists;
  }

  // التحقق من اكتمال المعلومات الصحية
  Future<bool> isHealthInfoComplete(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      return doc.exists && doc.data()?['healthInfoCompleted'] == true;
    } catch (e) {
      return false;
    }
  }

  // جلب بيانات المستخدم من Firestore
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      return doc.exists ? UserModel.fromJson(doc.data()!) : null;
    } catch (e) {
      throw "فشل في جلب بيانات المستخدم: ${e.toString()}";
    }
  }
}
