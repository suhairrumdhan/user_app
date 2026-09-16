import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/features/search/models/matched_medicine_result.dart';

import '../../search/models/pharmacy_search_result.dart';

class PharmacyModel {
  // الحقول الأساسية من PharmacyModel
  final String id;
  final String email;
  final String pharmacyName;
  final String ownerName;
  final String licenseNumber;
  final String licenseFileUrl;
  final String ownerIdFileUrl;
  final String ownerIdNumber;
  final String phoneNumber;
  final String imageUrl;
  final String status;
  final bool is24Hours;
  final bool isOnline;

  final Map<String, dynamic> location;
  final List<String> categories;

  final Map<String, dynamic>? workingHours;
  final double? distance;

  final DateTime? requestDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedDate;
  final DateTime? lastStatusUpdate;

  final List<String> acceptedInsuranceCodes;

  // الحقول المضافة من PharmacyDisplayModel
  final bool isOpenNow;
  final double distanceKm;
  final double totalEstimatedPrice;
  final double pharmacyScore;
  final List<MatchedMedicineResult> matchedMedicines;
  final List<String> missingMedicines;
  final List<String> matchedInsuranceCodes;

  // المُنشئ الرئيسي المدمج
  const PharmacyModel({
    required this.id,
    required this.email,
    required this.pharmacyName,
    required this.ownerName,
    required this.licenseNumber,
    required this.licenseFileUrl,
    required this.ownerIdFileUrl,
    required this.ownerIdNumber,
    required this.phoneNumber,
    required this.imageUrl,
    required this.status,
    required this.is24Hours,
    required this.isOnline,
    required this.location,
    required this.categories,
    this.workingHours,
    this.distance,
    this.requestDate,
    this.createdAt,
    this.updatedAt,
    this.approvedDate,
    this.lastStatusUpdate,
    required this.acceptedInsuranceCodes,
    // الحقول المضافة من PharmacyDisplayModel
    this.isOpenNow = false,
    this.distanceKm = 0.0,
    this.totalEstimatedPrice = 0.0,
    this.pharmacyScore = 0.0,
    this.matchedMedicines = const [],
    this.missingMedicines = const [],
    this.matchedInsuranceCodes = const [],
  });

  // Getters من PharmacyModel
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasPhone => phoneNumber.trim().isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;

  String get displayName =>
      pharmacyName.trim().isEmpty ? 'صيدلية' : pharmacyName.trim();

  String get address => (location['address'] ?? '').toString().trim();

  String get displayAddress =>
      address.isEmpty ? 'العنوان غير متوفر' : address;

