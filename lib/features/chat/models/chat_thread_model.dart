import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String id; // same as chatId
  final String chatId;
  final String orderId;

  final String userId;
  final String userName;

  final String pharmacyId;
  final String pharmacyName;
  final String pharmacyImageUrl;
  final bool pharmacyIsOnline;

  final String beneficiaryId;
  final String beneficiaryName;
  final String beneficiaryType;
  final String relationLabel;

  final Map<String, dynamic> healthSnapshot;



  final String lastMessage;
  final String lastMessageType; // text / image / file / system
  final DateTime lastMessageTime;

  final int userUnreadCount;
  final int pharmacyUnreadCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatThread({
    required this.id,
    required this.chatId,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.pharmacyImageUrl,
    required this.pharmacyIsOnline,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.beneficiaryType,
    required this.relationLabel,
    required this.healthSnapshot,

    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageTime,
    required this.userUnreadCount,
    required this.pharmacyUnreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasUnread => userUnreadCount > 0;

  bool get hasPharmacyImage => pharmacyImageUrl.trim().isNotEmpty;

  String get lastMessagePreview {
    switch (lastMessageType) {
      case 'image':
        return lastMessage.trim().isNotEmpty ? '📷 $lastMessage' : '📷 صورة';
      case 'file':
        return lastMessage.trim().isNotEmpty ? '📎 $lastMessage' : '📎 ملف';
      case 'system':
        return lastMessage;
      default:
        return lastMessage;
    }
  }

  factory ChatThread.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return ChatThread(
      id: id,
      chatId: data['chatId'] ?? id,
      orderId: data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacyName: data['pharmacyName'] ?? 'صيدلية',
      pharmacyImageUrl: data['pharmacyImageUrl'] ?? '',
      pharmacyIsOnline: data['pharmacyIsOnline'] ?? false,
      beneficiaryId: data['beneficiaryId'] ?? '',
      beneficiaryName: data['beneficiaryName'] ?? '',
      beneficiaryType: data['beneficiaryType'] ?? '',
      relationLabel: data['relationLabel'] ?? '',
      healthSnapshot:
      (data['healthSnapshot'] as Map?)?.cast<String, dynamic>() ?? {},
      lastMessage: data['lastMessage'] ?? '',
      lastMessageType: data['lastMessageType'] ?? 'text',
      lastMessageTime: _parseTimestamp(data['lastMessageTime']),
      userUnreadCount: (data['userUnreadCount'] ?? 0) as int,
      pharmacyUnreadCount: (data['pharmacyUnreadCount'] ?? 0) as int,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'pharmacyImageUrl': pharmacyImageUrl,
      'pharmacyIsOnline': pharmacyIsOnline,
      'beneficiaryId': beneficiaryId,
      'beneficiaryName': beneficiaryName,
      'beneficiaryType': beneficiaryType,
      'relationLabel': relationLabel,
      'healthSnapshot': healthSnapshot,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userUnreadCount': userUnreadCount,
      'pharmacyUnreadCount': pharmacyUnreadCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ChatThread copyWith({
    String? id,
    String? chatId,
    String? orderId,
    String? userId,
    String? userName,
    String? pharmacyId,
    String? pharmacyName,
    String? pharmacyImageUrl,
    bool? pharmacyIsOnline,
    String? beneficiaryId,
    String? beneficiaryName,
    String? beneficiaryType,
    String? relationLabel,
    Map<String, dynamic>? healthSnapshot,

    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageTime,
    int? userUnreadCount,
    int? pharmacyUnreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatThread(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyImageUrl: pharmacyImageUrl ?? this.pharmacyImageUrl,
      pharmacyIsOnline: pharmacyIsOnline ?? this.pharmacyIsOnline,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      beneficiaryType: beneficiaryType ?? this.beneficiaryType,
      relationLabel: relationLabel ?? this.relationLabel,
      healthSnapshot: healthSnapshot ?? this.healthSnapshot,

      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
      pharmacyUnreadCount: pharmacyUnreadCount ?? this.pharmacyUnreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ParticipatingPharmacySummary {
  final String pharmacyId;
  final String pharmacyName;
  final String pharmacyImageUrl;
  final bool pharmacyIsOnline;
  final int totalThreads;
  final int unreadCount;
  final DateTime lastMessageTime;
  final ChatThread latestThread;

  const ParticipatingPharmacySummary({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.pharmacyImageUrl,
    required this.pharmacyIsOnline,
    required this.totalThreads,
    required this.unreadCount,
    required this.lastMessageTime,
    required this.latestThread,
  });

  bool get hasImage => pharmacyImageUrl.trim().isNotEmpty;
  bool get hasUnread => unreadCount > 0;
}