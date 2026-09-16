import 'package:flutter/material.dart';

import '../../orders/models/order_status.dart';
import '../../orders/services/order_service.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_pharmacy_service.dart';

class ChatListItem extends StatelessWidget {
  final ChatThread thread;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ChatListItem({
    super.key,
    required this.thread,
    required this.primaryColor,
    required this.onTap,
    this.onDelete,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      final h = dateTime.hour.toString().padLeft(2, '0');
      final m = dateTime.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else if (diff.inDays < 7) {
      const days = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      return days[dateTime.weekday - 1];
    }
    return '${dateTime.day}/${dateTime.month}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
      case 'pending':
        return Colors.orange;
      case 'underReview':
      case 'reviewing':
        return Colors.deepOrange;
      case 'confirmedReserved':
      case 'confirmed':
        return Colors.green;
      case 'partialOfferPending':
      case 'partiallyConfirmed':
        return Colors.teal;
      case 'preparing':
        return Colors.deepPurple;
      case 'rejected':
        return Colors.red;
      case 'ready':
        return Colors.indigo;
      case 'completed':
        return Colors.blueGrey;
      case 'cancelled':
        return Colors.redAccent;
      case 'notCollected':
        return Colors.brown;
      default:
        return primaryColor;
    }
  }

  bool _isLockedStatus(String status) {
    return status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected' ||
        status == 'notCollected';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(thread.chatId),
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF6)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: StreamBuilder<PharmacyModel?>(
              stream: ChatPharmacyService.instance.watchPharmacyById(
                thread.pharmacyId,
              ),
              builder: (context, pharmacySnapshot) {
                final pharmacy = pharmacySnapshot.data;

                final bool useFallback = pharmacy == null;

                final pharmacyName = useFallback
                    ? thread.pharmacyName
                    : pharmacy.displayName;

                final pharmacyImageUrl = useFallback
                    ? thread.pharmacyImageUrl
                    : pharmacy.imageUrl;

                final pharmacyIsOnline = useFallback
                    ? thread.pharmacyIsOnline
                    : pharmacy.isOnline;

                final hasImage = pharmacyImageUrl.trim().isNotEmpty;

                return Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFF4F8FC),
                          backgroundImage: hasImage
                              ? NetworkImage(pharmacyImageUrl)
                              : null,
                          child: !hasImage
                              ? Icon(Icons.local_pharmacy, color: primaryColor)
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<OrderModel?>(
                        stream: OrderService.instance.watchOrderById(
                          thread.orderId,
                        ),
                        builder: (context, orderSnapshot) {
                          final order = orderSnapshot.data;
                          final status = order?.status.value ?? '';
                          final statusLabel = order?.statusLabel ?? '...';
                          final statusColor = _statusColor(status);
                          final isLocked = _isLockedStatus(status);
                          final orderNumberText =
                              order?.orderNumber?.trim().isNotEmpty == true
                              ? 'طلب #${order!.orderNumber}'
                              : 'طلب';

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            pharmacyName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(thread.lastMessageTime),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      thread.beneficiaryName.isNotEmpty
                                          ? thread.beneficiaryName
                                          : 'المستفيد غير محدد',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      orderNumberText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11.4,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (isLocked) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 12,
                                                  color: Colors.grey[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'مقفلة',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      thread.lastMessagePreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: thread.hasUnread
                                            ? Colors.black87
                                            : Colors.grey[650],
                                        fontSize: 12.7,
                                        fontWeight: thread.hasUnread
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (thread.hasUnread)
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          thread.userUnreadCount > 99
                                              ? '99+'
                                              : thread.userUnreadCount
                                                    .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 24),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
