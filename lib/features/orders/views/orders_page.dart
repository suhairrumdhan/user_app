import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

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
  List<OrderModel> _latestOrders = const [];

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _OrderSearchDelegate(orders: _latestOrders),
    );
  }

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
              onSearchTap: _openSearch,
              child: StreamBuilder<List<OrderModel>>(
                stream: OrderService.instance.getUserOrdersStream(
                  currentUser.id,
                ),
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
                  _latestOrders = orders;

                  if (orders.isEmpty) {
                    return const _OrdersMessageState(
                      icon: Iconsax.box,
                      title: 'لا توجد طلبات بعد',
                      subtitle:
                          'عند إرسال أول طلب سيظهر هنا لتتمكن من متابعته.',
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 5),
                        child: _OrdersSummaryCard(
                          totalOrders: orders.length,
                          pendingCount: orders
                              .where(
                                (o) =>
                                    o.status == OrderStatus.received ||
                                    o.status == OrderStatus.underReview ||
                                    o.status == OrderStatus.confirmedReserved ||
                                    o.status == OrderStatus.partialOfferPending ||
                                    o.status == OrderStatus.preparing ||
                                    o.status == OrderStatus.ready,
                              )
                              .length,
                          completedCount: orders
                              .where((o) => o.status == OrderStatus.completed)
                              .length,
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
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
  final VoidCallback? onSearchTap;

  const _OrdersShell({required this.child, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.box, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلباتي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSearchTap,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.22)),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.10),
                  ),
                  icon: const Icon(Iconsax.search_normal_1, size: 18),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
          const SizedBox(width: 5),
          Expanded(
            child: _summaryItem(
              title: 'قيد المتابعة',
              value: '$pendingCount',
              icon: Iconsax.timer_1,
            ),
          ),
          const SizedBox(width: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
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
                child: Icon(icon, color: SearchUiColors.primary, size: 34),
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

class _OrderSearchDelegate extends SearchDelegate<String> {
  final List<OrderModel> orders;

  _OrderSearchDelegate({required this.orders});

  @override
  String get searchFieldLabel => 'ابحث داخل الطلبات';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_ios_new_rounded),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final searchText = query.trim().toLowerCase();
    if (searchText.isEmpty) {
      return const Center(
        child: Text(
          'ابحث برقم الطلب أو الصيدلية أو المستفيد أو الدواء',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    final results = orders.where((order) {
      return order.id.toLowerCase().contains(searchText) ||
          (order.orderNumber?.toLowerCase().contains(searchText) ?? false) ||
          order.pharmacy.pharmacyName.toLowerCase().contains(searchText) ||
          order.beneficiary.name.toLowerCase().contains(searchText) ||
          order.statusLabel.toLowerCase().contains(searchText) ||
          order.medicines.any(
            (medicine) => medicine.displayName.toLowerCase().contains(searchText) ||
                medicine.requestedName.toLowerCase().contains(searchText),
          );
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = results[index];
        return OrderCard(
          order: order,
          onTap: () {
            close(context, '');
            Get.to(() => OrderDetailsPage(order: order));
          },
        );
      },
    );
  }
}
