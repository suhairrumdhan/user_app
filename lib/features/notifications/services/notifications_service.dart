import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification_model.dart';
import '../models/notification_type.dart';
import '../../../shared/session_list_feed.dart';

class NotificationsService {
  static final NotificationsService _instance =
      NotificationsService._internal();

  factory NotificationsService() => _instance;

  NotificationsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final _feed = SessionListFeed<AppNotificationModel>(
    sessions: _auth.authStateChanges().map((user) => user?.uid),
    currentUserId: () => _userId,
    watch: (uid) => _visibleWindow(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map(AppNotificationModel.fromFirestore)
          .where(
            (notification) =>
                !notification.isDeleted &&
                !_isChatNotification(
                  notification.type.value,
                  notification.referenceType.value,
                ),
          )
          .toList(),
    ),
  );
  late final Stream<int> _unreadStream = _feed.stream.map(
    (items) => items.where((item) => !item.isRead && !item.badgeSeen).length,
  );

  Query<Map<String, dynamic>> _visibleWindow(String uid) =>
      _userNotificationsRef(
        uid,
      ).orderBy('createdAt', descending: true).limit(100);

  String? get _userId => _auth.currentUser?.uid;

  bool _isChatNotification(String type, String referenceType) =>
      type == 'pharmacyMessage' || referenceType == 'chat';

  CollectionReference<Map<String, dynamic>> _userNotificationsRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');
  }

  /// =============================
  /// 📥 Stream Notifications
  /// =============================
  Stream<List<AppNotificationModel>> getNotificationsStream() {
    return _feed.stream;
  }

  /// =============================
  /// 🔢 Unread Count
  /// =============================

  Stream<int> getUnreadCountStream() {
    return _unreadStream;
  }

  /// =============================
  /// ➕ Create Notification
  /// =============================
  Future<void> createNotification(AppNotificationModel notification) async {
    final userId = notification.userId;

    await _userNotificationsRef(
      userId,
    ).doc(notification.id).set(notification.toMap());
  }

  /// =============================
  /// ✔️ Mark as Read
  /// =============================
  Future<void> markAsRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    await _userNotificationsRef(userId).doc(notificationId).update({
      'isRead': true,
      'badgeSeen': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clears the bottom-bar badge without changing unread notification cards.
  Future<void> markAllAsSeen() async {
    final userId = _userId;
    if (userId == null) return;

    final snapshot = await _visibleWindow(userId).get();
    if (_userId != userId) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isRead'] == true ||
          data['badgeSeen'] == true ||
          data['isDeleted'] == true ||
          _isChatNotification(
            data['type']?.toString() ?? '',
            data['referenceType']?.toString() ?? '',
          )) {
        continue;
      }
      batch.update(doc.reference, {'badgeSeen': true});
    }

    await batch.commit();
  }

  /// =============================
  /// ✔️ Mark All as Read
  /// =============================
  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;

    final snapshot = await _visibleWindow(userId).get();
    if (_userId != userId) return;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isRead'] == true ||
          data['isDeleted'] == true ||
          _isChatNotification(
            data['type']?.toString() ?? '',
            data['referenceType']?.toString() ?? '',
          )) {
        continue;
      }
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

    await _userNotificationsRef(
      userId,
    ).doc(notificationId).update({'isDeleted': true});
  }

  /// =============================
  /// 🧹 Hard Delete (اختياري)
  /// =============================
  Future<void> hardDeleteNotification(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    await _userNotificationsRef(userId).doc(notificationId).delete();
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
