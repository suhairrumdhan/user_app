import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ChatUploadResult {
  final String url;
  final String fileName;
  final String? extension;
  final String? mimeType;
  final int sizeBytes;

  const ChatUploadResult({
    required this.url,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
  });
}

class PickedChatFile {
  final String fileName;
  final String? extension;
  final String? mimeType;
  final int sizeBytes;
  final Uint8List? bytes;
  final String? path;

  const PickedChatFile({
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    this.bytes,
    this.path,
  });
}

class ChatUploadService {
  ChatUploadService._();
  static final ChatUploadService instance = ChatUploadService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<PickedChatFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb,
      // file_picker's Android compression writes to the public Pictures folder
      // and can crash under scoped storage. Upload the selected original file.
      allowCompression: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final inferredMimeType = _inferMimeType(
      file.name,
      file.extension,
      fallback: 'image/jpeg',
    );

    return PickedChatFile(
      fileName: file.name,
      extension: file.extension,
      mimeType: inferredMimeType,
      sizeBytes: file.size,
      bytes: file.bytes,
      path: file.path,
    );
  }

  Future<PickedChatFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final inferredMimeType = _inferMimeType(
      file.name,
      file.extension,
      fallback: 'application/octet-stream',
    );

    return PickedChatFile(
      fileName: file.name,
      extension: file.extension,
      mimeType: inferredMimeType,
      sizeBytes: file.size,
      bytes: file.bytes,
      path: file.path,
    );
  }

  Future<ChatUploadResult> uploadImage({
    required String chatId,
    required PickedChatFile file,
  }) async {
    return _uploadFile(folder: 'chat_images', chatId: chatId, file: file);
  }

  Future<ChatUploadResult> uploadFile({
    required String chatId,
    required PickedChatFile file,
  }) async {
    return _uploadFile(folder: 'chat_files', chatId: chatId, file: file);
  }

  Future<ChatUploadResult> _uploadFile({
    required String folder,
    required String chatId,
    required PickedChatFile file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = _sanitizeFileName(file.fileName);
    final storagePath = '$folder/$chatId/${timestamp}_$safeFileName';

    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(contentType: file.mimeType);

    UploadTask uploadTask;

    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('Web upload requires file bytes');
      }
      uploadTask = ref.putData(file.bytes!, metadata);
    } else {
      if (file.path == null || file.path!.isEmpty) {
        throw Exception('File path is missing');
      }
      uploadTask = ref.putFile(File(file.path!), metadata);
    }

    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();

    return ChatUploadResult(
      url: url,
      fileName: file.fileName,
      extension: file.extension,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
    );
  }

  String _inferMimeType(
    String fileName,
    String? extension, {
    required String fallback,
  }) {
    final ext = (extension ?? _extractExtension(fileName)).toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return fallback;
    }
  }

  String _extractExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index == -1 || index == fileName.length - 1) return '';
    return fileName.substring(index + 1);
  }

  String _sanitizeFileName(String fileName) {
    final sanitized = fileName
        .trim()
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    return sanitized.isEmpty ? 'attachment' : sanitized;
  }
}
