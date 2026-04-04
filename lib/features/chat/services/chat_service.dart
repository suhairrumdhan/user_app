import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:user_application/features/pharmacy/models/pharmacy_model.dart';

import '../models/chat_models.dart';
import '../../profile/controllers/user_controller.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

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

  /// =============================
  /// 🔥 تحميل الصيدلية كاملة (صح)
  /// =============================
  Future<PharmacyModel> _getPharmacyFull(String pharmacyId) async {
    final doc = await _firestore
        .collection('pharmacies')
        .doc(pharmacyId)
        .get();

    if (!doc.exists) {
      throw Exception('Pharmacy not found');
    }

    return PharmacyModel.fromFirestore(doc);
  }

  /// =============================
  /// 🔍 البحث
  /// =============================
  Future<List<PharmacyModel>> searchPharmacies(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final normalizedQuery = query.trim();

      final directSearch = await _firestore
          .collection('pharmacies')
          .where('pharmacyName', isGreaterThanOrEqualTo: normalizedQuery)
          .where('pharmacyName', isLessThan: '$normalizedQuery\uf8ff')
          .get();

      if (directSearch.docs.isNotEmpty) {
        return directSearch.docs
            .map((doc) => PharmacyModel.fromFirestore(doc))
            .toList();
      }

      final allPharmacies = await _firestore.collection('pharmacies').get();

      return allPharmacies.docs.where((doc) {
        final name =
            doc.data()['pharmacyName']?.toString().toLowerCase() ?? '';
        return name.contains(normalizedQuery.toLowerCase());
      }).map((doc) => PharmacyModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error searching pharmacies: $e');
      return [];
    }
  }

  /// =============================
  /// 💬 إنشاء دردشة
  /// =============================
  Future<Chat> createNewChat(PharmacyModel pharmacy) async {
    try {
      final currentUser = _requireCurrentUser();
      final userId = currentUser.id;

      final existingChat = await _firestore
          .collection('chats')
          .where('userId', isEqualTo: userId)
          .where('pharmacyId', isEqualTo: pharmacy.id)
          .limit(1)
          .get();

      if (existingChat.docs.isNotEmpty) {
        final doc = existingChat.docs.first;
        final data = doc.data();

        return Chat(
          id: doc.id,
          pharmacy: pharmacy,
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          userUnreadCount: data['userUnreadCount'] ?? 0,
        );
      }

      final chatDoc = await _firestore.collection('chats').add({
        'userId': userId,
        'pharmacyId': pharmacy.id,
        'userName': currentUser.name,
        'userImage': currentUser.profileImageUrl,
        'pharmacyName': pharmacy.pharmacyName,
        'pharmacyIsOnline': pharmacy.isOnline,
        'pharmacyImageUrl': pharmacy.imageUrl,
        'pharmacyAddress': pharmacy.address,
        'lastMessage': 'بدأ المحادثة',
        'lastMessageType': 'text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userUnreadCount': 0,
      });

      return Chat(
        id: chatDoc.id,
        pharmacy: pharmacy,
        lastMessage: 'بدأ المحادثة',
        lastMessageTime: DateTime.now(),
        userUnreadCount: 0,
      );
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  /// =============================
  /// 📩 إرسال رسالة
  /// =============================
  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    try {
      final currentUser = _requireCurrentUser();

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.id,
        'senderName': currentUser.name,
        'senderType': 'user',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'status': 'sent',
        'isRead': false,
      });

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pharmacyUnreadCount': FieldValue.increment(1),  // Fixed increment syntax
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// =============================
  /// 📥 جلب المحادثات (Stream)
  /// =============================
  Stream<List<Chat>> getUserChatsStream() {
    final userId = _userController.user.value?.id;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Chat> chats = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final pharmacyId = data['pharmacyId'];

        PharmacyModel pharmacy;

        try {
          pharmacy = await _getPharmacyFull(pharmacyId);
        } catch (_) {
          /// fallback سريع بدون crash
          pharmacy = PharmacyModel(
            id: pharmacyId,
            email: '',
            pharmacyName: data['pharmacyName'] ?? 'صيدلية',
            ownerName: '',
            licenseNumber: '',
            licenseFileUrl: '',
            ownerIdFileUrl: '',
            ownerIdNumber: '',
            phoneNumber: '',
            imageUrl: data['pharmacyImageUrl'] ?? '',
            status: 'approved',
            is24Hours: false,
            isOnline: data['pharmacyIsOnline'] ?? false,
            address: data['pharmacyAddress'] ?? '',
            latitude: null,
            longitude: null,
            locationCoordinates: const [],
            location: const {},
            categories: const [],
          );
        }

        chats.add(
          Chat(
            id: doc.id,
            pharmacy: pharmacy,
            lastMessage: data['lastMessage'] ?? '',
            lastMessageTime:
            (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            userUnreadCount: data['userUnreadCount'] ?? 0,
          ),
        );
      }

      return chats;
    });
  }

  /// =============================
  /// 📨 الرسائل
  /// =============================
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
      final currentUser = _userController.user.value;

      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Message.fromFirestore(
          data,
          doc.id,
          chatId,
          currentUser?.id ?? '',
        );
      }).toList();
    });
  }

  /// =============================
  /// ✔️ قراءة الرسائل
  /// =============================
  Future<void> markChatAsRead(String chatId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'userUnreadCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<int> getUnreadCountStream() {
    final userId = _userController.user.value?.id;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['userUnreadCount'] ?? 0) as int;
      }

      return total;
    });
  }

  /// =============================
  /// ❌ حذف
  /// =============================
  Future<void> deleteChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).delete();
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      rethrow;
    }
  }
}