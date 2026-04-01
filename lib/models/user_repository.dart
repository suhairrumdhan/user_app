import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();

  final _db = FirebaseFirestore.instance;

  Future<void> updateUserFields(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }
}