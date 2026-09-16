import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../orders/models/order_status.dart';
import '../../profile/controllers/user_controller.dart';
import '../models/chat_thread_model.dart';
import '../models/message_model.dart';

class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserController get _userController => Get.find<UserController>();

  dynamic get _currentUser => _userController.user.value;

  dynamic _requireCurrentUser() {
    final user = _currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }
    return user;
  }

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatsRef.doc(chatId).collection('messages');

  bool _isClosedOrderStatus(String status) {
    return status == OrderStatus.completed.value ||
        status == OrderStatus.cancelled.value ||
        status == OrderStatus.rejected.value ||
        status == OrderStatus.notCollected.value;
  }

  Future<void> _ensureChatWritable(String chatId) async {
    final chatSnapshot = await _chatsRef.doc(chatId).get();
    final chatData = chatSnapshot.data();
    final orderId = (chatData?['orderId'] ?? '').toString().trim();
    if (!chatSnapshot.exists || orderId.isEmpty) {
      throw Exception('تعذر التحقق من الطلب المرتبط بالمحادثة');
    }

    final orderSnapshot = await _firestore
        .collection('orders')
        .doc(orderId)
        .get();
    if (!orderSnapshot.exists) {
      throw Exception('الطلب المرتبط بالمحادثة غير موجود');
    }

    final status = (orderSnapshot.data()?['status'] ?? '').toString();
    if (_isClosedOrderStatus(status)) {
      throw Exception('انتهى الطلب وأصبحت المحادثة للقراءة فقط');
    }
  }

  String _resolveOrderChatId(OrderModel order) {
    final linkedChatId = (order.chatId ?? '').trim();
    if (linkedChatId.isNotEmpty) return linkedChatId;

    // Use the same deterministic id as the pharmacy app. A query by orderId
    // alone is denied by the participant-only Firestore list rule.
    return 'order_${order.id.trim()}';
  }

  Future<ChatThread> getOrCreateOrderChat(OrderModel order) async {
    final currentUser = _requireCurrentUser();
    final orderId = order.id.trim();
    final currentUserId = currentUser.id.toString().trim();

    if (orderId.isEmpty) {
      throw Exception('لا يمكن بدء المحادثة قبل حفظ الطلب');
    }

    if (order.pharmacy.pharmacyId.trim().isEmpty) {
      throw Exception('بيانات الصيدلية في الطلب غير صالحة');
    }

    if (order.user.userId.trim().isNotEmpty &&
        order.user.userId.trim() != currentUserId) {
      throw Exception('لا تملك صلاحية فتح محادثة هذا الطلب');
    }

    final chatId = _resolveOrderChatId(order);
    final chatRef = _chatsRef.doc(chatId);
    final orderRef = _firestore.collection('orders').doc(orderId);
    final initialMessageRef = _messagesRef(chatId).doc('conversation_created');

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      final orderSnapshot = await transaction.get(orderRef);

      if (!orderSnapshot.exists) {
        throw Exception('الطلب غير موجود');
      }

      final liveOrder = OrderModel.fromFirestore(orderSnapshot);
      if (liveOrder.user.userId.trim().isNotEmpty &&
          liveOrder.user.userId.trim() != currentUserId) {
        throw Exception('لا تملك صلاحية فتح محادثة هذا الطلب');
      }

      if (_isClosedOrderStatus(liveOrder.status.value)) {
        throw Exception('انتهى الطلب وأصبحت المحادثة للقراءة فقط');
      }

      if (chatSnapshot.exists) {
        final chatData = chatSnapshot.data() ?? const <String, dynamic>{};
        final existingOrderId = (chatData['orderId'] ?? '').toString().trim();
        final existingUserId = (chatData['userId'] ?? '').toString().trim();

        if (existingOrderId.isNotEmpty && existingOrderId != orderId) {
          throw Exception('معرف المحادثة مرتبط بطلب آخر');
        }

        if (existingUserId.isNotEmpty && existingUserId != currentUserId) {
          throw Exception('لا تملك صلاحية فتح هذه المحادثة');
        }
      }

      if (!chatSnapshot.exists) {
        final orderNumber = (liveOrder.orderNumber ?? '').trim();
        final systemText = orderNumber.isNotEmpty
            ? 'تم إنشاء المحادثة للطلب #$orderNumber'
            : 'تم إنشاء المحادثة لهذا الطلب';

        transaction.set(chatRef, {
          'chatId': chatId,
          'orderId': orderId,
          'orderNumber': liveOrder.orderNumber,
          'userId': currentUserId,
          'userName': liveOrder.user.name.trim().isNotEmpty
              ? liveOrder.user.name.trim()
              : currentUser.name.toString(),
          'pharmacyId': liveOrder.pharmacy.pharmacyId,
          'pharmacyName': liveOrder.pharmacy.pharmacyName,
          'pharmacyImageUrl': liveOrder.pharmacy.imageUrl ?? '',
          'pharmacyIsOnline': liveOrder.pharmacy.isOnline,
          'beneficiaryId': liveOrder.beneficiary.beneficiaryId,
          'beneficiaryName': liveOrder.beneficiary.name,
          'beneficiaryType': liveOrder.beneficiary.type.value,
          'relationLabel':
              liveOrder.beneficiary.relationLabel ??
              liveOrder.beneficiary.type.label,
          'healthSnapshot': {
            'gender': liveOrder.beneficiary.gender,
            'bloodType': liveOrder.beneficiary.bloodType,
            'age': liveOrder.beneficiary.age,
            'dateOfBirth': liveOrder.beneficiary.dateOfBirth == null
                ? null
                : Timestamp.fromDate(liveOrder.beneficiary.dateOfBirth!),
            'allergies': liveOrder.beneficiary.allergies,
            'healthConditions': liveOrder.beneficiary.healthConditions,
            'currentMedications': liveOrder.beneficiary.currentMedications,
            'hasHealthData': liveOrder.beneficiary.hasHealthData,
          },
          'lastMessage': systemText,
          'lastMessageType': 'system',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'userUnreadCount': 0,
          'pharmacyUnreadCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(initialMessageRef, {
          'senderId': 'system',
          'senderName': 'النظام',
          'senderType': 'system',
          'type': 'system',
          'text': systemText,
          'status': 'read',
          'isRead': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if ((liveOrder.chatId ?? '').trim() != chatId) {
        transaction.update(orderRef, {
          'chatId': chatId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    final chatSnapshot = await chatRef.get();
    if (!chatSnapshot.exists || chatSnapshot.data() == null) {
      throw Exception('تعذر فتح المحادثة');
    }

    return ChatThread.fromFirestore(chatSnapshot.data()!, chatSnapshot.id);
  }

  Stream<List<ChatThread>> getUserChatsStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _chatsRef
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatThread.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    final currentUser = _userController.user.value;
    final currentUserId =
        currentUser?.id ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return _messagesRef(chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return MessageModel.fromFirestore(
              doc.data(),
              doc.id,
              chatId,
              currentUserId,
            );
          }).toList(),
        );
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    final currentUser = _requireCurrentUser();
    final value = text.trim();
    if (value.isEmpty) return;
    await _ensureChatWritable(chatId);

    await _messagesRef(chatId).add({
      'senderId': currentUser.id,
      'senderName': currentUser.name,
      'senderType': 'user',
      'type': 'text',
      'text': value,
      'status': 'sent',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _chatsRef.doc(chatId).update({
      'lastMessage': value,
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'pharmacyUnreadCount': FieldValue.increment(1),
    });
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String imageUrl,
    String caption = '',
  }) async {
    final currentUser = _requireCurrentUser();
    await _ensureChatWritable(chatId);

    await _messagesRef(chatId).add({
      'senderId': currentUser.id,
      'senderName': currentUser.name,
      'senderType': 'user',
      'type': 'image',
      'text': caption.trim(),
      'imageUrl': imageUrl,
      'status': 'sent',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _chatsRef.doc(chatId).update({
      'lastMessage': caption.trim().isNotEmpty ? caption.trim() : 'صورة',
      'lastMessageType': 'image',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'pharmacyUnreadCount': FieldValue.increment(1),
    });
  }

  Future<void> sendFileMessage({
    required String chatId,
    required String fileUrl,
    required String fileName,
    String? fileExtension,
    String? mimeType,
    required int fileSizeBytes,
    String caption = '',
  }) async {
    final currentUser = _requireCurrentUser();
    await _ensureChatWritable(chatId);

    await _messagesRef(chatId).add({
      'senderId': currentUser.id,
      'senderName': currentUser.name,
      'senderType': 'user',
      'type': 'file',
      'text': caption.trim(),
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'status': 'sent',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _chatsRef.doc(chatId).update({
      'lastMessage': caption.trim().isNotEmpty ? caption.trim() : fileName,
      'lastMessageType': 'file',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'pharmacyUnreadCount': FieldValue.increment(1),
    });
  }

  Future<void> markChatAsRead(String chatId) async {
    final batch = _firestore.batch();

    batch.update(_chatsRef.doc(chatId), {
      'userUnreadCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final unreadMessages = await _messagesRef(chatId)
        .where('senderType', isEqualTo: 'pharmacy')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true, 'status': 'read'});
    }

    await batch.commit();
  }

  Stream<int> getUnreadCountStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _chatsRef.where('userId', isEqualTo: userId).snapshots().map((s) {
      int total = 0;
      for (final doc in s.docs) {
        total += (doc.data()['userUnreadCount'] ?? 0) as int;
      }
      return total;
    });
  }

  Future<void> deleteChat(String chatId) async {
    final messages = await _messagesRef(chatId).get();
    final batch = _firestore.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_chatsRef.doc(chatId));
    await batch.commit();
  }

  List<ParticipatingPharmacySummary> buildPharmacySummaries(
    List<ChatThread> threads,
  ) {
    final Map<String, List<ChatThread>> grouped = {};

    for (final thread in threads) {
      grouped.putIfAbsent(thread.pharmacyId, () => []).add(thread);
    }

    final result = grouped.entries.map((entry) {
      final pharmacyThreads = [...entry.value]
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      final latest = pharmacyThreads.first;
      final unread = pharmacyThreads.fold<int>(
        0,
        (sum, t) => sum + t.userUnreadCount,
      );

      return ParticipatingPharmacySummary(
        pharmacyId: latest.pharmacyId,
        pharmacyName: latest.pharmacyName,
        pharmacyImageUrl: latest.pharmacyImageUrl,
        pharmacyIsOnline: latest.pharmacyIsOnline,
        totalThreads: pharmacyThreads.length,
        unreadCount: unread,
        lastMessageTime: latest.lastMessageTime,
        latestThread: latest,
      );
    }).toList()..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    return result;
  }

  Map<String, List<ChatThread>> groupThreadsByPharmacy(
    List<ChatThread> threads,
  ) {
    final Map<String, List<ChatThread>> grouped = {};

    for (final thread in threads) {
      grouped.putIfAbsent(thread.pharmacyId, () => []).add(thread);
    }

    for (final entry in grouped.entries) {
      entry.value.sort(
        (a, b) => b.lastMessageTime.compareTo(a.lastMessageTime),
      );
    }

    return grouped;
  }
}
