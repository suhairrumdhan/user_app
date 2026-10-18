import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_member_model.dart';

class FamilyController extends GetxController {
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // Observable list for reactive updates
  final members = <FamilyMemberModel>[].obs;
  final isLoading = false.obs;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSubscription;
  String? _listeningUserId;

  CollectionReference<Map<String, dynamic>> get familyRef {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('يجب تسجيل الدخول للوصول إلى أفراد العائلة');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('familyMembers');
  }

  @override
  void onInit() {
    super.onInit();
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user == null) {
        _listeningUserId = null;
        unawaited(_membersSubscription?.cancel());
        _membersSubscription = null;
        members.clear();
        isLoading.value = false;
        return;
      }
      _listenToMembers(user.uid);
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _membersSubscription?.cancel();
    super.onClose();
  }

  /// 🔹 الاستماع للتغييرات في الوقت الفعلي
  void _listenToMembers(String uid) {
    if (_listeningUserId == uid && _membersSubscription != null) return;
    _listeningUserId = uid;
    unawaited(_membersSubscription?.cancel());
    isLoading.value = true;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('familyMembers');
    _membersSubscription = ref.snapshots().listen(
      (snapshot) {
        final loaded = snapshot.docs
            .map((doc) => FamilyMemberModel.fromMap(doc.id, doc.data()))
            .toList();
        loaded.sort((a, b) => a.name.compareTo(b.name));
        members.assignAll(loaded);
        isLoading.value = false;
      },
      onError: (Object error, StackTrace stackTrace) {
        isLoading.value = false;
        debugPrint('تعذر تحميل أفراد العائلة: $error');
      },
    );
  }

  /// يجلب أحدث نسخة قبل بناء قوائم المستفيدين أو حفظ الطلبات.
  Future<List<FamilyMemberModel>> refreshMembers() async {
    final snapshot = await familyRef.get();
    final loaded =
        snapshot.docs
            .map((doc) => FamilyMemberModel.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    members.assignAll(loaded);
    return loaded;
  }

  /// 🔹 جلب البيانات (Stream)
  Stream<List<FamilyMemberModel>> getMembers() {
    return familyRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FamilyMemberModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  /// 🔹 إضافة فرد جديد
  Future<String> addMember(FamilyMemberModel member) async {
    try {
      isLoading.value = true;
      final document = await familyRef.add(member.toMap());
      final saved = member.copyWith(id: document.id);
      if (!members.any((item) => item.id == document.id)) {
        members.add(saved);
      }
      return document.id;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إضافة الفرد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔹 تعديل بيانات فرد
  Future<void> updateMember(FamilyMemberModel member) async {
    try {
      isLoading.value = true;
      await familyRef
          .doc(member.id)
          .update(member.toMap(includeCreatedAt: false));
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث الفرد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔹 تحديث السجل الصحي لفرد العائلة
  Future<void> updateMemberHealthRecords(
    String memberId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      isLoading.value = true;

      // تحديث في Firestore
      await familyRef.doc(memberId).update(updateData);

      // تحديث القائمة المحلية
      final index = members.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        members[index] = members[index].copyWith(
          healthConditions:
              updateData['healthConditions'] ?? members[index].healthConditions,
          allergies: updateData['allergies'] ?? members[index].allergies,
          currentMedications:
              updateData['currentMedications'] ??
              members[index].currentMedications,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث السجل الصحي',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔹 حذف فرد
  Future<void> deleteMember(String id) async {
    try {
      isLoading.value = true;

      // حذف من Firestore
      await familyRef.doc(id).delete();

      // حذف من القائمة المحلية
      members.removeWhere((m) => m.id == id);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في حذف الفرد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔹 جلب فرد واحد
  Future<FamilyMemberModel?> getMember(String id) async {
    try {
      final doc = await familyRef.doc(id).get();
      if (!doc.exists) return null;

      return FamilyMemberModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMemberHealthRecords(String memberId) async {
    try {
      final doc = await familyRef.doc(memberId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return {
        'healthConditions': List<String>.from(data['healthConditions'] ?? []),
        'allergies': List<String>.from(data['allergies'] ?? []),
        'currentMedications': List<String>.from(
          data['currentMedications'] ?? [],
        ),
      };
    } catch (e) {
      return null;
    }
  }

  Future<void> updateMemberAdditionalInfo({
    required String memberId,
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (bloodType != null) updateData['bloodType'] = bloodType;
      if (gender != null) updateData['gender'] = gender;
      if (dateOfBirth != null)
        updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);

      if (updateData.isNotEmpty) {
        await familyRef.doc(memberId).update(updateData);

        // تحديث القائمة المحلية
        final index = members.indexWhere((m) => m.id == memberId);
        if (index != -1) {
          members[index] = members[index].copyWith(
            bloodType: bloodType ?? members[index].bloodType,
            gender: gender ?? members[index].gender,
            dateOfBirth: dateOfBirth ?? members[index].dateOfBirth,
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديث المعلومات الإضافية: $e');
      rethrow;
    }
  }

  /// 🔹 مسح جميع البيانات (للخروج من التطبيق)
  void clearData() {
    members.clear();
  }
}
