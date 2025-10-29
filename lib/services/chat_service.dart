import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/chat_models.dart';
import '../controllers/user_controller.dart'; // استيراد الـ Controller

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _firestore = FirebaseFirestore.instance;

  // الحصول على instance من UserController
  UserController get _userController => Get.find<UserController>();

  /// 🔍 البحث عن الصيدليات بالاسم
  // Future<List<Pharmacy>> searchPharmacies(String query) async {
  //   if (query.isEmpty) {
  //     return [];
  //   }
  //
  //   try {
  //     final queryLower = query.toLowerCase();
  //
  //     final pharmaciesSnapshot = await _firestore
  //         .collection('pharmacies')
  //         .where('name', isGreaterThanOrEqualTo: queryLower)
  //         .where('name', isLessThan: queryLower + '\uf8ff') // 🔥 هذا أفضل من 'z'
  //         .get();
  //
  //     return pharmaciesSnapshot.docs.map((doc) {
  //       final data = doc.data();
  //       return Pharmacy(
  //         id: doc.id,
  //         name: data['name'] ?? 'صيدلية',
  //         isOnline: data['isOnline'] ?? false,
  //         imageUrl: data['imageUrl'],
  //         address: data['address'],
  //       );
  //     }).toList();
  //   } catch (e) {
  //     print('Error searching pharmacies: $e');
  //     return [];
  //   }
  // }
  Future<List<Pharmacy>> searchPharmacies(String query) async {
    if (query.isEmpty) return [];

    try {
      // محاولة البحث المباشر أولاً
      final directSearch = await _firestore
          .collection('pharmacies')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .get();

      if (directSearch.docs.isNotEmpty) {
        return _mapPharmacyDocs(directSearch.docs);
      }

      // إذا لم تنجح، جلب الكل والتصفية محلياً
      final allPharmacies = await _firestore
          .collection('pharmacies')
          .get();

      return allPharmacies.docs
          .where((doc) {
        final name = doc.data()['name']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase());
      })
          .map(_mapPharmacyDoc)
          .toList();
    } catch (e) {
      print('Error searching pharmacies: $e');
      return [];
    }
  }

  Pharmacy _mapPharmacyDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Pharmacy(
      id: doc.id,
      name: data['name'] ?? 'صيدلية',
      isOnline: data['isOnline'] ?? false,
      imageUrl: data['imageUrl'],
      address: data['address'],
    );
  }

  List<Pharmacy> _mapPharmacyDocs(List<DocumentSnapshot> docs) {
    return docs.map(_mapPharmacyDoc).toList();
  }
  /// 💬 إنشاء محادثة جديدة مع صيدلية
  Future<Chat> createNewChat(Pharmacy pharmacy) async {
    try {
      // ✅ الحصول على المستخدم الحالي من الـ Controller
      final currentUser = _userController.user.value;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final userId = currentUser.id;

      // البحث إذا كانت هناك محادثة موجودة مسبقاً
      final existingChat = await _firestore
          .collection('chats')
          .where('userId', isEqualTo: userId)
          .where('pharmacyId', isEqualTo: pharmacy.id)
          .limit(1)
          .get();

      if (existingChat.docs.isNotEmpty) {
        // إرجاع المحادثة الموجودة
        final doc = existingChat.docs.first;
        final data = doc.data();
        return Chat(
          id: doc.id,
          pharmacy: pharmacy,
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          unreadCount: data['unreadCount'] ?? 0,
        );
      }

      // إنشاء محادثة جديدة
      final chatDoc = await _firestore.collection('chats').add({
        'userId': userId,
        'pharmacyId': pharmacy.id,
        'userName': currentUser.name, // حفظ اسم المستخدم
        'userImage': currentUser.profileImageUrl, // حفظ صورة المستخدم
        'lastMessage': 'بدأ المحادثة',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });

      // إرجاع المحادثة الجديدة
      return Chat(
        id: chatDoc.id,
        pharmacy: pharmacy,
        lastMessage: 'بدأ المحادثة',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
      );
    } catch (e) {
      print('Error creating new chat: $e');
      throw e;
    }
  }

  /// ✉️ إرسال رسالة أولى في المحادثة الجديدة
  Future<void> sendFirstMessage(String chatId, String messageText) async {
    try {
      // ✅ الحصول على المستخدم الحالي من الـ Controller
      final currentUser = _userController.user.value;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.id, // ✅ استخدام المعرف الحقيقي
        'senderName': currentUser.name, // اسم المرسل
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isMe': true,
        'type': 'text',
      });

      // تحديث آخر رسالة في المحادثة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending first message: $e');
      throw e;
    }
  }

  /// 📩 إرسال رسالة عادية
  Future<void> sendMessage({
    required String chatId,
    required String text,
    required bool isMe,
  }) async {
    try {
      // ✅ الحصول على المستخدم الحالي من الـ Controller
      final currentUser = _userController.user.value;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.id,
        'senderName': currentUser.name,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isMe': isMe,
        'type': 'text',
      });

      // تحديث آخر رسالة في المحادثة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  /// 📥 جلب محادثات المستخدم الحالي
  Future<List<Chat>> getUserChats() async {
    try {
      // ✅ الحصول على المستخدم الحالي من الـ Controller
      final currentUser = _userController.user.value;
      if (currentUser == null) {
        return [];
      }

      final userId = currentUser.id;

      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('userId', isEqualTo: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      List<Chat> chats = [];

      for (final doc in chatsSnapshot.docs) {
        final data = doc.data();
        final pharmacy = await _getPharmacyInfo(data['pharmacyId']);

        chats.add(Chat(
          id: doc.id,
          pharmacy: pharmacy,
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          unreadCount: data['unreadCount'] ?? 0,
        ));
      }

      return chats;
    } catch (e) {
      print('Error getting user chats: $e');
      return [];
    }
  }

  Future<Pharmacy> _getPharmacyInfo(String pharmacyId) async {
    final pharmacyDoc = await _firestore
        .collection('pharmacies')
        .doc(pharmacyId)
        .get();

    final data = pharmacyDoc.data() ?? {};

    return Pharmacy(
      id: pharmacyId,
      name: data['name'] ?? 'صيدلية',
      isOnline: data['isOnline'] ?? false,
      imageUrl: data['imageUrl'],
      address: data['address'],
    );
  }

  // 🔥 إضافة دالة getMessages المفقودة
  Future<List<Message>> getMessages(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false) // من الأقدم إلى الأحدث
          .get();

      return messagesSnapshot.docs.map((doc) {
        final data = doc.data();

        // ✅ مقارنة مع المستخدم الحالي لتحديد isMe
        final currentUser = _userController.user.value;
        final isMyMessage = currentUser != null && data['senderId'] == currentUser.id;

        return Message(
          id: doc.id,
          chatId: chatId,
          senderId: data['senderId'] ?? '',
          text: data['text'] ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isMe: data['isMe'] ?? isMyMessage,
        );
      }).toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // 🔥 إضافة دالة getMessagesStream للـ Real-time updates
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // من الأحدث إلى الأقدم
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        final currentUser = _userController.user.value;
        final isMyMessage = currentUser != null && data['senderId'] == currentUser.id;

        return Message(
          id: doc.id,
          chatId: chatId,
          senderId: data['senderId'] ?? '',
          text: data['text'] ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isMe: data['isMe'] ?? isMyMessage,
        );
      }).toList();
    });
  }

}