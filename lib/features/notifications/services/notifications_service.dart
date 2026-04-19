import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/app_notification_model.dart';
import '../../profile/controllers/user_controller.dart';

class NotificationsService {
  static final NotificationsService _instance =
  NotificationsService._internal();

  factory NotificationsService() => _instance;

  NotificationsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserController get _userController => Get.find<UserController>();

  String? get _userId => _userController.user.value?.id;

  CollectionReference<Map<String, dynamic>> _userNotificationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  /// =============================
  /// 📥 Stream Notifications
  /// =============================
  Stream<List<AppNotificationModel>> getNotificationsStream() {
    final userId = _userId;
    if (userId == null) return Stream.value([]);

    return _userNotificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => AppNotificationModel.fromFirestore(doc))
          .where((n) => !n.isDeleted)
          .toList(),
    );
  }

  /// =============================
  /// 🔢 Unread Count
  /// =============================

  Stream<int> getUnreadCountStream() {
    final userId = _userId;
    if (userId == null) return Stream.value(0);

    return _userNotificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }


  /// =============================
  /// ➕ Create Notification
  /// =============================
  Future<void> createNotification(AppNotificationModel notification) async {
    final userId = notification.userId;

    await _userNotificationsRef(userId)
        .doc(notification.id)
        .set(notification.toMap());
  }

  /// =============================
  /// ✔️ Mark as Read
  /// =============================
  Future<void> markAsRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    await _userNotificationsRef(userId)
        .doc(notificationId)
        .update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// =============================
  /// ✔️ Mark All as Read
  /// =============================
  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;

    final snapshot = await _userNotificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// =============================
  /// ❌ Soft Delete
  /// =============================
  Future<void> deleteNotification(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    await _userNotificationsRef(userId)
        .doc(notificationId)
        .update({
      'isDeleted': true,
    });
  }

  /// =============================
  /// 🧹 Hard Delete (اختياري)
  /// =============================
  Future<void> hardDeleteNotification(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    await _userNotificationsRef(userId)
        .doc(notificationId)
        .delete();
  }
  /// =============================
  /// 📦 Bulk Insert (مفيد للـ admin)
  /// =============================
  Future<void> createBulkNotifications(
      List<AppNotificationModel> notifications,
      ) async {
    final batch = _firestore.batch();

    for (final n in notifications) {
      final ref = _userNotificationsRef(n.userId).doc(n.id);
      batch.set(ref, n.toMap());
    }

    await batch.commit();
  }
}