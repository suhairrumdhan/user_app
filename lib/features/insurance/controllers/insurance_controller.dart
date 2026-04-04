import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/insurance_model.dart';

class InsuranceController extends GetxController {
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  final insurances = <InsuranceModel>[].obs;
  final isLoading = false.obs;

  CollectionReference get insuranceRef => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('insurances');

  @override
  void onInit() {
    super.onInit();
    _listenToInsurances();
  }

  void _listenToInsurances() {
    insuranceRef.orderBy('createdAt', descending: true).snapshots().listen(
          (snapshot) {
        insurances.value = snapshot.docs
            .map(
              (doc) => InsuranceModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          ),
        )
            .toList();
      },
    );
  }

  Stream<List<InsuranceModel>> getInsurances() {
    return insuranceRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => InsuranceModel.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        ),
      )
          .toList(),
    );
  }

  Future<void> addInsurance(InsuranceModel insurance) async {
    try {
      isLoading.value = true;
      await insuranceRef.add(insurance.toMap());
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إضافة شركة التأمين: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateInsurance(InsuranceModel insurance) async {
    try {
      if (insurance.id.isEmpty) {
        throw Exception('معرّف التأمين غير موجود');
      }

      isLoading.value = true;
      await insuranceRef.doc(insurance.id).update(insurance.toMap());
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث شركة التأمين: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteInsurance(String id) async {
    try {
      isLoading.value = true;
      await insuranceRef.doc(id).delete();
      insurances.removeWhere((i) => i.id == id);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في حذف شركة التأمين: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<InsuranceModel?> getInsurance(String id) async {
    try {
      final doc = await insuranceRef.doc(id).get();
      if (!doc.exists) return null;

      return InsuranceModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  void clearData() {
    insurances.clear();
  }
}