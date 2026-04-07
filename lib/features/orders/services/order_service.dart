import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../profile/controllers/user_controller.dart';
import '../builders/order_snapshot_builder.dart';
import '../models/order_status.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  UserController get _userController => Get.find<UserController>();

  Future<OrderModel> createOrder({
    required PharmacyModel pharmacy,
    required BeneficiaryModel beneficiary,
    required List<MedicineModel> medicines,
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

    if (medicines.isEmpty) {
      throw Exception('يجب إضافة دواء واحد على الأقل');
    }

    final order = OrderSnapshotBuilder.buildOrder(
      ownerUserId: currentUser.id,
      userSnapshot: OrderSnapshotBuilder.buildUserSnapshot(
        userId: currentUser.id,
      ),
      pharmacy: pharmacy,
      beneficiary: beneficiary,
      medicines: medicines,
      useInsurance: useInsurance,
      requestSource: requestSource,
      userNote: userNote,
      chatId: chatId,
      prescriptionId: prescriptionId,
      prescriptionImageUrl: prescriptionImageUrl,
      prescriptionText: prescriptionText,
      metadata: metadata,
    );

    final doc = await _ordersRef.add(order.toMap());

    return order.copyWith(id: doc.id);
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