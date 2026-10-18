import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  received,
  underReview,
  partialOfferPending,
  confirmedReserved,
  preparing,
  ready,
  completed,
  cancelled,
  rejected,
  notCollected,
  unknown,
}

extension OrderStatusX on OrderStatus {
  bool canTransitionTo(OrderStatus next, {required String actorType}) {
    if (actorType == 'user') {
      if (this == OrderStatus.partialOfferPending &&
          next == OrderStatus.confirmedReserved) {
        return true;
      }
      if (this == OrderStatus.received && next == OrderStatus.underReview) {
        return true;
      }
      return next == OrderStatus.cancelled &&
          (this == OrderStatus.received ||
              this == OrderStatus.underReview ||
              this == OrderStatus.partialOfferPending ||
              this == OrderStatus.confirmedReserved);
    }

    if (actorType == 'system') {
      return this == OrderStatus.received && next == OrderStatus.underReview;
    }
    if (actorType != 'pharmacy') return false;

    switch (this) {
      case OrderStatus.received:
        return false;
      case OrderStatus.underReview:
        return next == OrderStatus.confirmedReserved ||
            next == OrderStatus.partialOfferPending ||
            next == OrderStatus.rejected;
      case OrderStatus.partialOfferPending:
        return next == OrderStatus.partialOfferPending;
      case OrderStatus.confirmedReserved:
        return next == OrderStatus.preparing ||
            next == OrderStatus.partialOfferPending;
      case OrderStatus.preparing:
        return next == OrderStatus.ready ||
            next == OrderStatus.cancelled ||
            next == OrderStatus.partialOfferPending;
      case OrderStatus.ready:
        return next == OrderStatus.completed ||
            next == OrderStatus.partialOfferPending ||
            next == OrderStatus.cancelled ||
            next == OrderStatus.notCollected;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
      case OrderStatus.notCollected:
      case OrderStatus.unknown:
        return false;
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.received:
        return 'received';
      case OrderStatus.underReview:
        return 'underReview';
      case OrderStatus.partialOfferPending:
        return 'partialOfferPending';
      case OrderStatus.confirmedReserved:
        return 'confirmedReserved';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.rejected:
        return 'rejected';
      case OrderStatus.notCollected:
        return 'notCollected';
      case OrderStatus.unknown:
        return 'unknown';
    }
  }

  static OrderStatus fromValue(String? value) {
    switch (value) {
      case 'underReview':
      case 'reviewing':
        return OrderStatus.underReview;
      case 'confirmedReserved':
      case 'confirmed':
      case 'accepted':
        return OrderStatus.confirmedReserved;
      case 'partialOfferPending':
      case 'partiallyConfirmed':
      case 'partially_confirmed':
        return OrderStatus.partialOfferPending;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
      case 'delivered':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'rejected':
        return OrderStatus.rejected;
      case 'notCollected':
        return OrderStatus.notCollected;
      case 'received':
      case 'pending':
        return OrderStatus.received;
      default:
        return OrderStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.received:
        return 'تم إرسال الطلب';
      case OrderStatus.underReview:
        return 'قيد المراجعة';
      case OrderStatus.partialOfferPending:
        return 'بانتظار ردك';
      case OrderStatus.confirmedReserved:
        return 'تم التأكيد والحجز';
      case OrderStatus.preparing:
        return 'قيد التجهيز';
      case OrderStatus.ready:
        return 'جاهز للاستلام';
      case OrderStatus.completed:
        return 'تم الاستلام';
      case OrderStatus.cancelled:
        return 'تم الإلغاء';
      case OrderStatus.rejected:
        return 'رفضته الصيدلية';
      case OrderStatus.notCollected:
        return 'لم يتم الاستلام';
      case OrderStatus.unknown:
        return 'حالة غير معروفة';
    }
  }
}

enum OrderRequestSource { manual, prescription }

extension OrderRequestSourceX on OrderRequestSource {
  String get value {
    switch (this) {
      case OrderRequestSource.manual:
        return 'manual';
      case OrderRequestSource.prescription:
        return 'prescription';
    }
  }

  static OrderRequestSource fromValue(String? value) {
    switch (value) {
      case 'prescription':
        return OrderRequestSource.prescription;
      case 'manual':
      default:
        return OrderRequestSource.manual;
    }
  }

  String get label {
    switch (this) {
      case OrderRequestSource.manual:
        return 'بحث يدوي';
      case OrderRequestSource.prescription:
        return 'وصفة طبية';
    }
  }
}

