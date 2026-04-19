import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../search/views/search_ui_colors.dart';
import '../controllers/notifications_controller.dart';
import '../models/app_notification_model.dart';
import '../widgets/notification_card.dart';
import '../widgets/notifications_empty_state.dart';
import '../widgets/notifications_header.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationsController controller =
    Get.put(NotificationsController(), permanent: true);

    return Scaffold(
      backgroundColor: SearchUiColors.primary,
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: controller.notificationsStream,
        builder: (context, snapshot) {
          final allNotifications = snapshot.data ?? [];
          final unreadCount = controller.countUnread(allNotifications);

          return Column(
            children: [
              Obx(
                    () => NotificationsHeader(
                  totalCount: allNotifications.length,
                  unreadCount: unreadCount,
                  isProcessing: controller.isProcessing.value,
                  onMarkAllAsRead: unreadCount == 0
                      ? null
                      : () => controller.markAllAsRead(),
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
                  child: _buildBody(
                    context: context,
                    controller: controller,
                    snapshot: snapshot,
                    allNotifications: allNotifications,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required NotificationsController controller,
    required AsyncSnapshot<List<AppNotificationModel>> snapshot,
    required List<AppNotificationModel> allNotifications,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        allNotifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: SearchUiColors.primary,
        ),
      );
    }

    if (snapshot.hasError) {
      return const NotificationsEmptyState(
        title: 'حدث خطأ',
        subtitle: 'تعذر تحميل الإشعارات حالياً. حاول مرة أخرى لاحقاً.',
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        const SizedBox(height: 14),
        Expanded(
          child: allNotifications.isEmpty  // تغيير: استخدام allNotifications بدلاً من filteredNotifications
              ? const NotificationsEmptyState(  // تغيير: إزالة Obx(() =>)
            title: 'لا توجد إشعارات',
            subtitle: 'عند وصول أي تحديثات أو تنبيهات مهمة ستظهر هنا مباشرة.',
          )
              : RefreshIndicator(
            color: SearchUiColors.primary,
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 500),
              );
              // يمكن إضافة منطق التحديث هنا إذا لزم الأمر
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: allNotifications.length,  // تغيير: استخدام allNotifications
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = allNotifications[index];  // تغيير: استخدام allNotifications

                return NotificationCard(
                  notification: notification,
                  onTap: () => controller.handleNotificationTap(
                    notification,
                    context,
                  ),
                  onDelete: () => controller.deleteNotification(
                    notification.id,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

  }
}