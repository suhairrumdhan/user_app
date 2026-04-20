import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../app/controllers/main_navigation_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';
import '../widgets/order_card.dart';
import 'order_details_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final UserController _userController = Get.find<UserController>();
  final MainNavigationController _navController =
  Get.find<MainNavigationController>();

  @override
  Widget build(BuildContext context) {
    final currentUser = _userController.user.value;

    return Scaffold(
      backgroundColor: SearchUiColors.primary,
      body: currentUser == null
          ? const _OrdersShell(
        child: _OrdersMessageState(
          icon: Iconsax.user_octagon,
          title: 'يجب تسجيل الدخول أولاً',
          subtitle: 'سجلي الدخول لعرض طلباتك ومتابعة حالتها.',
        ),
      )
          : _OrdersShell(
        child: StreamBuilder<List<OrderModel>>(
          stream: OrderService.instance.getUserOrdersStream(currentUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: SearchUiColors.primary,
                ),
              );
            }

            if (snapshot.hasError) {
              return const _OrdersMessageState(
                icon: Iconsax.warning_2,
                title: 'حدث خطأ',
                subtitle: 'تعذر تحميل الطلبات حالياً.',
              );
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return const _OrdersMessageState(
                icon: Iconsax.box,
                title: 'لا توجد طلبات بعد',
                subtitle: 'عند إرسال أول طلب سيظهر هنا لتتمكني من متابعته.',
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: _OrdersSummaryCard(
                    totalOrders: orders.length,
                    pendingCount: orders
                        .where((o) =>
                    o.status == OrderStatus.pending ||
                        o.status == OrderStatus.reviewing ||
                        o.status == OrderStatus.confirmed ||
                        o.status == OrderStatus.partiallyConfirmed ||
                        o.status == OrderStatus.ready)
                        .length,
                    completedCount: orders
                        .where((o) => o.status == OrderStatus.completed)
                        .length,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];

                      return OrderCard(
                        order: order,
                        onTap: () {
                          Get.to(() => OrderDetailsPage(order: order));
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrdersShell extends StatelessWidget {
  final Widget child;

  const _OrdersShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Iconsax.shopping_cart4,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلباتي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'تابع جميع طلباتك وحالتها بسهولة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: SearchUiColors.light,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(34),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _OrdersSummaryCard extends StatelessWidget {
  final int totalOrders;
  final int pendingCount;
  final int completedCount;

  const _OrdersSummaryCard({
    required this.totalOrders,
    required this.pendingCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SearchUiColors.primary.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              title: 'إجمالي الطلبات',
              value: '$totalOrders',
              icon: Iconsax.box,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryItem(
              title: 'قيد المتابعة',
              value: '$pendingCount',
              icon: Iconsax.timer_1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryItem(
              title: 'مكتملة',
              value: '$completedCount',
              icon: Iconsax.tick_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OrdersMessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: SearchUiColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: SearchUiColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}