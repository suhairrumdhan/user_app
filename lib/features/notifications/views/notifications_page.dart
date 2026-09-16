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
    final NotificationsController controller = Get.put(
      NotificationsController(),
      permanent: true,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
                        : () => controller.markAllAsRead(context: context),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: SearchUiColors.light,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
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
        child: CircularProgressIndicator(color: SearchUiColors.primary),
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
        const SizedBox(height: 9),
        Expanded(
          child: allNotifications.isEmpty
              ? const NotificationsEmptyState(
                  title: 'لا توجد إشعارات',
                  subtitle: 'ستظهر التنبيهات الجديدة هنا.',
                )
              : RefreshIndicator(
                  color: SearchUiColors.primary,
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
                    itemCount: allNotifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final notification = allNotifications[index];

                      return NotificationCard(
                        notification: notification,
                        onTap: () => controller.handleNotificationTap(
                          notification,
                          context,
                        ),
                        onDelete: () => controller.deleteNotification(
                          notification.id,
                          context: context,
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
