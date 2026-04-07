import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';

class OrderDetailsPage extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SearchUiColors.primary,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'تفاصيل الطلب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// BODY
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: SearchUiColors.light,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    title: 'الصيدلية',
                    icon: Iconsax.hospital,
                    children: [
                      _row('الاسم', order.pharmacy.pharmacyName),
                      _row('العنوان', order.pharmacy.address ?? 'غير متوفر'),
                    ],
                  ),
                  _section(
                    title: 'المستفيد',
                    icon: Iconsax.profile_circle,
                    children: [
                      _row('الاسم', order.beneficiary.name),
                      _row('الصفة', order.beneficiary.relationLabel ?? ''),
                    ],
                  ),
                  _section(
                    title: 'الأدوية',
                    icon: Iconsax.box,
                    children: order.medicines
                        .map((e) => _row('دواء', e.requestedName))
                        .toList(),
                  ),
                  _section(
                    title: 'الحالة',
                    icon: Iconsax.timer_1,
                    children: [
                      _row('الحالة الحالية', order.statusLabel),
                      _row('نوع الطلب', order.requestSourceLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCancelButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: SearchUiColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SearchUiColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('تأكيد الإلغاء'),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الطلب؟',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _cancelOrder(context);
    }
  }
  Widget _buildCancelButton(BuildContext context) {
    final canCancel = order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled;

    if (!canCancel) return const SizedBox();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      child: ElevatedButton.icon(
        onPressed: () => _confirmCancel(context),
        icon: const Icon(Iconsax.close_circle),
        label: const Text('إلغاء الطلب'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
  Future<void> _cancelOrder(BuildContext context) async {
    try {
      await OrderService.instance.updateOrderStatus(
        orderId: order.id!,
        newStatus: OrderStatus.cancelled,
        changedById: order.user.userId,
        changedByType: 'user',
        note: 'تم إلغاء الطلب من قبل المستخدم',
      );

      if (!context.mounted) return;

      Navigator.pop(context); // يرجع لصفحة الطلبات

      Get.snackbar(
        'تم الإلغاء',
        'تم إلغاء الطلب بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إلغاء الطلب',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }
}