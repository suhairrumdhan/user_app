import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;

  final String senderId;
  final String senderName;
  final String senderType; // user / pharmacy / system

  final String type; // text / image / file / system
  final String text;

  final String? imageUrl;

  final String? fileUrl;
  final String? fileName;
  final String? fileExtension;
  final String? mimeType;
  final int? fileSizeBytes;

  final String status; // sent / delivered / read
  final bool isRead;
  final DateTime timestamp;

  final bool isMe;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.type,
    required this.text,
    required this.status,
    required this.isRead,
    required this.timestamp,
    required this.isMe,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileExtension,
    this.mimeType,
    this.fileSizeBytes,
  });

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
  bool get isSystem => type == 'system';

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasFile => (fileUrl ?? '').trim().isNotEmpty;

  String get displayFileName {
    final raw = (fileName ?? '').trim();
    if (raw.isNotEmpty) return raw;
    return 'ملف';
  }

  factory MessageModel.fromFirestore(
      Map<String, dynamic> data,
      String id,
      String chatId,
      String currentUserId,
      ) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderType: data['senderType'] ?? '',
      type: data['type'] ?? 'text',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileExtension: data['fileExtension'],
      mimeType: data['mimeType'],
      fileSizeBytes: data['fileSizeBytes'],
      status: data['status'] ?? 'sent',
      isRead: data['isRead'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: data['senderId'] == currentUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'type': type,
      'text': text,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'status': status,
      'isRead': isRead,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}