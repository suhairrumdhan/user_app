import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_member_model.dart';

class FamilyController extends GetxController {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  // Observable list for reactive updates
  final members = <FamilyMemberModel>[].obs;
  final isLoading = false.obs;

  CollectionReference get familyRef => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('familyMembers');

  @override
  void onInit() {
    super.onInit();
    _listenToMembers();
  }

  /// 🔹 الاستماع للتغييرات في الوقت الفعلي
  void _listenToMembers() {
    familyRef.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      members.value = snapshot.docs
          .map((doc) => FamilyMemberModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      ))
          .toList();
    });
  }

  /// 🔹 جلب البيانات (Stream)
  Stream<List<FamilyMemberModel>> getMembers() {
    return familyRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
          .map((doc) => FamilyMemberModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      ))
          .toList(),
    );
  }

  /// 🔹 إضافة فرد جديد
  Future<void> addMember(FamilyMemberModel member) async {
    try {
      isLoading.value = true;
      await familyRef.add(member.toMap());
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إضافة الفرد: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔹 تعديل بيانات فرد
  Future<void> updateMember(FamilyMemberModel member) async {
    try {
      isLoading.value = true;
      await familyRef.doc(member.id).update(member.toMap());
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث الفرد: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
          healthConditions: updateData['healthConditions'] ?? members[index].healthConditions,
          allergies: updateData['allergies'] ?? members[index].allergies,
          currentMedications: updateData['currentMedications'] ?? members[index].currentMedications,
        );
      }


    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث السجل الصحي: $e',
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
        'فشل في حذف الفرد: $e',
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
        'currentMedications': List<String>.from(data['currentMedications'] ?? []),
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
      if (dateOfBirth != null) updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);

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