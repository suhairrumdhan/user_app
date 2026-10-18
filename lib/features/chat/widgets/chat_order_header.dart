import 'package:flutter/material.dart';

import '../../orders/models/order_status.dart';
import '../../orders/services/order_service.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_pharmacy_service.dart';

class ChatOrderHeader extends StatelessWidget {
  final ChatThread thread;
  final Color primaryColor;

  const ChatOrderHeader({
    super.key,
    required this.thread,
    required this.primaryColor,
  });

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PharmacyModel?>(
      stream: ChatPharmacyService.instance.watchPharmacyById(thread.pharmacyId),
      builder: (context, pharmacySnapshot) {
        final pharmacy = pharmacySnapshot.data;

        final pharmacyName = pharmacy?.displayName ?? thread.pharmacyName;
        final pharmacyImageUrl = pharmacy?.imageUrl ?? thread.pharmacyImageUrl;
        final pharmacyIsOnline = pharmacy?.isOnline ?? thread.pharmacyIsOnline;

        final hasImage = pharmacyImageUrl.trim().isNotEmpty;

        return StreamBuilder<OrderModel?>(
          stream: OrderService.instance.watchOrderById(thread.orderId),
          builder: (context, orderSnapshot) {
            final order = orderSnapshot.data;

            final status = order?.status.value ?? '';
            final statusLabel = order?.statusLabel ?? '...';
            final statusColor = _statusColor(status);

            /// 🔥 أهم سطر (حل المشكلة)
            final orderNumberText =
                (order != null &&
                    order.orderNumber != null &&
                    order.orderNumber!.trim().isNotEmpty)
                ? 'طلب #${order.orderNumber}'
                : 'جارٍ تحميل الطلب…';

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: primaryColor.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              image: hasImage
                                  ? DecorationImage(
                                      image: NetworkImage(pharmacyImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !hasImage
                                ? Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: primaryColor,
                                  )
                                : null,
                          ),
                          if (pharmacyIsOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.8,
                              ),
                            ),
                            const SizedBox(height: 4),

                            /// 👤 المستفيد
                            Text(
                              thread.beneficiaryName.isNotEmpty
                                  ? thread.beneficiaryName
                                  : 'المستفيد غير محدد',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 6),

                            /// 🔥 رقم الطلب (المهم)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7FB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                orderNumberText,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// الحالة
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
