import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../orders/models/order_status.dart';
import '../../orders/services/order_service.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../controllers/chat_detail_controller.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_pharmacy_service.dart';
import '../widgets/attachment_picker_sheet.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_order_header.dart';

class ChatDetailScreen extends StatelessWidget {
  final ChatThread thread;

  ChatDetailScreen({super.key, required this.thread});

  final Color _primaryColor = const Color(0xFF5EABD6);

  bool _isLockedStatus(String status) {
    return status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected';
  }

  String _lockedMessage(String status) {
    switch (status) {
      case 'completed':
        return 'تم إيقاف المراسلة لأن الطلب مكتمل.';
      case 'cancelled':
        return 'تم إيقاف المراسلة لأن الطلب ملغي.';
      case 'rejected':
        return 'تم إيقاف المراسلة لأن الطلب مرفوض.';
      default:
        return 'المراسلة غير متاحة.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ChatDetailController(thread: thread),
      tag: thread.chatId,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<PharmacyModel?>(
        stream: ChatPharmacyService.instance.watchPharmacyById(
          thread.pharmacyId,
        ),
        builder: (context, pharmacySnapshot) {
          final pharmacy = pharmacySnapshot.data;
          final pharmacyName = pharmacy?.displayName ?? thread.pharmacyName;
          final pharmacyImageUrl =
              pharmacy?.imageUrl ?? thread.pharmacyImageUrl;
          final pharmacyIsOnline =
              pharmacy?.isOnline ?? thread.pharmacyIsOnline;
          final hasImage = pharmacyImageUrl.trim().isNotEmpty;

          return StreamBuilder<OrderModel?>(
            stream: OrderService.instance.watchOrderById(thread.orderId),
            builder: (context, orderSnapshot) {
              final order = orderSnapshot.data;
              final status = order?.status.value ?? '';
              final isLocked = _isLockedStatus(status);

              return Scaffold(
                backgroundColor: _primaryColor,
                appBar: AppBar(
                  backgroundColor: _primaryColor,
                  elevation: 0,
                  titleSpacing: 0,
                  title: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: Colors.white,
                            backgroundImage: hasImage
                                ? NetworkImage(pharmacyImageUrl)
                                : null,
                            child: !hasImage
                                ? Icon(
                                    Icons.local_pharmacy,
                                    color: _primaryColor,
                                  )
                                : null,
                          ),
                          if (pharmacyIsOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pharmacyIsOnline ? 'متصل الآن' : 'غير متصل',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                body: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7FAFD),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                  ),
                  child: Column(
                    children: [
                      ChatOrderHeader(
                        thread: thread,
                        primaryColor: _primaryColor,
                      ),
                      Expanded(
                        child: Obx(() {
                          final messages = controller.messages;

                          if (messages.isEmpty) {
                            return const Center(
                              child: Text(
                                'لا توجد رسائل بعد',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: controller.scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                            itemCount: messages.length,
                            itemBuilder: (_, index) {
                              return ChatMessageBubble(
                                message: messages[index],
                                primaryColor: _primaryColor,
                              );
                            },
                          );
                        }),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 12,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Obx(() {
                            final busy =
                                controller.isUploading.value ||
                                controller.isSending.value;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLocked)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.orange,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _lockedMessage(status),
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: busy || isLocked
                                          ? null
                                          : () {
                                              showModalBottomSheet(
                                                context: context,
                                                backgroundColor:
                                                    Colors.transparent,
                                                builder: (_) =>
                                                    AttachmentPickerSheet(
                                                      onImageTap: () async {
                                                        Navigator.pop(context);
                                                        await controller
                                                            .pickAndSendImage();
                                                      },
                                                      onFileTap: () async {
                                                        Navigator.pop(context);
                                                        await controller
                                                            .pickAndSendFile();
                                                      },
                                                    ),
                                              );
                                            },
                                      icon: Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: (busy || isLocked)
                                            ? Colors.grey
                                            : _primaryColor,
                                        size: 28,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F7FB),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: TextField(
                                          controller:
                                              controller.messageController,
                                          minLines: 1,
                                          maxLines: 4,
                                          enabled: !isLocked && !busy,
                                          textInputAction: TextInputAction.send,
                                          onSubmitted: (_) {
                                            if (!isLocked) {
                                              controller.sendText();
                                            }
                                          },
                                          decoration: InputDecoration(
                                            hintText: isLocked
                                                ? 'المراسلة متوقفة لهذا الطلب'
                                                : 'اكتب رسالة...',
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: (busy || isLocked)
                                          ? null
                                          : controller.sendText,
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: (busy || isLocked)
                                              ? Colors.grey
                                              : _primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: busy
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
