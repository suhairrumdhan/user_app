import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/controllers/main_navigation_controller.dart';

import '../models/app_notification_model.dart';
import '../models/notification_type.dart';
import '../services/notifications_service.dart';

enum NotificationsFilter {
  all,
  orders,
  pharmacy,
  admin,
  reminders,
  promotions,
  system,
  unread,
}

class NotificationsController extends GetxController {
  final NotificationsService _service;
  MainNavigationController get _navController =>
      Get.find<MainNavigationController>();

  NotificationsController({NotificationsService? service})
      : _service = service ?? NotificationsService();



  final RxBool isProcessing = false.obs;

  Stream<List<AppNotificationModel>> get notificationsStream =>
      _service.getNotificationsStream();

  Stream<int> get unreadCountStream => _service.getUnreadCountStream();




  int countUnread(List<AppNotificationModel> notifications) {
    return notifications.where((n) => !n.isRead).length;
  }

  int countByFilter(
      List<AppNotificationModel> notifications,
      NotificationsFilter filter,
      ) {
    switch (filter) {
      case NotificationsFilter.all:
        return notifications.length;

      case NotificationsFilter.orders:
        return notifications
            .where((n) => n.type == AppNotificationType.orderUpdate)
            .length;

      case NotificationsFilter.pharmacy:
        return notifications
            .where((n) => n.type == AppNotificationType.pharmacyMessage)
            .length;

      case NotificationsFilter.admin:
        return notifications
            .where((n) => n.type == AppNotificationType.adminMessage)
            .length;

      case NotificationsFilter.reminders:
        return notifications.where((n) {
          return n.type == AppNotificationType.medicineReminder ||
              n.type == AppNotificationType.appointmentReminder;
        }).length;

      case NotificationsFilter.promotions:
        return notifications
            .where((n) => n.type == AppNotificationType.promotion)
            .length;

      case NotificationsFilter.system:
        return notifications
            .where((n) => n.type == AppNotificationType.system)
            .length;

      case NotificationsFilter.unread:
        return notifications.where((n) => !n.isRead).length;
    }
  }

  String getFilterLabel(NotificationsFilter filter) {
    switch (filter) {
      case NotificationsFilter.all:
        return 'الكل';
      case NotificationsFilter.orders:
        return 'الطلبات';
      case NotificationsFilter.pharmacy:
        return 'الصيدلية';
      case NotificationsFilter.admin:
        return 'الإدارة';
      case NotificationsFilter.reminders:
        return 'التذكيرات';
      case NotificationsFilter.promotions:
        return 'العروض';
      case NotificationsFilter.system:
        return 'النظام';
      case NotificationsFilter.unread:
        return 'غير مقروء';
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث حالة الإشعار',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> markAllAsRead() async {
    if (isProcessing.value) return;

    try {
      isProcessing.value = true;
      await _service.markAllAsRead();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر تعيين جميع الإشعارات كمقروءة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _service.deleteNotification(notificationId);
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر حذف الإشعار',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> handleNotificationTap(
      AppNotificationModel notification,
      BuildContext context,
      ) async {
    if (!notification.isRead) {
      await markAsRead(notification.id);
    }

    await navigateFromNotification(notification, context);
  }
  Future<void> navigateFromNotification(
      AppNotificationModel notification,
      BuildContext context,
      ) async {
    // 🔹 1. لو عنده route جاهز (مستقبلاً)
    if (notification.actionRoute != null &&
        notification.actionRoute!.trim().isNotEmpty) {
      try {
        Get.toNamed(
          notification.actionRoute!,
          arguments: notification.actionId,
        );
        return;
      } catch (_) {
        // fallback
      }
    }

    // 🔹 2. fallback على Navigator (الحالي)
    switch (notification.type) {
      case AppNotificationType.orderUpdate:
        _navController.goOrders();
        break;

      case AppNotificationType.pharmacyMessage:
        _navController.goChats();
        break;

      case AppNotificationType.medicineReminder:
      case AppNotificationType.appointmentReminder:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Placeholder(),
          ),
        );
        break;

      case AppNotificationType.adminMessage:
      case AppNotificationType.promotion:
      case AppNotificationType.system:
        _navController.goNotifications();
        break;
    }
  }
}