import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/pending_order_commands.dart';

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
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  UserController get _userController => Get.find<UserController>();

  String newOperationId(String command) {
    final random = Random.secure();
    final entropy = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'order:$command:${DateTime.now().microsecondsSinceEpoch}:$entropy';
  }

  dynamic _callableValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is List) return value.map(_callableValue).toList();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _callableValue(item)),
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> _executeCommand({
    required String command,
    required String operationId,
    String? orderId,
    Map<String, dynamic> payload = const {},
    Map<String, dynamic> actor = const {},
  }) async {
    final callable = _functions.httpsCallable('executeOrderCommand');
    final request = {
      'schemaVersion': 3,
      'command': command,
      'operationId': operationId,
      if (orderId != null) 'orderId': orderId,
      'payload': _callableValue(payload),
      'actor': actor,
    };
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('يجب تسجيل الدخول');
    return PendingOrderCommands.execute(
      key: '$uid:$command:${orderId ?? "new"}',
      request: request,
      isDefinitiveFailure: (error) =>
          error is FirebaseFunctionsException &&
          !{
            'unavailable',
            'deadline-exceeded',
            'internal',
          }.contains(error.code),
      send: (savedRequest) async {
        FirebaseFunctionsException? lastError;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            if (FirebaseAuth.instance.currentUser?.uid != uid)
              throw StateError('تغيرت جلسة الدخول');
            debugPrint(
              'executeOrderCommand started: command=$command '
              'operationId=${savedRequest['operationId']} attempt=${attempt + 1}',
            );
            final response = await callable.call(savedRequest);
            debugPrint(
              'executeOrderCommand succeeded: command=$command '
              'response=${response.data}',
            );
            return Map<String, dynamic>.from(response.data as Map);
          } on FirebaseFunctionsException catch (error) {
            lastError = error;
            debugPrint(
              'executeOrderCommand failed: command=$command code=${error.code} '
              'message=${error.message} details=${error.details}',
            );
            if (!{
                  'unavailable',
                  'deadline-exceeded',
                  'internal',
                }.contains(error.code) ||
                attempt == 2) {
              rethrow;
            }
            await Future<void>.delayed(
              Duration(milliseconds: 600 * (attempt + 1)),
            );
          }
        }
        throw lastError ?? Exception('تعذر تنفيذ أمر الطلب');
      },
    );
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
      final operationId = newOperationId('create');
      final map = order.toMap()
        ..removeWhere(
          (key, _) => {
            'schemaVersion',
            'orderNumber',
            'orderDateKey',
            'dailySequence',
            'status',
            'statusLabel',
            'statusHistory',
            'createdAt',
            'updatedAt',
            'submittedAt',
            'reviewedAt',
            'completedAt',
            'cancelledAt',
            'operationId',
            'payloadHash',
            'commandResultRef',
            'invoiceId',
            'offerVersion',
            'reservationId',
            'reservationState',
            'reviewStartedAt',
            'pharmacyDelayAt',
            'userDecisionStartedAt',
            'userDecisionDeadline',
            'preparingAt',
            'readyAt',
            'pickupDeadline',
            'pickupOverdue',
            'pharmacyDelayed',
            'deliveredAt',
            'collectedAt',
            'rejectedAt',
            'notCollectedAt',
          }.contains(key),
        );
      final envelope = await _executeCommand(
        command: 'createOrder',
        operationId: operationId,
        payload: {'order': map},
      );
      final result = Map<String, dynamic>.from(envelope['result'] as Map);
      final createdStatus = OrderStatusX.fromValue(
        result['status']?.toString(),
      );
      final localCommittedAt = DateTime.now();
      return order.copyWith(
        id: result['orderId']?.toString() ?? '',
        orderNumber: result['orderNumber']?.toString(),
        status: createdStatus,
        statusLabel: createdStatus.label,
        operationId: envelope['operationId']?.toString(),
        payloadHash: envelope['payloadHash']?.toString(),
        createdAt: localCommittedAt,
        updatedAt: localCommittedAt,
        submittedAt: localCommittedAt,
        reviewStartedAt: createdStatus == OrderStatus.underReview
            ? localCommittedAt
            : null,
      );
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

    if (changedByType != 'user' || newStatus != OrderStatus.cancelled) {
      throw Exception('هذا الانتقال لا ينفذه تطبيق المستخدم');
    }
    await _executeCommand(
      command: 'cancelOrder',
      operationId: newOperationId('cancel'),
      orderId: orderId,
      payload: {if (note != null) 'note': note},
    );
  }

  Future<void> acceptPartialOffer({
    required String orderId,
    required int offerVersion,
  }) async {
    await _executeCommand(
      command: 'acceptPartialOffer',
      operationId: newOperationId('accept-offer'),
      orderId: orderId,
      payload: {'offerVersion': offerVersion},
    );
  }

  Future<void> rejectPartialOffer({
    required String orderId,
    required int offerVersion,
  }) async {
    await _executeCommand(
      command: 'rejectPartialOffer',
      operationId: newOperationId('reject-offer'),
      orderId: orderId,
      payload: {'offerVersion': offerVersion},
    );
  }

  Future<void> continueWithoutInsurance({required String orderId}) async {
    await _executeCommand(
      command: 'continueWithoutInsurance',
      operationId: newOperationId('continue-without-insurance'),
      orderId: orderId,
      payload: const {'note': 'اختار المستخدم متابعة الطلب دون تغطية تأمينية'},
    );
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
