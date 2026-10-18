import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/chat_thread_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/chat_upload_service.dart';

class ChatDetailController extends GetxController {
  final ChatThread thread;

  ChatDetailController({required this.thread});

  final ChatService _chatService = ChatService.instance;
  final ChatUploadService _uploadService = ChatUploadService.instance;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  StreamSubscription<List<MessageModel>>? _messagesSub;

  final RxBool isUploading = false.obs;
  final RxBool isSending = false.obs;
  final RxList<MessageModel> messages = <MessageModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    _listenMessages();
    markAsRead();
  }

  void _listenMessages() {
    _messagesSub?.cancel();
    _messagesSub = _chatService.getMessagesStream(thread.chatId).listen((data) {
      messages.assignAll(data);
      scrollToBottom();
    });
  }

  Future<void> markAsRead() async {
    await _chatService.markChatAsRead(thread.chatId);
  }

  Future<void> sendText() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending.value) return;

    try {
      isSending.value = true;
      await _chatService.sendTextMessage(chatId: thread.chatId, text: text);
      messageController.clear();
      scrollToBottom();
    } finally {
      isSending.value = false;
    }
  }

  Future<void> pickAndSendImage() async {
    if (isUploading.value) return;

    try {
      isUploading.value = true;
      final picked = await _uploadService.pickImage();
      if (picked == null) return;

      final uploaded = await _uploadService.uploadImage(
        chatId: thread.chatId,
        file: picked,
      );

      await _chatService.sendImageMessage(
        chatId: thread.chatId,
        imageUrl: uploaded.url,
      );
      scrollToBottom();
    } catch (error, stackTrace) {
      _handleAttachmentError(error, stackTrace, attachmentType: 'الصورة');
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> pickAndSendFile() async {
    if (isUploading.value) return;

    try {
      isUploading.value = true;
      final picked = await _uploadService.pickFile();
      if (picked == null) return;

      final uploaded = await _uploadService.uploadFile(
        chatId: thread.chatId,
        file: picked,
      );

      await _chatService.sendFileMessage(
        chatId: thread.chatId,
        fileUrl: uploaded.url,
        fileName: uploaded.fileName,
        fileExtension: uploaded.extension,
        mimeType: uploaded.mimeType,
        fileSizeBytes: uploaded.sizeBytes,
      );
      scrollToBottom();
    } catch (error, stackTrace) {
      _handleAttachmentError(error, stackTrace, attachmentType: 'الملف');
    } finally {
      isUploading.value = false;
    }
  }

  void _handleAttachmentError(
    Object error,
    StackTrace stackTrace, {
    required String attachmentType,
  }) {
    debugPrint('Failed to attach $attachmentType: $error');
    debugPrintStack(stackTrace: stackTrace);

    final rawError = error.toString().toLowerCase();
    final message =
        rawError.contains('network') ||
            rawError.contains('connection') ||
            rawError.contains('unavailable')
        ? 'تعذر رفع $attachmentType. تحقق من اتصال الإنترنت وحاول مرة أخرى.'
        : rawError.contains('permission') ||
              rawError.contains('unauthorized') ||
              rawError.contains('denied')
        ? 'لا توجد صلاحية كافية لإرفاق $attachmentType.'
        : rawError.contains('path is missing') || rawError.contains('not found')
        ? 'تعذر الوصول إلى $attachmentType المحدد. اختره مرة أخرى.'
        : 'تعذر إرفاق $attachmentType. حاول مرة أخرى.';

    Get.snackbar(
      'تعذر إرسال المرفق',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void onClose() {
    _messagesSub?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
