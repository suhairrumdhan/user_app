import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/features/profile/models/user_model.dart';

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find<UserRepository>();
  UserRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<UserModel> ensureUserProfile(
    User account, {
    String? name,
    String? phone,
  }) async {
    final ref = _db.collection('users').doc(account.uid);
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        final patch = <String, dynamic>{};
        if (name != null && name.isNotEmpty) patch['name'] = name;
        if (phone != null && phone.isNotEmpty) patch['phone'] = phone;
        if (patch.isNotEmpty) transaction.update(ref, patch);
        return UserModel.fromJson({...data, ...patch}, account.uid);
      }
      final profile = UserModel.fromFirebaseUser(account);
      if (name != null && name.isNotEmpty) profile.name = name;
      if (phone != null && phone.isNotEmpty) profile.phone = phone;
      transaction.set(ref, profile.toJson());
      return profile;
    });
  }

  Future<void> createUser(UserModel user) async {
    try {
      print('🔄 جاري إنشاء مستخدم جديد: ${user.id}');
      await _db.collection("users").doc(user.id).set(user.toJson());
      print('✅ تم إنشاء المستخدم بنجاح في Firestore');
    } catch (e) {
      print('❌ خطأ في إنشاء المستخدم: $e');
      rethrow;
    }
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    try {
      print('🔄 جاري تحديث بيانات المستخدم: $uid');
      await _db.collection("users").doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ تم تحديث بيانات المستخدم بنجاح');
    } catch (e) {
      print('❌ خطأ في تحديث بيانات المستخدم: $e');
      rethrow;
    }
  }

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

  Future<void> saveUser(UserModel user) async {
    try {
      print('💾 جاري حفظ المستخدم في Firestore: ${user.id}');
      await _db
          .collection("users")
          .doc(user.id)
          .set(
            user.toJson(),
            SetOptions(merge: true), // ✅ هذا هيخلي البيانات تدمج بدل ما تستبدل
          );
      print('✅ تم حفظ المستخدم بنجاح في Firestore');
    } catch (e) {
      print('❌ خطأ في حفظ المستخدم في Firestore: $e');
      rethrow;
    }
  }

  // جلب بيانات المستخدم من Firestore
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      return doc.exists ? UserModel.fromJson(doc.data()!, doc.id) : null;
    } catch (e) {
      try {
        final cachedDoc = await _db
            .collection("users")
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        return cachedDoc.exists
            ? UserModel.fromJson(cachedDoc.data()!, cachedDoc.id)
            : null;
      } catch (_) {
        throw "فشل في جلب بيانات المستخدم: ${e.toString()}";
      }
    }
  }
}
