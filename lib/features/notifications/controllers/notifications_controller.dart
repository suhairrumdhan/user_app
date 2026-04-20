import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/main_navigation_controller.dart';
import '../../previous_medications/views/add_previous_medication_from_notification_sheet.dart';
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
    if (_shouldOpenPreviousMedicationSheet(notification)) {
      _openPreviousMedicationSheet(notification, context);
      return;
    }

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

    switch (notification.type) {
      case AppNotificationType.orderUpdate:
        _navController.goOrders(orderId: notification.orderId);
        break;

      case AppNotificationType.pharmacyMessage:
        _navController.goChats();
        break;

      case AppNotificationType.medicineReminder:
      case AppNotificationType.appointmentReminder:
        _navController.goNotifications();
        break;

      case AppNotificationType.adminMessage:
      case AppNotificationType.promotion:
      case AppNotificationType.system:
        _navController.goNotifications();
        break;
    }
  }

  bool _shouldOpenPreviousMedicationSheet(AppNotificationModel notification) {
    if (notification.type != AppNotificationType.orderUpdate) {
      return false;
    }

    if (!_hasMinimumPreviousMedicationContext(notification)) {
      return false;
    }

    final status = _normalizeStatus(notification.extraData['status']);
    final statusLabel = _normalizeStatus(notification.extraData['statusLabel']);
    final canAddFlag =
        notification.extraData['canAddToMedicationHistory'] == true;

    final delivered = status == 'delivered' ||
        status == 'completed_delivery' ||
        statusLabel == 'تم الاستلام' ||
        statusLabel == 'تم التسليم' ||
        statusLabel == 'delivered';

    return delivered || canAddFlag;
  }

  bool _hasMinimumPreviousMedicationContext(AppNotificationModel notification) {
    final hasOrderId = (notification.orderId ?? '').trim().isNotEmpty;
    final hasBeneficiaryId =
        (notification.beneficiaryId ?? '').trim().isNotEmpty;
    final medicines = notification.extraData['deliveredMedicines'];

    final hasMedicines = medicines is List && medicines.isNotEmpty;

    return hasOrderId && hasBeneficiaryId && hasMedicines;
  }

  String _normalizeStatus(dynamic value) {
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  void _openPreviousMedicationSheet(
      AppNotificationModel notification,
      BuildContext context,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPreviousMedicationFromNotificationSheet(
        notification: notification,
      ),
    );
  }
}