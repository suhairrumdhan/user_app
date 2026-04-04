import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/features/pharmacy/models/pharmacy_model.dart';

/// =============================
/// 💬 Chat Model (محسّن)
/// =============================
class Chat {
  final String id;
  final PharmacyModel pharmacy;

  final String lastMessage;
  final String lastMessageType; // 🔥 جديد (text / image / file)

  final DateTime lastMessageTime;
  final int userUnreadCount;

  Chat({
    required this.id,
    required this.pharmacy,
    required this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageType = 'text',
    this.userUnreadCount = 0,
  });

  /// 🔹 Preview ذكي
  String get lastMessagePreview {
    switch (lastMessageType) {
      case 'image':
        return '📷 صورة';
      case 'file':
        return '📎 ملف';
      default:
        return lastMessage;
    }
  }

  /// 🔹 هل فيه رسائل غير مقروءة
  bool get hasUnread => userUnreadCount > 0;

  /// 🔹 Factory
  factory Chat.fromFirestore(
      Map<String, dynamic> data,
      String id,
      PharmacyModel pharmacy,
      ) {
    return Chat(
      id: id,
      pharmacy: pharmacy,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageType: data['lastMessageType'] ?? 'text',
      lastMessageTime:
      (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userUnreadCount: data['userUnreadCount'] ?? 0,
    );
  }

  /// 🔹 Map
  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacy.id,
      'pharmacyName': pharmacy.pharmacyName,
      'pharmacyImageUrl': pharmacy.imageUrl,
      'pharmacyIsOnline': pharmacy.isOnline,
      'pharmacyAddress': pharmacy.address,

      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': FieldValue.serverTimestamp(),

      'userUnreadCount': userUnreadCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 🔹 copyWith
  Chat copyWith({
    String? id,
    PharmacyModel? pharmacy,
    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageTime,
    int? userUnreadCount,
  }) {
    return Chat(
      id: id ?? this.id,
      pharmacy: pharmacy ?? this.pharmacy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
    );
  }
}

/// =============================
/// 📨 Message Model (احترافي)
/// =============================
class Message {
  final String id;
  final String chatId;
  final String senderId;

  final String text;
  final DateTime timestamp;
  final bool isMe;

  /// 🔥 إضافات احترافية
  final String type; // text / image / file
  final String status; // sent / delivered / read
  final bool isRead;

  final String? imageUrl;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.type = 'text',
    this.status = 'sent',
    this.isRead = false,
    this.imageUrl,
  });

  /// 🔹 هل صورة
  bool get isImage => type == 'image';

  /// 🔹 هل نص
  bool get isText => type == 'text';

  /// 🔹 Factory
  factory Message.fromFirestore(
      Map<String, dynamic> data,
      String id,
      String chatId,
      String currentUserId,
      ) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp:
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: data['senderId'] == currentUserId,
      type: data['type'] ?? 'text',
      status: data['status'] ?? 'sent',
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
    );
  }

  /// 🔹 Map
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),

      'type': type,
      'status': status,
      'isRead': isRead,

      'imageUrl': imageUrl,
    };
  }

  /// 🔹 copyWith
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    String? type,
    String? status,
    bool? isRead,
    String? imageUrl,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}