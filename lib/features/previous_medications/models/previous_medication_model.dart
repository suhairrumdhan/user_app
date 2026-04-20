import 'package:cloud_firestore/cloud_firestore.dart';

class PreviousMedicationModel {
  final String id;
  final String userId;

  // ========= Owner / Beneficiary =========
  final String ownerBeneficiaryId;
  final String ownerName;
  final String ownerType; // self | family
  final String ownerRelation; // self | son | daughter | mother ...

  // ========= Medication Details =========
  final String medicineName;
  final String? dosage;
  final String? route;
  final String? notes;

  // ========= Source / Context =========
  final String? pharmacyId;
  final String? pharmacyName;
  final String? orderId;
  final String? addedFromNotificationId;

  // ========= Medication Timeline =========
  final DateTime takenAt;
  final DateTime? treatmentStartDate;
  final DateTime? treatmentEndDate;

  // ========= Pharmacist Visibility =========
  final DateTime? showToPharmacistFrom;
  final DateTime? showToPharmacistUntil;
  final bool isVisibleToPharmacist;

  // ========= Reminder Link =========
  final String reminderStatus; // none | linked | completed
  final int? linkedReminderLocalId;

  // ========= General Status =========
  final String status; // active | completed | archived

  final DateTime createdAt;
  final DateTime? updatedAt;

  const PreviousMedicationModel({
    required this.id,
    required this.userId,
    required this.ownerBeneficiaryId,
    required this.ownerName,
    required this.ownerType,
    required this.ownerRelation,
    required this.medicineName,
    this.dosage,
    this.route,
    this.notes,
    this.pharmacyId,
    this.pharmacyName,
    this.orderId,
    this.addedFromNotificationId,
    required this.takenAt,
    this.treatmentStartDate,
    this.treatmentEndDate,
    this.showToPharmacistFrom,
    this.showToPharmacistUntil,
    this.isVisibleToPharmacist = true,
    this.reminderStatus = PreviousMedicationReminderStatus.none,
    this.linkedReminderLocalId,
    this.status = PreviousMedicationStatus.active,
    required this.createdAt,
    this.updatedAt,
  });

  // ========= Computed =========

  bool get hasDosage => dosage != null && dosage!.trim().isNotEmpty;
  bool get hasRoute => route != null && route!.trim().isNotEmpty;
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;
  bool get hasPharmacyName =>
      pharmacyName != null && pharmacyName!.trim().isNotEmpty;
  bool get hasOrderId => orderId != null && orderId!.trim().isNotEmpty;
  bool get hasLinkedReminder => linkedReminderLocalId != null;

  bool get isActive => status == PreviousMedicationStatus.active;
  bool get isCompleted => status == PreviousMedicationStatus.completed;
  bool get isArchived => status == PreviousMedicationStatus.archived;

  bool get isReminderLinked =>
      reminderStatus == PreviousMedicationReminderStatus.linked;

