enum AppNotificationType {
  orderUpdate,
  pharmacyMessage,
  adminMessage,
  promotion,
  medicineReminder,
  appointmentReminder,
  system,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

enum NotificationReferenceType {
  order,
  chat,
  prescription,
  medicineReminder,
  appointment,
  system,
  none,
}

extension AppNotificationTypeX on AppNotificationType {
  String get value {
    switch (this) {
      case AppNotificationType.orderUpdate:
        return 'orderUpdate';
      case AppNotificationType.pharmacyMessage:
        return 'pharmacyMessage';
      case AppNotificationType.adminMessage:
        return 'adminMessage';
      case AppNotificationType.promotion:
        return 'promotion';
      case AppNotificationType.medicineReminder:
        return 'medicineReminder';
      case AppNotificationType.appointmentReminder:
        return 'appointmentReminder';
      case AppNotificationType.system:
        return 'system';
    }
  }

  String get arabicLabel {
    switch (this) {
      case AppNotificationType.orderUpdate:
        return 'الطلبات';
      case AppNotificationType.pharmacyMessage:
        return 'الصيدلية';
      case AppNotificationType.adminMessage:
        return 'الإدارة';
      case AppNotificationType.promotion:
        return 'العروض';
      case AppNotificationType.medicineReminder:
        return 'تنبيه دواء';
      case AppNotificationType.appointmentReminder:
        return 'موعد';
      case AppNotificationType.system:
        return 'النظام';
    }
  }

  static AppNotificationType fromString(dynamic value) {
    switch (value) {
      case 'orderUpdate':
        return AppNotificationType.orderUpdate;
      case 'pharmacyMessage':
        return AppNotificationType.pharmacyMessage;
      case 'adminMessage':
        return AppNotificationType.adminMessage;
      case 'promotion':
        return AppNotificationType.promotion;
      case 'medicineReminder':
        return AppNotificationType.medicineReminder;
      case 'appointmentReminder':
        return AppNotificationType.appointmentReminder;
      case 'system':
      default:
        return AppNotificationType.system;
    }
  }
}

extension NotificationPriorityX on NotificationPriority {
  String get value {
    switch (this) {
      case NotificationPriority.low:
        return 'low';
      case NotificationPriority.normal:
        return 'normal';
      case NotificationPriority.high:
        return 'high';
      case NotificationPriority.urgent:
        return 'urgent';
    }
  }

  String get arabicLabel {
    switch (this) {
      case NotificationPriority.low:
        return 'منخفضة';
      case NotificationPriority.normal:
        return 'عادية';
      case NotificationPriority.high:
        return 'مرتفعة';
      case NotificationPriority.urgent:
        return 'عاجلة';
    }
  }

  static NotificationPriority fromString(dynamic value) {
    switch (value) {
      case 'low':
        return NotificationPriority.low;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
        return NotificationPriority.urgent;
      case 'normal':
      default:
        return NotificationPriority.normal;
    }
  }
}

extension NotificationReferenceTypeX on NotificationReferenceType {
  String get value {
    switch (this) {
      case NotificationReferenceType.order:
        return 'order';
      case NotificationReferenceType.chat:
        return 'chat';
      case NotificationReferenceType.prescription:
        return 'prescription';
      case NotificationReferenceType.medicineReminder:
        return 'medicineReminder';
      case NotificationReferenceType.appointment:
        return 'appointment';
      case NotificationReferenceType.system:
        return 'system';
      case NotificationReferenceType.none:
        return 'none';
    }
  }

  static NotificationReferenceType fromString(dynamic value) {
    switch (value) {
      case 'order':
        return NotificationReferenceType.order;
      case 'chat':
        return NotificationReferenceType.chat;
      case 'prescription':
        return NotificationReferenceType.prescription;
      case 'medicineReminder':
        return NotificationReferenceType.medicineReminder;
      case 'appointment':
        return NotificationReferenceType.appointment;
      case 'system':
        return NotificationReferenceType.system;
      case 'none':
      default:
        return NotificationReferenceType.none;
    }
  }
}