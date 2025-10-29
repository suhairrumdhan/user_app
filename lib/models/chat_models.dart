import 'package:cloud_firestore/cloud_firestore.dart';

class Pharmacy {
  final String id;
  final String name;
  final bool isOnline;
  final String? imageUrl;
  final double? distance;
  final String? address; // 🔥 حقل جديد



  Pharmacy({
    required this.id,
    required this.name,
    required this.isOnline,
    this.imageUrl,
    this.distance,
    this.address, // 🔥 إضافة العنوان

  });

  factory Pharmacy.fromFirestore(Map<String, dynamic> data, String id) {
    return Pharmacy(
      id: id,
      name: data['name'] ?? 'صيدلية',
      isOnline: data['isOnline'] ?? false,
      imageUrl: data['imageUrl'],
      distance: data['distance']?.toDouble(),
      address: data['address'], // 🔥 تحويل العنوان

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isOnline': isOnline,
      'imageUrl': imageUrl,
      'distance': distance,
      'address': address, // 🔥 حفظ العنوان

    };
  }
}

class Chat {
  final String id;
  final Pharmacy pharmacy;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  Chat({
    required this.id,
    required this.pharmacy,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Chat.fromFirestore(Map<String, dynamic> data, String id, Pharmacy pharmacy) {
    return Chat(
      id: id,
      pharmacy: pharmacy,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: data['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacy.id,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
    };
  }
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  factory Message.fromFirestore(Map<String, dynamic> data, String id, String chatId) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: data['isMe'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isMe': isMe,
    };
  }
}