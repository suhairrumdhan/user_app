import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/insurance_model.dart';

class InsuranceController extends GetxController {
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  final insurances = <InsuranceModel>[].obs;
  final isLoading = false.obs;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _insuranceSubscription;
  String? _listeningUserId;

  CollectionReference<Map<String, dynamic>> get insuranceRef {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('يجب تسجيل الدخول للوصول إلى بيانات التأمين');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insurances');
  }

  @override
  void onInit() {
    super.onInit();
    _authSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (user == null) {
        _listeningUserId = null;
        unawaited(_insuranceSubscription?.cancel());
        _insuranceSubscription = null;
        insurances.clear();
        isLoading.value = false;
        return;
      }
      _listenToInsurances(user.uid);
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _insuranceSubscription?.cancel();
    super.onClose();
  }

  void _listenToInsurances(String uid) {
    if (_listeningUserId == uid && _insuranceSubscription != null) return;
    _listeningUserId = uid;
    unawaited(_insuranceSubscription?.cancel());
    isLoading.value = true;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('insurances');
    _insuranceSubscription = ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            insurances.assignAll(
              snapshot.docs
                  .map((doc) => InsuranceModel.fromMap(doc.id, doc.data()))
                  .toList(),
            );
            isLoading.value = false;
          },
          onError: (Object error, StackTrace stackTrace) {
            isLoading.value = false;
            debugPrint('تعذر تحميل بيانات التأمين: $error');
          },
        );
  }

  Stream<List<InsuranceModel>> getInsurances() {
    return insuranceRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InsuranceModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addInsurance(InsuranceModel insurance) async {
    try {
      isLoading.value = true;
      final beneficiaryId = insurance.beneficiaryId.trim();
      if (beneficiaryId.isEmpty) {
        throw StateError('يجب اختيار المستفيد من وثيقة التأمين');
      }
      final duplicate = insurances.any(
        (item) => item.beneficiaryId == beneficiaryId,
      );
      if (duplicate) {
        throw StateError('هذا المستفيد مرتبط بالفعل بوثيقة تأمين');
      }
      final target = insuranceRef.doc(beneficiaryId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existing = await transaction.get(target);
        if (existing.exists) {
          throw StateError('هذا المستفيد مرتبط بالفعل بوثيقة تأمين');
        }
        transaction.set(target, insurance.toMap());
      });
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إضافة شركة التأمين',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
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
      final duplicate = insurances.any(
        (item) =>
            item.id != insurance.id &&
            item.beneficiaryId == insurance.beneficiaryId,
      );
      if (duplicate) {
        throw StateError('هذا المستفيد مرتبط بالفعل بوثيقة تأمين أخرى');
      }
      if (insurance.id == insurance.beneficiaryId) {
        await insuranceRef.doc(insurance.id).update(insurance.toMap());
      } else {
        // Migrate a legacy random document ID to the deterministic beneficiary
        // ID while preserving a single atomic outcome.
        final oldRef = insuranceRef.doc(insurance.id);
        final targetRef = insuranceRef.doc(insurance.beneficiaryId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final target = await transaction.get(targetRef);
          if (target.exists) {
            throw StateError('هذا المستفيد مرتبط بالفعل بوثيقة تأمين');
          }
          transaction.set(targetRef, insurance.toMap());
          transaction.delete(oldRef);
        });
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في تحديث شركة التأمين',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow;
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
        'فشل في حذف شركة التأمين',
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

      return InsuranceModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  void clearData() {
    insurances.clear();
  }
}
