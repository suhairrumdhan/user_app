import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFA726); // برتقالي هادي

      case OrderStatus.reviewing:
        return const Color(0xFF42A5F5); // أزرق فاتح

      case OrderStatus.confirmed:
        return const Color(0xFF66BB6A); // أخضر جميل

      case OrderStatus.partiallyConfirmed:
        return const Color(0xFFFF7043); // برتقالي غامق

      case OrderStatus.rejected:
        return const Color(0xFFE53935); // أحمر قوي

      case OrderStatus.ready:
        return const Color(0xFF26A69A); // تيل (جميل مع الأزرق)

      case OrderStatus.completed:
        return const Color(0xFF43A047); // أخضر غامق

      case OrderStatus.cancelled:
        return const Color(0xFFD32F2F); // 🔥 أحمر واضح (المهم)
    }
  }
  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: SearchUiColors.primary.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _iconBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: _titleSection(),
                ),
                _statusBadge(statusColor),
              ],
            ),
            const SizedBox(height: 14),

            /// معلومات سريعة
            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Iconsax.document_text,
                    label: 'نوع الطلب',
                    value: order.requestSourceLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfo(
                    icon: Iconsax.box,
                    label: 'عدد الأدوية',
                    value: '${order.totalItemsCount}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Iconsax.money_4,
                    label: 'السعر',
                    value: order.estimatedTotalPrice != null
                        ? '${order.estimatedTotalPrice!.toStringAsFixed(2)} د.ل'
                        : 'غير محدد',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfo(
                    icon: Iconsax.calendar_1,
                    label: 'التاريخ',
                    value: _formatDate(order.createdAt),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// Tags
            Row(
              children: [
                if (order.containsInsurance) _tag('تأمين'),
                const Spacer(),
                const Icon(
                  Iconsax.arrow_left_2,
                  size: 18,
                  color: SearchUiColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            SearchUiColors.primary,
            SearchUiColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Iconsax.hospital,
        color: Colors.white,
        size: 22,
      ),
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
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: SearchUiColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'لـ ${order.beneficiary.name}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        order.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _miniInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SearchUiColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: SearchUiColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SearchUiColors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}