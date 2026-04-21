import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
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

  Stream<List<ChatThread>> getUserChatsStream() {
    final userId = _userController.user.value?.id;
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

    return _messagesRef(chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(
          doc.data(),
          doc.id,
          chatId,
          currentUser?.id ?? '',
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
      batch.update(doc.reference, {
        'isRead': true,
        'status': 'read',
      });
    }

    await batch.commit();
  }

  Stream<int> getUnreadCountStream() {
    final userId = _userController.user.value?.id;
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
    }).toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    return result;
  }

  Map<String, List<ChatThread>> groupThreadsByPharmacy(List<ChatThread> threads) {
    final Map<String, List<ChatThread>> grouped = {};

    for (final thread in threads) {
      grouped.putIfAbsent(thread.pharmacyId, () => []).add(thread);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    }

    return grouped;
  }
}