  double? get latitude {
    final value = location['latitude'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? get longitude {
    final value = location['longitude'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<double> get locationCoordinates {
    if (latitude == null || longitude == null) return <double>[];
    return [latitude!, longitude!];
  }

  // Getters المضافة من PharmacyDisplayModel
  bool get supportsInsurance => matchedInsuranceCodes.isNotEmpty;
  bool get hasMatchedInsurance => matchedInsuranceCodes.isNotEmpty;

  String get insuranceLabel {
    if (!hasMatchedInsurance) return 'بدون تأمين';
    if (matchedInsuranceCodes.length == 1) return 'تأمين متوافق';
    return 'عدة شركات متوافقة';
  }

  int get matchedCount => matchedMedicines.length;
  int get missingCount => missingMedicines.length;
  int get requestedCount => matchedCount + missingCount;

  bool get hasFullMatch => missingMedicines.isEmpty;

  bool get hasPartialMatch =>
      matchedMedicines.isNotEmpty && missingMedicines.isNotEmpty;

  double get coveragePercent {
    if (requestedCount == 0) return 0;
    return (matchedCount / requestedCount) * 100;
  }

  double get averageMatchScore {
    if (matchedMedicines.isEmpty) return 0;
    final total = matchedMedicines.fold<double>(
      0,
          (sum, item) => sum + item.matchScore,
    );
    return total / matchedMedicines.length;
  }

  String get statusLabel {
    if (is24Hours) return '24 ساعة';
    return isOpenNow ? 'مفتوحة الآن' : 'مغلقة الآن';
  }

  String get matchLabel => hasFullMatch ? 'تطابق كامل' : 'تطابق جزئي';

  bool get hasKnownDistance => distanceKm >= 0;

  String get displayDistance => hasKnownDistance
      ? '${distanceKm.toStringAsFixed(1)} كم'
      : 'غير متوفرة';
  String get displayPrice => '${totalEstimatedPrice.toStringAsFixed(2)} د.ل';

  bool get hasValidCoordinates => latitude != null && longitude != null;
  bool get hasImageUrl => (imageUrl.trim().isNotEmpty);
  bool get hasPhoneNumber => (phoneNumber.trim().isNotEmpty);

  // Methods من PharmacyModel
  PharmacyModel copyWith({
    String? id,
    String? email,
    String? pharmacyName,
    String? ownerName,
    String? licenseNumber,
    String? licenseFileUrl,
    String? ownerIdFileUrl,
    String? ownerIdNumber,
    String? phoneNumber,
    String? imageUrl,
    String? status,
    bool? is24Hours,
    bool? isOnline,
    Map<String, dynamic>? location,
    List<String>? categories,
    Map<String, dynamic>? workingHours,
    double? distance,
    DateTime? requestDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedDate,
    DateTime? lastStatusUpdate,
    List<String>? acceptedInsuranceCodes,
    // الحقول المضافة
    bool? isOpenNow,
    double? distanceKm,
    double? totalEstimatedPrice,
    double? pharmacyScore,
    List<MatchedMedicineResult>? matchedMedicines,
    List<String>? missingMedicines,
    List<String>? matchedInsuranceCodes,
  }) {
    return PharmacyModel(
      id: id ?? this.id,
      email: email ?? this.email,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      ownerName: ownerName ?? this.ownerName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseFileUrl: licenseFileUrl ?? this.licenseFileUrl,
      ownerIdFileUrl: ownerIdFileUrl ?? this.ownerIdFileUrl,
      ownerIdNumber: ownerIdNumber ?? this.ownerIdNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      is24Hours: is24Hours ?? this.is24Hours,
      isOnline: isOnline ?? this.isOnline,
      location: location ?? this.location,
      categories: categories ?? this.categories,
      workingHours: workingHours ?? this.workingHours,
      distance: distance ?? this.distance,
      requestDate: requestDate ?? this.requestDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedDate: approvedDate ?? this.approvedDate,
      lastStatusUpdate: lastStatusUpdate ?? this.lastStatusUpdate,
      acceptedInsuranceCodes:
      acceptedInsuranceCodes ?? this.acceptedInsuranceCodes,
      // الحقول المضافة
      isOpenNow: isOpenNow ?? this.isOpenNow,
      distanceKm: distanceKm ?? this.distanceKm,
      totalEstimatedPrice: totalEstimatedPrice ?? this.totalEstimatedPrice,
      pharmacyScore: pharmacyScore ?? this.pharmacyScore,
      matchedMedicines: matchedMedicines ?? this.matchedMedicines,
      missingMedicines: missingMedicines ?? this.missingMedicines,
      matchedInsuranceCodes: matchedInsuranceCodes ?? this.matchedInsuranceCodes,
    );
  }

  // Factory constructor من Firestore
  factory PharmacyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        Map<String, dynamic>? workingHours,
        double? distance,
      }) {
    final data = doc.data() ?? {};

    final rawLocation = data['location'];
    final locationMap = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : <String, dynamic>{};

    return PharmacyModel(
      id: doc.id,
      email: (data['email'] ?? '').toString(),
      pharmacyName: (data['pharmacyName'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      licenseNumber: (data['licenseNumber'] ?? '').toString(),
      licenseFileUrl: (data['licenseFileUrl'] ?? '').toString(),
      ownerIdFileUrl: (data['ownerIdFileUrl'] ?? '').toString(),
      ownerIdNumber: (data['ownerIdNumber'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      is24Hours: data['is24Hours'] == true,
      isOnline: data['isOnline'] == true,
      location: locationMap,
      categories: _toStringList(data['categories']),
      workingHours: workingHours,
      distance: distance,
      requestDate: _toDateTime(data['requestDate']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      approvedDate: _toDateTime(data['approvedDate']),
      lastStatusUpdate: _toDateTime(data['lastStatusUpdate']),
      acceptedInsuranceCodes: _toStringList(data['acceptedInsuranceCodes']),
      // القيم الافتراضية للحقول المضافة
      isOpenNow: false,
      distanceKm: 0.0,
      totalEstimatedPrice: 0.0,
      pharmacyScore: 0.0,
      matchedMedicines: const [],
      missingMedicines: const [],
      matchedInsuranceCodes: const [],
    );
  }

  // Factory constructor من PharmacySearchResult
// Factory constructor من PharmacySearchResult
  factory PharmacyModel.fromSearchResult(
      PharmacySearchResult result, {
        required PharmacyModel pharmacy,
      }) {
    return pharmacy.copyWith(
      isOpenNow: result.isOpenNow,
      distanceKm: result.distanceKm,
      totalEstimatedPrice: result.totalEstimatedPrice,
      pharmacyScore: result.pharmacyScore,
      matchedMedicines: result.matchedMedicines,
      missingMedicines: result.missingMedicines,
      matchedInsuranceCodes: result.matchedInsuranceCodes,
    );
  }

  // toMap method
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'pharmacyName': pharmacyName,
      'ownerName': ownerName,
      'licenseNumber': licenseNumber,
      'licenseFileUrl': licenseFileUrl,
      'ownerIdFileUrl': ownerIdFileUrl,
      'ownerIdNumber': ownerIdNumber,
      'phoneNumber': phoneNumber,
      'imageUrl': imageUrl,
      'status': status,
      'is24Hours': is24Hours,
      'isOnline': isOnline,
      'location': location,
      'categories': categories,
      'workingHours': workingHours,
      'distance': distance,
      'requestDate': requestDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'approvedDate': approvedDate,
      'lastStatusUpdate': lastStatusUpdate,
      'acceptedInsuranceCodes': acceptedInsuranceCodes,
      'isOpenNow': isOpenNow,
      'distanceKm': distanceKm,
      'totalEstimatedPrice': totalEstimatedPrice,
      'pharmacyScore': pharmacyScore,
      'matchedMedicines': matchedMedicines.map((e) => e.toMap()).toList(),
      'missingMedicines': missingMedicines,
      'matchedInsuranceCodes': matchedInsuranceCodes,
    };
  }

  // Helper methods
  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}