enum BeneficiaryType { self, family }

extension BeneficiaryTypeX on BeneficiaryType {
  String get value {
    switch (this) {
      case BeneficiaryType.self:
        return 'self';
      case BeneficiaryType.family:
        return 'family';
    }
  }

  static BeneficiaryType fromValue(String? value) {
    switch (value) {
      case 'family':
        return BeneficiaryType.family;
      case 'self':
      default:
        return BeneficiaryType.self;
    }
  }

  String get label {
    switch (this) {
      case BeneficiaryType.self:
        return 'أنا';
      case BeneficiaryType.family:
        return 'فرد من العائلة';
    }
  }
}

class OrderUserSnapshot {
  final String userId;
  final String name;
  final String? phone;
  final String? email;
  final String? profileImageUrl;

  const OrderUserSnapshot({
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.profileImageUrl,
  });

  factory OrderUserSnapshot.fromMap(Map<String, dynamic> map) {
    return OrderUserSnapshot(
      userId: (map['userId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      profileImageUrl: map['profileImageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }

  OrderUserSnapshot copyWith({
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? profileImageUrl,
  }) {
    return OrderUserSnapshot(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class OrderPharmacySnapshot {
  final String pharmacyId;
  final String pharmacyName;
  final String? phoneNumber;
  final String? imageUrl;
  final String? address;
  final bool isOnline;
  final bool is24Hours;
  final bool isOpenNow;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double? estimatedTotalPrice;
  final double? pharmacyScore;

  const OrderPharmacySnapshot({
    required this.pharmacyId,
    required this.pharmacyName,
    this.phoneNumber,
    this.imageUrl,
    this.address,
    this.isOnline = false,
    this.is24Hours = false,
    this.isOpenNow = false,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.estimatedTotalPrice,
    this.pharmacyScore,
  });

  factory OrderPharmacySnapshot.fromMap(Map<String, dynamic> map) {
    return OrderPharmacySnapshot(
      pharmacyId: (map['pharmacyId'] ?? '').toString(),
      pharmacyName: (map['pharmacyName'] ?? '').toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      address: map['address']?.toString(),
      isOnline: map['isOnline'] == true,
      is24Hours: map['is24Hours'] == true,
      isOpenNow: map['isOpenNow'] == true,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      distanceKm: _toDouble(map['distanceKm']),
      estimatedTotalPrice: _toDouble(map['estimatedTotalPrice']),
      pharmacyScore: _toDouble(map['pharmacyScore']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'phoneNumber': phoneNumber,
      'imageUrl': imageUrl,
      'address': address,
      'isOnline': isOnline,
      'is24Hours': is24Hours,
      'isOpenNow': isOpenNow,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
      'estimatedTotalPrice': estimatedTotalPrice,
      'pharmacyScore': pharmacyScore,
    };
  }

  OrderPharmacySnapshot copyWith({
    String? pharmacyId,
    String? pharmacyName,
    String? phoneNumber,
    String? imageUrl,
    String? address,
    bool? isOnline,
    bool? is24Hours,
    bool? isOpenNow,
    double? latitude,
    double? longitude,
    double? distanceKm,
    double? estimatedTotalPrice,
    double? pharmacyScore,
  }) {
    return OrderPharmacySnapshot(
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      address: address ?? this.address,
      isOnline: isOnline ?? this.isOnline,
      is24Hours: is24Hours ?? this.is24Hours,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedTotalPrice: estimatedTotalPrice ?? this.estimatedTotalPrice,
      pharmacyScore: pharmacyScore ?? this.pharmacyScore,
    );
  }
}

class OrderBeneficiarySnapshot {
  final String beneficiaryId;
  final String ownerUserId;
  final BeneficiaryType type;
  final String name;
  final String? relationLabel;
  final String? familyMemberId;
  final String? gender;
  final String? bloodType;
  final int? age;
  final DateTime? dateOfBirth;
  final List<String> allergies;
  final List<String> healthConditions;
  final List<String> currentMedications;
  final bool hasHealthData;

  const OrderBeneficiarySnapshot({
    required this.beneficiaryId,
    required this.ownerUserId,
    required this.type,
    required this.name,
    this.relationLabel,
    this.familyMemberId,
    this.gender,
    this.bloodType,
    this.age,
    this.dateOfBirth,
    this.allergies = const [],
    this.healthConditions = const [],
    this.currentMedications = const [],
    this.hasHealthData = false,
  });

  bool get isSelf => type == BeneficiaryType.self;
  bool get isFamily => type == BeneficiaryType.family;

  factory OrderBeneficiarySnapshot.fromMap(Map<String, dynamic> map) {
    return OrderBeneficiarySnapshot(
      beneficiaryId: (map['beneficiaryId'] ?? '').toString(),
      ownerUserId: (map['ownerUserId'] ?? '').toString(),
      type: BeneficiaryTypeX.fromValue(map['type']?.toString()),
      name: (map['name'] ?? '').toString(),
      relationLabel: map['relationLabel']?.toString(),
      familyMemberId: map['familyMemberId']?.toString(),
      gender: map['gender']?.toString(),
      bloodType: map['bloodType']?.toString(),
      age: map['age'] is int
          ? map['age'] as int
          : int.tryParse('${map['age']}'),
      dateOfBirth: _toDateTime(map['dateOfBirth']),
      allergies: _toStringList(map['allergies']),
      healthConditions: _toStringList(map['healthConditions']),
      currentMedications: _toStringList(map['currentMedications']),
      hasHealthData: map['hasHealthData'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'beneficiaryId': beneficiaryId,
      'ownerUserId': ownerUserId,
      'type': type.value,
      'typeLabel': type.label,
      'name': name,
      'relationLabel': relationLabel,
      'familyMemberId': familyMemberId,
      'gender': gender,
      'bloodType': bloodType,
      'age': age,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'allergies': allergies,
      'healthConditions': healthConditions,
      'currentMedications': currentMedications,
      'hasHealthData': hasHealthData,
    };
  }

  OrderBeneficiarySnapshot copyWith({
    String? beneficiaryId,
    String? ownerUserId,
    BeneficiaryType? type,
    String? name,
    String? relationLabel,
    String? familyMemberId,
    String? gender,
    String? bloodType,
    int? age,
    DateTime? dateOfBirth,
    List<String>? allergies,
    List<String>? healthConditions,
    List<String>? currentMedications,
    bool? hasHealthData,
  }) {
    return OrderBeneficiarySnapshot(
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      type: type ?? this.type,
      name: name ?? this.name,
      relationLabel: relationLabel ?? this.relationLabel,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      allergies: allergies ?? this.allergies,
      healthConditions: healthConditions ?? this.healthConditions,
      currentMedications: currentMedications ?? this.currentMedications,
      hasHealthData: hasHealthData ?? this.hasHealthData,
    );
  }
}

class OrderInsuranceSnapshot {
  final bool enabled;
  final String? beneficiaryId;
  final String? insuranceDocumentId;
  final String? companyCode;
  final String? companyName;
  final String? policyNumber;
  final List<String> companyCodes;
  final List<String> companyNames;
  final List<String> cardNumbers;

  const OrderInsuranceSnapshot({
    this.enabled = false,
    this.beneficiaryId,
    this.insuranceDocumentId,
    this.companyCode,
    this.companyName,
    this.policyNumber,
    this.companyCodes = const [],
    this.companyNames = const [],
    this.cardNumbers = const [],
  });

  bool get hasInsurance => enabled && companyCodes.isNotEmpty;

  factory OrderInsuranceSnapshot.fromMap(Map<String, dynamic> map) {
    return OrderInsuranceSnapshot(
      enabled: map['enabled'] == true,
      beneficiaryId: map['beneficiaryId']?.toString(),
      insuranceDocumentId: map['insuranceDocumentId']?.toString(),
      companyCode: map['companyCode']?.toString(),
      companyName: map['companyName']?.toString(),
      policyNumber: (map['policyNumber'] ?? map['cardNumber'])?.toString(),
      companyCodes: _toStringList(map['companyCodes']),
      companyNames: _toStringList(map['companyNames']),
      cardNumbers: _toStringList(map['cardNumbers']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'beneficiaryId': beneficiaryId,
      'insuranceDocumentId': insuranceDocumentId,
      'companyCode': companyCode,
      'companyName': companyName,
      'policyNumber': policyNumber,
      'companyCodes': companyCodes,
      'companyNames': companyNames,
      'cardNumbers': cardNumbers,
      'hasInsurance': hasInsurance,
    };
  }

  OrderInsuranceSnapshot copyWith({
    bool? enabled,
    String? beneficiaryId,
    String? insuranceDocumentId,
    String? companyCode,
    String? companyName,
    String? policyNumber,
    List<String>? companyCodes,
    List<String>? companyNames,
    List<String>? cardNumbers,
  }) {
    return OrderInsuranceSnapshot(
      enabled: enabled ?? this.enabled,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      insuranceDocumentId: insuranceDocumentId ?? this.insuranceDocumentId,
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
      policyNumber: policyNumber ?? this.policyNumber,
      companyCodes: companyCodes ?? this.companyCodes,
      companyNames: companyNames ?? this.companyNames,
      cardNumbers: cardNumbers ?? this.cardNumbers,
    );
  }
}

class OrderMedicineItem {
  final String requestedName;
  final String normalizedName;
  final String? strength;
  final String? dosageForm;
  final int quantity;
  final String? note;
  final String? matchedMedicineId;
  final String? matchedMedicineName;
  final double? estimatedPrice;
  final bool? availableAtSelection;
  final bool soldByPiece;
  final String? unit;
  final String? imageUrl;

  const OrderMedicineItem({
    required this.requestedName,
    required this.normalizedName,
    this.strength,
    this.dosageForm,
    this.quantity = 1,
    this.note,
    this.matchedMedicineId,
    this.matchedMedicineName,
    this.estimatedPrice,
    this.availableAtSelection,
    this.soldByPiece = false,
    this.unit,
    this.imageUrl,
  });

  String get displayName {
    final matched = matchedMedicineName?.trim();
    if (matched != null && matched.isNotEmpty) return matched;
    return requestedName;
  }

  double get lineTotal => (estimatedPrice ?? 0) * quantity;

  factory OrderMedicineItem.fromMap(Map<String, dynamic> map) {
    return OrderMedicineItem(
      requestedName: (map['requestedName'] ?? '').toString(),
      normalizedName: (map['normalizedName'] ?? '').toString(),
      strength: map['strength']?.toString(),
      dosageForm: map['dosageForm']?.toString(),
      quantity: map['quantity'] is int
          ? map['quantity'] as int
          : int.tryParse('${map['quantity']}') ?? 1,
      note: map['note']?.toString(),
      matchedMedicineId: map['matchedMedicineId']?.toString(),
      matchedMedicineName: map['matchedMedicineName']?.toString(),
      estimatedPrice: _toDouble(map['estimatedPrice']),
      availableAtSelection: map['availableAtSelection'] as bool?,
      soldByPiece: map['soldByPiece'] == true,
      unit: map['unit']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestedName': requestedName,
      'normalizedName': normalizedName,
      'strength': strength,
      'dosageForm': dosageForm,
      'quantity': quantity,
      'note': note,
      'matchedMedicineId': matchedMedicineId,
      'matchedMedicineName': matchedMedicineName,
      'estimatedPrice': estimatedPrice,
      'availableAtSelection': availableAtSelection,
      'soldByPiece': soldByPiece,
      'unit': unit,
      'imageUrl': imageUrl,
    };
  }

  OrderMedicineItem copyWith({
    String? requestedName,
    String? normalizedName,
    String? strength,
    String? dosageForm,
    int? quantity,
    String? note,
    String? matchedMedicineId,
    String? matchedMedicineName,
    double? estimatedPrice,
    bool? availableAtSelection,
    bool? soldByPiece,
    String? unit,
    String? imageUrl,
  }) {
    return OrderMedicineItem(
      requestedName: requestedName ?? this.requestedName,
      normalizedName: normalizedName ?? this.normalizedName,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      matchedMedicineId: matchedMedicineId ?? this.matchedMedicineId,
      matchedMedicineName: matchedMedicineName ?? this.matchedMedicineName,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      availableAtSelection: availableAtSelection ?? this.availableAtSelection,
      soldByPiece: soldByPiece ?? this.soldByPiece,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class OrderStatusLog {
  final String status;
  final String label;
  final String? changedById;
  final String? changedByType;
  final String? note;
  final DateTime? changedAt;

  const OrderStatusLog({
    required this.status,
    required this.label,
    this.changedById,
    this.changedByType,
    this.note,
    this.changedAt,
  });

  factory OrderStatusLog.fromMap(Map<String, dynamic> map) {
    return OrderStatusLog(
      status: (map['status'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      changedById: map['changedById']?.toString(),
      changedByType: map['changedByType']?.toString(),
      note: map['note']?.toString(),
      changedAt: _toDateTime(map['changedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'label': label,
      'changedById': changedById,
      'changedByType': changedByType,
      'note': note,
      'changedAt': changedAt != null
          ? Timestamp.fromDate(changedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class OrderModel {
  final int schemaVersion;
  final String id;
  final String? orderNumber;
  final String? orderDateKey;
  final int? dailySequence;
  final OrderUserSnapshot user;
  final OrderPharmacySnapshot pharmacy;
  final OrderBeneficiarySnapshot beneficiary;
  final OrderInsuranceSnapshot insurance;
  final OrderRequestSource requestSource;
  final String requestSourceLabel;
  final List<OrderMedicineItem> medicines;
  final OrderStatus status;
  final String statusLabel;
  final String? userNote;
  final String? pharmacyNote;
  final String? chatId;
  final int totalItemsCount;
  final double? estimatedTotalPrice;
  final double? initialCustomerEstimatedTotalPrice;
  final double? finalCustomerTotalPrice;
  final double? finalGrossTotalPrice;
  final double? finalInsuranceShare;
  final bool hasSensitiveHealthData;
  final bool containsInsurance;
  final String? prescriptionId;
  final String? prescriptionImageUrl;
  final String? prescriptionText;
  final Map<String, dynamic> metadata;
  final List<OrderStatusLog> statusHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? operationId;
  final String? payloadHash;
  final String? commandResultRef;
  final String? invoiceId;
  final int offerVersion;
  final int? acceptedOfferVersion;
  final Map<String, dynamic> partialOffer;
  final Map<String, dynamic> insuranceRemoval;
  final Map<String, dynamic> insuranceResolution;
  final String? reservationId;
  final String? reservationState;
  final DateTime? reviewStartedAt;
  final DateTime? pharmacyDelayAt;
  final DateTime? userDecisionStartedAt;
  final DateTime? userDecisionDeadline;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? pickupDeadline;
  final bool pickupOverdue;
  final bool pharmacyDelayed;
  final DateTime? deliveredAt;
  final DateTime? collectedAt;
  final DateTime? rejectedAt;
  final DateTime? notCollectedAt;

  const OrderModel({
    this.schemaVersion = 3,
    this.id = '',
    this.orderNumber,
    this.orderDateKey,
    this.dailySequence,
    required this.user,
    required this.pharmacy,
    required this.beneficiary,
    required this.insurance,
    required this.requestSource,
    required this.requestSourceLabel,
    required this.medicines,
    this.status = OrderStatus.received,
    this.statusLabel = 'تم إرسال الطلب',
    this.userNote,
    this.pharmacyNote,
    this.chatId,
    required this.totalItemsCount,
    this.estimatedTotalPrice,
    this.initialCustomerEstimatedTotalPrice,
    this.finalCustomerTotalPrice,
    this.finalGrossTotalPrice,
    this.finalInsuranceShare,
    this.hasSensitiveHealthData = false,
    this.containsInsurance = false,
    this.prescriptionId,
    this.prescriptionImageUrl,
    this.prescriptionText,
    this.metadata = const {},
    this.statusHistory = const [],
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.reviewedAt,
    this.completedAt,
    this.cancelledAt,
    this.operationId,
    this.payloadHash,
    this.commandResultRef,
    this.invoiceId,
    this.offerVersion = 0,
    this.acceptedOfferVersion,
    this.partialOffer = const {},
    this.insuranceRemoval = const {},
    this.insuranceResolution = const {},
    this.reservationId,
    this.reservationState,
    this.reviewStartedAt,
    this.pharmacyDelayAt,
    this.userDecisionStartedAt,
    this.userDecisionDeadline,
    this.preparingAt,
    this.readyAt,
    this.pickupDeadline,
    this.pickupOverdue = false,
    this.pharmacyDelayed = false,
    this.deliveredAt,
    this.collectedAt,
    this.rejectedAt,
    this.notCollectedAt,
  });

  bool get isPending =>
      status == OrderStatus.received || status == OrderStatus.underReview;
  bool get isManual => requestSource == OrderRequestSource.manual;
  bool get isPrescription => requestSource == OrderRequestSource.prescription;

  String get displayStatusLabel {
    if (status == OrderStatus.partialOfferPending) {
      if (partialOffer['kind'] == 'full')
        return 'بانتظار موافقة سعر الطلب الكامل';
      if (partialOffer['kind'] == 'replacement')
        return 'بانتظار موافقة تبديل الأصناف';
    }
    return status.label;
  }

  bool get isAwaitingInsuranceRemoval =>
      insuranceRemoval['status'] == 'pending' &&
      ![
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.rejected,
        OrderStatus.notCollected,
      ].contains(status);

  double? get currentCustomerTotalPrice {
    if (isAwaitingInsuranceRemoval) {
      final quote = insuranceRemoval['quote'];
      if (quote is Map) return _toDouble(quote['customerTotal']);
      return null;
    }
    if (status == OrderStatus.partialOfferPending &&
        partialOffer['quote'] is Map) {
      return _toDouble((partialOffer['quote'] as Map)['customerTotal']);
    }
    return finalCustomerTotalPrice ?? estimatedTotalPrice;
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    return OrderModel(
      schemaVersion: map['schemaVersion'] is int
          ? map['schemaVersion'] as int
          : int.tryParse('${map['schemaVersion']}') ?? 0,
      id: id,
      orderNumber: map['orderNumber']?.toString(),
      orderDateKey: map['orderDateKey']?.toString(),
      dailySequence: map['dailySequence'] is int
          ? map['dailySequence'] as int
          : int.tryParse('${map['dailySequence']}'),
      user: OrderUserSnapshot.fromMap(
        Map<String, dynamic>.from(map['user'] ?? {}),
      ),
      pharmacy: OrderPharmacySnapshot.fromMap(
        Map<String, dynamic>.from(map['pharmacy'] ?? {}),
      ),
      beneficiary: OrderBeneficiarySnapshot.fromMap(
        Map<String, dynamic>.from(map['beneficiary'] ?? {}),
      ),
      insurance: OrderInsuranceSnapshot.fromMap(
        Map<String, dynamic>.from(map['insurance'] ?? {}),
      ),
      requestSource: OrderRequestSourceX.fromValue(
        map['requestSource']?.toString(),
      ),
      requestSourceLabel: (map['requestSourceLabel'] ?? '').toString(),
      medicines: (map['medicines'] as List<dynamic>? ?? [])
          .map((e) => OrderMedicineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      status: OrderStatusX.fromValue(map['status']?.toString()),
      statusLabel: (map['statusLabel'] ?? '').toString(),
      userNote: map['userNote']?.toString(),
      pharmacyNote: map['pharmacyNote']?.toString(),
      chatId: map['chatId']?.toString(),
      totalItemsCount: map['totalItemsCount'] is int
          ? map['totalItemsCount'] as int
          : int.tryParse('${map['totalItemsCount']}') ?? 0,
      estimatedTotalPrice: _toDouble(map['estimatedTotalPrice']),
      initialCustomerEstimatedTotalPrice: _toDouble(
        map['initialCustomerEstimatedTotalPrice'],
      ),
      finalCustomerTotalPrice: _toDouble(map['finalCustomerTotalPrice']),
      finalGrossTotalPrice: _toDouble(map['finalGrossTotalPrice']),
      finalInsuranceShare: _toDouble(map['finalInsuranceShare']),
      hasSensitiveHealthData: map['hasSensitiveHealthData'] == true,
      containsInsurance: map['containsInsurance'] == true,
      prescriptionId: map['prescriptionId']?.toString(),
      prescriptionImageUrl: map['prescriptionImageUrl']?.toString(),
      prescriptionText: map['prescriptionText']?.toString(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? const {}),
      statusHistory: (map['statusHistory'] as List<dynamic>? ?? [])
          .map((e) => OrderStatusLog.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      submittedAt: _toDateTime(map['submittedAt']),
      reviewedAt: _toDateTime(map['reviewedAt']),
      completedAt: _toDateTime(map['completedAt']),
      cancelledAt: _toDateTime(map['cancelledAt']),
      operationId: map['operationId']?.toString(),
      payloadHash: map['payloadHash']?.toString(),
      commandResultRef: map['commandResultRef']?.toString(),
      invoiceId: map['invoiceId']?.toString(),
      offerVersion: map['offerVersion'] is int
          ? map['offerVersion'] as int
          : int.tryParse('${map['offerVersion']}') ?? 0,
      acceptedOfferVersion: map['acceptedOfferVersion'] is int
          ? map['acceptedOfferVersion'] as int
          : int.tryParse('${map['acceptedOfferVersion']}'),
      partialOffer: Map<String, dynamic>.from(map['partialOffer'] ?? const {}),
      insuranceResolution: Map<String, dynamic>.from(
        map['insuranceResolution'] ?? const {},
      ),
      insuranceRemoval: Map<String, dynamic>.from(
        map['insuranceRemoval'] ?? const {},
      ),
      reservationId: map['reservationId']?.toString(),
      reservationState: map['reservationState']?.toString(),
      reviewStartedAt: _toDateTime(map['reviewStartedAt']),
      pharmacyDelayAt: _toDateTime(map['pharmacyDelayAt']),
      userDecisionStartedAt: _toDateTime(map['userDecisionStartedAt']),
      userDecisionDeadline: _toDateTime(map['userDecisionDeadline']),
      preparingAt: _toDateTime(map['preparingAt']),
      readyAt: _toDateTime(map['readyAt']),
      pickupDeadline: _toDateTime(map['pickupDeadline']),
      pickupOverdue: map['pickupOverdue'] == true,
      pharmacyDelayed: map['pharmacyDelayed'] == true,
      deliveredAt: _toDateTime(map['deliveredAt']),
      collectedAt: _toDateTime(map['collectedAt']),
      rejectedAt: _toDateTime(map['rejectedAt']),
      notCollectedAt: _toDateTime(map['notCollectedAt']),
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderModel.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'user': user.toMap(),
      'orderNumber': orderNumber,
      'orderDateKey': orderDateKey,
      'dailySequence': dailySequence,
      'pharmacy': pharmacy.toMap(),
      'beneficiary': beneficiary.toMap(),
      'insurance': insurance.toMap(),
      'requestSource': requestSource.value,
      'requestSourceLabel': requestSourceLabel,
      'medicines': medicines.map((e) => e.toMap()).toList(),
      'status': status.value,
      'statusLabel': statusLabel,
      'userNote': userNote,
      'pharmacyNote': pharmacyNote,
      'chatId': chatId,
      'totalItemsCount': totalItemsCount,
      'estimatedTotalPrice': estimatedTotalPrice,
      'initialCustomerEstimatedTotalPrice': initialCustomerEstimatedTotalPrice,
      'finalCustomerTotalPrice': finalCustomerTotalPrice,
      'finalGrossTotalPrice': finalGrossTotalPrice,
      'finalInsuranceShare': finalInsuranceShare,
      'hasSensitiveHealthData': hasSensitiveHealthData,
      'containsInsurance': containsInsurance,
      'prescriptionId': prescriptionId,
      'prescriptionImageUrl': prescriptionImageUrl,
      'prescriptionText': prescriptionText,
      'metadata': metadata,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : null,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
      'operationId': operationId,
      'payloadHash': payloadHash,
      'commandResultRef': commandResultRef,
      'invoiceId': invoiceId,
      'offerVersion': offerVersion,
      'acceptedOfferVersion': acceptedOfferVersion,
      'partialOffer': partialOffer,
      'insuranceRemoval': insuranceRemoval,
      'insuranceResolution': insuranceResolution,
      'reservationId': reservationId,
      'reservationState': reservationState,
      'reviewStartedAt': reviewStartedAt != null
          ? Timestamp.fromDate(reviewStartedAt!)
          : null,
      'pharmacyDelayAt': pharmacyDelayAt != null
          ? Timestamp.fromDate(pharmacyDelayAt!)
          : null,
      'userDecisionStartedAt': userDecisionStartedAt != null
          ? Timestamp.fromDate(userDecisionStartedAt!)
          : null,
      'userDecisionDeadline': userDecisionDeadline != null
          ? Timestamp.fromDate(userDecisionDeadline!)
          : null,
      'preparingAt': preparingAt != null
          ? Timestamp.fromDate(preparingAt!)
          : null,
      'readyAt': readyAt != null ? Timestamp.fromDate(readyAt!) : null,
      'pickupDeadline': pickupDeadline != null
          ? Timestamp.fromDate(pickupDeadline!)
          : null,
      'pickupOverdue': pickupOverdue,
      'pharmacyDelayed': pharmacyDelayed,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'collectedAt': collectedAt != null
          ? Timestamp.fromDate(collectedAt!)
          : null,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'notCollectedAt': notCollectedAt != null
          ? Timestamp.fromDate(notCollectedAt!)
          : null,
    };
  }

  OrderModel copyWith({
    int? schemaVersion,
    String? id,
    String? orderNumber,
    String? orderDateKey,
    int? dailySequence,
    OrderUserSnapshot? user,
    OrderPharmacySnapshot? pharmacy,
    OrderBeneficiarySnapshot? beneficiary,
    OrderInsuranceSnapshot? insurance,
    OrderRequestSource? requestSource,
    String? requestSourceLabel,
    List<OrderMedicineItem>? medicines,
    OrderStatus? status,
    String? statusLabel,
    String? userNote,
    String? pharmacyNote,
    String? chatId,
    int? totalItemsCount,
    double? estimatedTotalPrice,
    double? initialCustomerEstimatedTotalPrice,
    double? finalCustomerTotalPrice,
    double? finalGrossTotalPrice,
    double? finalInsuranceShare,
    bool? hasSensitiveHealthData,
    bool? containsInsurance,
    String? prescriptionId,
    String? prescriptionImageUrl,
    String? prescriptionText,
    Map<String, dynamic>? metadata,
    List<OrderStatusLog>? statusHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? operationId,
    String? payloadHash,
    String? commandResultRef,
    String? invoiceId,
    int? offerVersion,
    int? acceptedOfferVersion,
    Map<String, dynamic>? partialOffer,
    Map<String, dynamic>? insuranceRemoval,
    Map<String, dynamic>? insuranceResolution,
    String? reservationId,
    String? reservationState,
    DateTime? reviewStartedAt,
    DateTime? pharmacyDelayAt,
    DateTime? userDecisionStartedAt,
    DateTime? userDecisionDeadline,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? pickupDeadline,
    bool? pickupOverdue,
    bool? pharmacyDelayed,
    DateTime? deliveredAt,
    DateTime? collectedAt,
    DateTime? rejectedAt,
    DateTime? notCollectedAt,
  }) {
    return OrderModel(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDateKey: orderDateKey ?? this.orderDateKey,
      dailySequence: dailySequence ?? this.dailySequence,
      user: user ?? this.user,
      pharmacy: pharmacy ?? this.pharmacy,
      beneficiary: beneficiary ?? this.beneficiary,
      insurance: insurance ?? this.insurance,
      requestSource: requestSource ?? this.requestSource,
      requestSourceLabel: requestSourceLabel ?? this.requestSourceLabel,
      medicines: medicines ?? this.medicines,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      userNote: userNote ?? this.userNote,
      pharmacyNote: pharmacyNote ?? this.pharmacyNote,
      chatId: chatId ?? this.chatId,
      totalItemsCount: totalItemsCount ?? this.totalItemsCount,
      estimatedTotalPrice: estimatedTotalPrice ?? this.estimatedTotalPrice,
      initialCustomerEstimatedTotalPrice:
          initialCustomerEstimatedTotalPrice ??
          this.initialCustomerEstimatedTotalPrice,
      finalCustomerTotalPrice:
          finalCustomerTotalPrice ?? this.finalCustomerTotalPrice,
      finalGrossTotalPrice: finalGrossTotalPrice ?? this.finalGrossTotalPrice,
      finalInsuranceShare: finalInsuranceShare ?? this.finalInsuranceShare,
      hasSensitiveHealthData:
          hasSensitiveHealthData ?? this.hasSensitiveHealthData,
      containsInsurance: containsInsurance ?? this.containsInsurance,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      prescriptionImageUrl: prescriptionImageUrl ?? this.prescriptionImageUrl,
      prescriptionText: prescriptionText ?? this.prescriptionText,
      metadata: metadata ?? this.metadata,
      statusHistory: statusHistory ?? this.statusHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      operationId: operationId ?? this.operationId,
      payloadHash: payloadHash ?? this.payloadHash,
      commandResultRef: commandResultRef ?? this.commandResultRef,
      invoiceId: invoiceId ?? this.invoiceId,
      offerVersion: offerVersion ?? this.offerVersion,
      acceptedOfferVersion: acceptedOfferVersion ?? this.acceptedOfferVersion,
      partialOffer: partialOffer ?? this.partialOffer,
      insuranceRemoval: insuranceRemoval ?? this.insuranceRemoval,
      insuranceResolution: insuranceResolution ?? this.insuranceResolution,
      reservationId: reservationId ?? this.reservationId,
      reservationState: reservationState ?? this.reservationState,
      reviewStartedAt: reviewStartedAt ?? this.reviewStartedAt,
      pharmacyDelayAt: pharmacyDelayAt ?? this.pharmacyDelayAt,
      userDecisionStartedAt:
          userDecisionStartedAt ?? this.userDecisionStartedAt,
      userDecisionDeadline: userDecisionDeadline ?? this.userDecisionDeadline,
      preparingAt: preparingAt ?? this.preparingAt,
      readyAt: readyAt ?? this.readyAt,
      pickupDeadline: pickupDeadline ?? this.pickupDeadline,
      pickupOverdue: pickupOverdue ?? this.pickupOverdue,
      pharmacyDelayed: pharmacyDelayed ?? this.pharmacyDelayed,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      collectedAt: collectedAt ?? this.collectedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      notCollectedAt: notCollectedAt ?? this.notCollectedAt,
    );
  }
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}
