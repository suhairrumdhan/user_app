import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_type.dart';

class AppNotificationModel {
  final String id;
  final String userId;

  final String title;
  final String message;

  final AppNotificationType type;
  final NotificationPriority priority;
  final NotificationReferenceType referenceType;

  final bool isRead;
  final bool isDeleted;
  final bool isActionable;

  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;

  final String? referenceId;
  final String? actionRoute;
  final String? actionId;

  final String? imageUrl;
  final String? iconName;

  final String? pharmacyId;
  final String? pharmacyName;

  final String? orderId;
  final String? chatId;
  final String? prescriptionId;

  final String? beneficiaryId;
  final String? beneficiaryName;
  final String? beneficiaryType;

  final Map<String, dynamic> extraData;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.referenceType = NotificationReferenceType.none,
    this.isRead = false,
    this.isDeleted = false,
    this.isActionable = true,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
    this.referenceId,
    this.actionRoute,
    this.actionId,
    this.imageUrl,
    this.iconName,
    this.pharmacyId,
    this.pharmacyName,
    this.orderId,
    this.chatId,
    this.prescriptionId,
    this.beneficiaryId,
    this.beneficiaryName,
    this.beneficiaryType,
    this.extraData = const {},
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
  bool get hasActionRoute => actionRoute != null && actionRoute!.trim().isNotEmpty;
  bool get hasReference => referenceId != null && referenceId!.trim().isNotEmpty;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isOrderNotification => type == AppNotificationType.orderUpdate;
  bool get isReminderNotification =>
      type == AppNotificationType.medicineReminder ||
          type == AppNotificationType.appointmentReminder;

  String get typeLabel => type.arabicLabel;
  String get priorityLabel => priority.arabicLabel;