  bool get isTreatmentEnded {
    final end = treatmentEndDate;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  bool get isCurrentlyVisibleToPharmacist {
    if (!isVisibleToPharmacist) return false;

    final now = DateTime.now();

    if (showToPharmacistFrom != null && now.isBefore(showToPharmacistFrom!)) {
      return false;
    }

    if (showToPharmacistUntil != null && now.isAfter(showToPharmacistUntil!)) {
      return false;
    }

    return true;
  }

  String get ownerDisplayLabel {
    if (ownerRelation.trim().isNotEmpty) return ownerRelation;
    return ownerType == 'self' ? 'أنا' : 'فرد عائلة';
  }

  String get pharmacistVisibilityLabel {
    if (!isVisibleToPharmacist) return 'مخفي عن الصيدلي';
    if (isCurrentlyVisibleToPharmacist) return 'ظاهر للصيدلي';
    return 'انتهت مدة الظهور';
  }

  String get statusLabel {
    switch (status) {
      case PreviousMedicationStatus.active:
        return 'نشط';
      case PreviousMedicationStatus.completed:
        return 'مكتمل';
      case PreviousMedicationStatus.archived:
        return 'مؤرشف';
      default:
        return 'غير معروف';
    }
  }

  String get reminderStatusLabel {
    switch (reminderStatus) {
      case PreviousMedicationReminderStatus.none:
        return 'بدون تذكير';
      case PreviousMedicationReminderStatus.linked:
        return 'مرتبط بتذكير';
      case PreviousMedicationReminderStatus.completed:
        return 'تم التذكير';
      default:
        return 'غير معروف';
    }
  }

  // ========= Serialization =========

  factory PreviousMedicationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    return PreviousMedicationModel(
      id: doc.id,
      userId: _readString(data['userId']),
      ownerBeneficiaryId: _readString(data['ownerBeneficiaryId']),
      ownerName: _readString(data['ownerName']),
      ownerType: _readString(data['ownerType']),
      ownerRelation: _readString(data['ownerRelation']),
      medicineName: _readString(data['medicineName']),
      dosage: _readNullableString(data['dosage']),
      route: _readNullableString(data['route']),
      notes: _readNullableString(data['notes']),
      pharmacyId: _readNullableString(data['pharmacyId']),
      pharmacyName: _readNullableString(data['pharmacyName']),
      orderId: _readNullableString(data['orderId']),
      addedFromNotificationId:
      _readNullableString(data['addedFromNotificationId']),
      takenAt: _readDateTime(data['takenAt']) ?? DateTime.now(),
      treatmentStartDate: _readDateTime(data['treatmentStartDate']),
      treatmentEndDate: _readDateTime(data['treatmentEndDate']),
      showToPharmacistFrom: _readDateTime(data['showToPharmacistFrom']),
      showToPharmacistUntil: _readDateTime(data['showToPharmacistUntil']),
      isVisibleToPharmacist: _readBool(
        data['isVisibleToPharmacist'],
        fallback: true,
      ),
      reminderStatus: _readString(
        data['reminderStatus'],
        fallback: PreviousMedicationReminderStatus.none,
      ),
      linkedReminderLocalId: _readNullableInt(data['linkedReminderLocalId']),
      status: _readString(
        data['status'],
        fallback: PreviousMedicationStatus.active,
      ),
      createdAt: _readDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({
    bool includeServerTimestamp = true,
  }) {
    return {
      'userId': userId,
      'ownerBeneficiaryId': ownerBeneficiaryId,
      'ownerName': ownerName,
      'ownerType': ownerType,
      'ownerRelation': ownerRelation,
      'medicineName': medicineName,
      'dosage': dosage,
      'route': route,
      'notes': notes,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'orderId': orderId,
      'addedFromNotificationId': addedFromNotificationId,
      'takenAt': Timestamp.fromDate(takenAt),
      'treatmentStartDate': treatmentStartDate != null
          ? Timestamp.fromDate(treatmentStartDate!)
          : null,
      'treatmentEndDate': treatmentEndDate != null
          ? Timestamp.fromDate(treatmentEndDate!)
          : null,
      'showToPharmacistFrom': showToPharmacistFrom != null
          ? Timestamp.fromDate(showToPharmacistFrom!)
          : null,
      'showToPharmacistUntil': showToPharmacistUntil != null
          ? Timestamp.fromDate(showToPharmacistUntil!)
          : null,
      'isVisibleToPharmacist': isVisibleToPharmacist,
      'reminderStatus': reminderStatus,
      'linkedReminderLocalId': linkedReminderLocalId,
      'status': status,
      'createdAt': includeServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // ========= Copy =========

  PreviousMedicationModel copyWith({
    String? id,
    String? userId,
    String? ownerBeneficiaryId,
    String? ownerName,
    String? ownerType,
    String? ownerRelation,
    String? medicineName,
    String? dosage,
    bool clearDosage = false,
    String? route,
    bool clearRoute = false,
    String? notes,
    bool clearNotes = false,
    String? pharmacyId,
    bool clearPharmacyId = false,
    String? pharmacyName,
    bool clearPharmacyName = false,
    String? orderId,
    bool clearOrderId = false,
    String? addedFromNotificationId,
    bool clearAddedFromNotificationId = false,
    DateTime? takenAt,
    DateTime? treatmentStartDate,
    bool clearTreatmentStartDate = false,
    DateTime? treatmentEndDate,
    bool clearTreatmentEndDate = false,
    DateTime? showToPharmacistFrom,
    bool clearShowToPharmacistFrom = false,
    DateTime? showToPharmacistUntil,
    bool clearShowToPharmacistUntil = false,
    bool? isVisibleToPharmacist,
    String? reminderStatus,
    int? linkedReminderLocalId,
    bool clearLinkedReminderLocalId = false,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool touchUpdatedAt = false,
    bool clearUpdatedAt = false,
  }) {
    return PreviousMedicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ownerBeneficiaryId: ownerBeneficiaryId ?? this.ownerBeneficiaryId,
      ownerName: ownerName ?? this.ownerName,
      ownerType: ownerType ?? this.ownerType,
      ownerRelation: ownerRelation ?? this.ownerRelation,
      medicineName: medicineName ?? this.medicineName,
      dosage: clearDosage ? null : (dosage ?? this.dosage),
      route: clearRoute ? null : (route ?? this.route),
      notes: clearNotes ? null : (notes ?? this.notes),
      pharmacyId: clearPharmacyId ? null : (pharmacyId ?? this.pharmacyId),
      pharmacyName:
      clearPharmacyName ? null : (pharmacyName ?? this.pharmacyName),
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
      addedFromNotificationId: clearAddedFromNotificationId
          ? null
          : (addedFromNotificationId ?? this.addedFromNotificationId),
      takenAt: takenAt ?? this.takenAt,
      treatmentStartDate: clearTreatmentStartDate
          ? null
          : (treatmentStartDate ?? this.treatmentStartDate),
      treatmentEndDate: clearTreatmentEndDate
          ? null
          : (treatmentEndDate ?? this.treatmentEndDate),
      showToPharmacistFrom: clearShowToPharmacistFrom
          ? null
          : (showToPharmacistFrom ?? this.showToPharmacistFrom),
      showToPharmacistUntil: clearShowToPharmacistUntil
          ? null
          : (showToPharmacistUntil ?? this.showToPharmacistUntil),
      isVisibleToPharmacist:
      isVisibleToPharmacist ?? this.isVisibleToPharmacist,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      linkedReminderLocalId: clearLinkedReminderLocalId
          ? null
          : (linkedReminderLocalId ?? this.linkedReminderLocalId),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt
          ? null
          : (touchUpdatedAt ? DateTime.now() : (updatedAt ?? this.updatedAt)),
    );
  }

  // ========= Helpers =========

  static String buildDocId({
    required String orderId,
    required String ownerBeneficiaryId,
    required String medicineName,
  }) {
    final normalizedMedicine = medicineName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_');
    return '${orderId}_${ownerBeneficiaryId}_$normalizedMedicine';
  }

  static String _readString(
      dynamic value, {
        String fallback = '',
      }) {
    if (value is String) return value.trim();
    if (value == null) return fallback;
    return value.toString().trim();
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static bool _readBool(
      dynamic value, {
        bool fallback = false,
      }) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
      if (normalized == '1') return true;
      if (normalized == '0') return false;
    }
    return fallback;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class PreviousMedicationStatus {
  static const String active = 'active';
  static const String completed = 'completed';
  static const String archived = 'archived';

  static const List<String> values = [
    active,
    completed,
    archived,
  ];
}

class PreviousMedicationReminderStatus {
  static const String none = 'none';
  static const String linked = 'linked';
  static const String completed = 'completed';

  static const List<String> values = [
    none,
    linked,
    completed,
  ];
}