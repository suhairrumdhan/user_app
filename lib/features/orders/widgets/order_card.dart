import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.received:
        return const Color(0xFFFFA726);
      case OrderStatus.underReview:
        return const Color(0xFF42A5F5);
      case OrderStatus.confirmedReserved:
        return const Color(0xFF66BB6A);
      case OrderStatus.partialOfferPending:
        return const Color(0xFFFF7043);
      case OrderStatus.preparing:
        return const Color(0xFF7E57C2);
      case OrderStatus.rejected:
        return const Color(0xFFE53935);
      case OrderStatus.ready:
        return const Color(0xFF26A69A);
      case OrderStatus.completed:
        return const Color(0xFF43A047);
      case OrderStatus.cancelled:
        return const Color(0xFFD32F2F);
      case OrderStatus.notCollected:
        return const Color(0xFF6D4C41);
      case OrderStatus.unknown:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month}/${date.day}';
  }

  String get _orderReference {
    final orderNumber = order.orderNumber?.trim();
    return orderNumber != null && orderNumber.isNotEmpty
        ? orderNumber
        : order.id;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SearchUiColors.primary.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _iconBox(),
                const SizedBox(width: 9),
                Expanded(child: _titleSection()),
                _statusBadge(statusColor),
              ],
            ),
            const SizedBox(height: 9),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                _compactInfo(Iconsax.box, '${order.totalItemsCount} قطعة'),
                const SizedBox(width: 12),
                _compactInfo(
                  Iconsax.money_4,
                  order.estimatedTotalPrice != null
                      ? '${order.estimatedTotalPrice!.toStringAsFixed(2)} د.ل'
                      : 'السعر غير محدد',
                ),
                const SizedBox(width: 12),
                _compactInfo(Iconsax.calendar_1, _formatDate(order.createdAt)),
                const Spacer(),
                if (order.containsInsurance) _tag('تأمين'),
                const SizedBox(width: 5),
                const Icon(Iconsax.arrow_left_2, size: 16),
              ],
            ),
            if (order.status == OrderStatus.partialOfferPending) ...[
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF8A3D)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Iconsax.notification_bing,
                      color: Color(0xFFFF6D00),
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'لديك عرض من الصيدلية بانتظار ردك',
                        style: TextStyle(
                          color: Color(0xFF9A3F00),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Iconsax.hospital, color: Colors.white, size: 18),
    );
  }

  Widget _titleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.pharmacy.pharmacyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: SearchUiColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'طلب رقم $_orderReference',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: SearchUiColors.darkText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'لـ ${order.beneficiary.name}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        order.status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _compactInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: SearchUiColors.primary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            color: SearchUiColors.softText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SearchUiColors.primary,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