  factory AppNotificationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    return AppNotificationModel(
      id: doc.id,
      userId: _readString(data['userId']),
      title: _readString(data['title']),
      message: _readString(data['message']),
      type: AppNotificationTypeX.fromString(data['type']),
      priority: NotificationPriorityX.fromString(data['priority']),
      referenceType:
      NotificationReferenceTypeX.fromString(data['referenceType']),
      isRead: _readBool(data['isRead']),
      isDeleted: _readBool(data['isDeleted']),
      isActionable: data['isActionable'] is bool ? data['isActionable'] as bool : true,
      createdAt: _readDateTime(data['createdAt']) ?? DateTime.now(),
      readAt: _readDateTime(data['readAt']),
      expiresAt: _readDateTime(data['expiresAt']),
      referenceId: _readNullableString(data['referenceId']),
      actionRoute: _readNullableString(data['actionRoute']),
      actionId: _readNullableString(data['actionId']),
      imageUrl: _readNullableString(data['imageUrl']),
      iconName: _readNullableString(data['iconName']),
      pharmacyId: _readNullableString(data['pharmacyId']),
      pharmacyName: _readNullableString(data['pharmacyName']),
      orderId: _readNullableString(data['orderId']),
      chatId: _readNullableString(data['chatId']),
      prescriptionId: _readNullableString(data['prescriptionId']),
      beneficiaryId: _readNullableString(data['beneficiaryId']),
      beneficiaryName: _readNullableString(data['beneficiaryName']),
      beneficiaryType: _readNullableString(data['beneficiaryType']),
      extraData: _readMap(data['extraData']),
    );
  }

  Map<String, dynamic> toMap({bool includeServerTimestamp = true}) {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.value,
      'priority': priority.value,
      'referenceType': referenceType.value,
      'isRead': isRead,
      'isDeleted': isDeleted,
      'isActionable': isActionable,
      'createdAt': includeServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'referenceId': referenceId,
      'actionRoute': actionRoute,
      'actionId': actionId,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'orderId': orderId,
      'chatId': chatId,
      'prescriptionId': prescriptionId,
      'beneficiaryId': beneficiaryId,
      'beneficiaryName': beneficiaryName,
      'beneficiaryType': beneficiaryType,
      'extraData': extraData,
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    AppNotificationType? type,
    NotificationPriority? priority,
    NotificationReferenceType? referenceType,
    bool? isRead,
    bool? isDeleted,
    bool? isActionable,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? referenceId,
    bool clearReferenceId = false,
    String? actionRoute,
    bool clearActionRoute = false,
    String? actionId,
    bool clearActionId = false,
    String? imageUrl,
    bool clearImageUrl = false,
    String? iconName,
    bool clearIconName = false,
    String? pharmacyId,
    bool clearPharmacyId = false,
    String? pharmacyName,
    bool clearPharmacyName = false,
    String? orderId,
    bool clearOrderId = false,
    String? chatId,
    bool clearChatId = false,
    String? prescriptionId,
    bool clearPrescriptionId = false,
    String? beneficiaryId,
    bool clearBeneficiaryId = false,
    String? beneficiaryName,
    bool clearBeneficiaryName = false,
    String? beneficiaryType,
    bool clearBeneficiaryType = false,
    Map<String, dynamic>? extraData,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      referenceType: referenceType ?? this.referenceType,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      isActionable: isActionable ?? this.isActionable,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      referenceId: clearReferenceId ? null : (referenceId ?? this.referenceId),
      actionRoute: clearActionRoute ? null : (actionRoute ?? this.actionRoute),
      actionId: clearActionId ? null : (actionId ?? this.actionId),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      iconName: clearIconName ? null : (iconName ?? this.iconName),
      pharmacyId: clearPharmacyId ? null : (pharmacyId ?? this.pharmacyId),
      pharmacyName:
      clearPharmacyName ? null : (pharmacyName ?? this.pharmacyName),
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
      chatId: clearChatId ? null : (chatId ?? this.chatId),
      prescriptionId:
      clearPrescriptionId ? null : (prescriptionId ?? this.prescriptionId),
      beneficiaryId:
      clearBeneficiaryId ? null : (beneficiaryId ?? this.beneficiaryId),
      beneficiaryName: clearBeneficiaryName
          ? null
          : (beneficiaryName ?? this.beneficiaryName),
      beneficiaryType: clearBeneficiaryType
          ? null
          : (beneficiaryType ?? this.beneficiaryType),
      extraData: extraData ?? this.extraData,
    );
  }

  static AppNotificationModel createOrderUpdate({
    required String id,
    required String userId,
    required String title,
    required String message,
    required DateTime createdAt,
    required String orderId,
    String? pharmacyId,
    String? pharmacyName,
    String? beneficiaryId,
    String? beneficiaryName,
    String? beneficiaryType,
    NotificationPriority priority = NotificationPriority.high,
    String? actionRoute,
    String? actionId,
    Map<String, dynamic> extraData = const {},
  }) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: AppNotificationType.orderUpdate,
      priority: priority,
      referenceType: NotificationReferenceType.order,
      createdAt: createdAt,
      orderId: orderId,
      referenceId: orderId,
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      beneficiaryId: beneficiaryId,
      beneficiaryName: beneficiaryName,
      beneficiaryType: beneficiaryType,
      actionRoute: actionRoute,
      actionId: actionId ?? orderId,
      extraData: extraData,
    );
  }

  static AppNotificationModel createMedicineReminder({
    required String id,
    required String userId,
    required String title,
    required String message,
    required DateTime createdAt,
    String? beneficiaryId,
    String? beneficiaryName,
    String? beneficiaryType,
    String? referenceId,
    String? actionRoute,
    String? actionId,
    NotificationPriority priority = NotificationPriority.urgent,
    Map<String, dynamic> extraData = const {},
  }) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: AppNotificationType.medicineReminder,
      priority: priority,
      referenceType: NotificationReferenceType.medicineReminder,
      createdAt: createdAt,
      referenceId: referenceId,
      beneficiaryId: beneficiaryId,
      beneficiaryName: beneficiaryName,
      beneficiaryType: beneficiaryType,
      actionRoute: actionRoute,
      actionId: actionId,
      extraData: extraData,
    );
  }

  static AppNotificationModel createAppointmentReminder({
    required String id,
    required String userId,
    required String title,
    required String message,
    required DateTime createdAt,
    String? beneficiaryId,
    String? beneficiaryName,
    String? beneficiaryType,
    String? referenceId,
    String? actionRoute,
    String? actionId,
    NotificationPriority priority = NotificationPriority.high,
    Map<String, dynamic> extraData = const {},
  }) {
    return AppNotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: AppNotificationType.appointmentReminder,
      priority: priority,
      referenceType: NotificationReferenceType.appointment,
      createdAt: createdAt,
      referenceId: referenceId,
      beneficiaryId: beneficiaryId,
      beneficiaryName: beneficiaryName,
      beneficiaryType: beneficiaryType,
      actionRoute: actionRoute,
      actionId: actionId,
      extraData: extraData,
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1';
    }
    return false;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
            (key, val) => MapEntry(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }
}