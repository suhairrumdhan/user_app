import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../profile/controllers/user_controller.dart';
import '../../search/models/matched_medicine_result.dart';
import '../builders/order_snapshot_builder.dart';
import '../models/order_status.dart';
import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  UserController get _userController => Get.find<UserController>();

  Future<Map<String, dynamic>> _reserveOrderNumber({
    required String pharmacyId,
    required String userId,
    required String userName,
    required String beneficiaryId,
    required String beneficiaryName,
    required String beneficiaryType,
    required String relationLabel,
  }) async {
    try {
      final callable = _functions.httpsCallable('reserveOrderNumber');

      final result = await callable.call({
        'pharmacyId': pharmacyId,
        'userId': userId,
        'userName': userName,
        'beneficiaryId': beneficiaryId,
        'beneficiaryName': beneficiaryName,
        'beneficiaryType': beneficiaryType,
        'relationLabel': relationLabel,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('✅ reserveOrderNumber result: $data');

      return data;
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('❌ FirebaseFunctionsException');
      debugPrint('code: ${e.code}');
      debugPrint('message: ${e.message}');
      debugPrint('details: ${e.details}');
      debugPrintStack(stackTrace: st);
      rethrow;
    } catch (e, st) {
      debugPrint('❌ reserveOrderNumber unknown error: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<OrderModel> createOrder({
    required PharmacyModel pharmacy,
    required BeneficiaryModel beneficiary,
    required List<MatchedMedicineResult> selectedMatches,
    required Map<String, int> quantitiesByMatchedMedicineId,
    required bool useInsurance,
    required OrderRequestSource requestSource,
    String? userNote,
    String? chatId,
    String? prescriptionId,
    String? prescriptionImageUrl,
    String? prescriptionText,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = _userController.user.value;
    if (currentUser == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    if (pharmacy.id.trim().isEmpty) {
      throw Exception('بيانات الصيدلية غير صالحة');
    }

    if (beneficiary.id.trim().isEmpty) {
      throw Exception('يجب اختيار المستفيد');
    }

    if (selectedMatches.isEmpty) {
      throw Exception('يجب اختيار دواء واحد على الأقل');
    }
    debugPrint('🔥 pharmacyId: ${pharmacy.id}');
    debugPrint('🔥 userId: ${currentUser.id}');

    final order = OrderSnapshotBuilder.buildOrderFromMatches(
      ownerUserId: currentUser.id,
      userSnapshot: OrderSnapshotBuilder.buildUserSnapshot(
        userId: currentUser.id,
      ),
      pharmacy: pharmacy,
      beneficiary: beneficiary,
      selectedMatches: selectedMatches,
      quantitiesByMatchedMedicineId: quantitiesByMatchedMedicineId,
      useInsurance: useInsurance,
      requestSource: requestSource,
      userNote: userNote,
      chatId: chatId,
      prescriptionId: prescriptionId,
      prescriptionImageUrl: prescriptionImageUrl,
      prescriptionText: prescriptionText,
      metadata: metadata,
    );
    try {
      final reserved = await _reserveOrderNumber(
        pharmacyId: pharmacy.id,
        userId: currentUser.id,
        userName: currentUser.name,
        beneficiaryId: beneficiary.id,
        beneficiaryName: beneficiary.name,
        beneficiaryType: beneficiary.isSelf ? 'self' : 'family',
        relationLabel: beneficiary.relation?.trim().isNotEmpty == true
            ? beneficiary.relation!.trim()
            : (beneficiary.isSelf ? 'أنا' : 'فرد من العائلة'),
      );

      debugPrint('✅ reserved map: $reserved');

      final orderWithNumber = order.copyWith(
        orderNumber: reserved['orderNumber']?.toString(),
        orderDateKey: reserved['orderDateKey']?.toString(),
        dailySequence: reserved['dailySequence'] is int
            ? reserved['dailySequence'] as int
            : int.tryParse('${reserved['dailySequence']}'),
      );

      debugPrint('✅ orderWithNumber.orderNumber = ${orderWithNumber.orderNumber}');
      debugPrint('✅ orderWithNumber.orderDateKey = ${orderWithNumber.orderDateKey}');
      debugPrint('✅ orderWithNumber.dailySequence = ${orderWithNumber.dailySequence}');

      final map = orderWithNumber.toMap();
      debugPrint('✅ orderWithNumber.toMap ready');


      final doc = await _ordersRef.add(map);
      debugPrint('✅ order saved with id: ${doc.id}');

      return orderWithNumber.copyWith(id: doc.id);
    } catch (e, st) {
      debugPrint('❌ createOrder failed inside OrderService: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

  }

  Future<OrderModel?> getOrderById(String orderId) async {
    if (orderId.trim().isEmpty) return null;

    final doc = await _ordersRef.doc(orderId).get();
    if (!doc.exists) return null;

    return OrderModel.fromFirestore(doc);
  }

  Stream<List<OrderModel>> getUserOrdersStream(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _ordersRef
        .where('user.userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList(),
    );
  }

  Stream<List<OrderModel>> getPharmacyOrdersStream(String pharmacyId) {
    if (pharmacyId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _ordersRef
        .where('pharmacy.pharmacyId', isEqualTo: pharmacyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList(),
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    required String changedById,
    required String changedByType,
    String? note,
  }) async {
    if (orderId.trim().isEmpty) {
      throw Exception('معرف الطلب غير صالح');
    }

    final docRef = _ordersRef.doc(orderId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('الطلب غير موجود');
    }

    final currentOrder = OrderModel.fromFirestore(doc);
    final now = DateTime.now();

    final updatedHistory = [
      ...currentOrder.statusHistory,
      OrderStatusLog(
        status: newStatus.value,
        label: newStatus.label,
        changedById: changedById,
        changedByType: changedByType,
        note: note,
        changedAt: now,
      ),
    ];

    final updateMap = <String, dynamic>{
      'status': newStatus.value,
      'statusLabel': newStatus.label,
      'statusHistory': updatedHistory.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == OrderStatus.reviewing) {
      updateMap['reviewedAt'] = FieldValue.serverTimestamp();
    }

    if (newStatus == OrderStatus.completed) {
      updateMap['completedAt'] = FieldValue.serverTimestamp();
    }

    if (newStatus == OrderStatus.cancelled) {
      updateMap['cancelledAt'] = FieldValue.serverTimestamp();
    }

    await docRef.update(updateMap);
  }
  Stream<OrderModel?> watchOrderById(String orderId) {
    if (orderId.trim().isEmpty) return Stream.value(null);

    return _ordersRef.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromFirestore(doc);
    });
  }
  Future<void> attachChatToOrder({
    required String orderId,
    required String chatId,
  }) async {
    if (orderId.trim().isEmpty || chatId.trim().isEmpty) {
      throw Exception('بيانات الربط غير صالحة');
    }

    await _ordersRef.doc(orderId).update({
      'chatId': chatId.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}