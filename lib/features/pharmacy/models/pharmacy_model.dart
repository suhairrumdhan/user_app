import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyModel {
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

  final String address;
  final double? latitude;
  final double? longitude;

  final List<double> locationCoordinates;
  final Map<String, dynamic> location;
  final List<String> categories;

  final Map<String, dynamic>? workingHours;
  final double? distance;

  final DateTime? requestDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedDate;
  final DateTime? lastStatusUpdate;

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
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.locationCoordinates,
    required this.location,
    required this.categories,
    this.workingHours,
    this.distance,
    this.requestDate,
    this.createdAt,
    this.updatedAt,
    this.approvedDate,
    this.lastStatusUpdate,
  });

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasPhone => phoneNumber.trim().isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;

  String get displayName =>
      pharmacyName.trim().isEmpty ? 'صيدلية' : pharmacyName.trim();

  String get displayAddress =>
      address.trim().isEmpty ? 'العنوان غير متوفر' : address.trim();

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
    String? address,
    double? latitude,
    double? longitude,
    List<double>? locationCoordinates,
    Map<String, dynamic>? location,
    List<String>? categories,
    Map<String, dynamic>? workingHours,
    double? distance,
    DateTime? requestDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedDate,
    DateTime? lastStatusUpdate,
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
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationCoordinates: locationCoordinates ?? this.locationCoordinates,
      location: location ?? this.location,
      categories: categories ?? this.categories,
      workingHours: workingHours ?? this.workingHours,
      distance: distance ?? this.distance,
      requestDate: requestDate ?? this.requestDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedDate: approvedDate ?? this.approvedDate,
      lastStatusUpdate: lastStatusUpdate ?? this.lastStatusUpdate,
    );
  }

  factory PharmacyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        Map<String, dynamic>? workingHours,
        double? distance,
      }) {
    final data = doc.data() ?? {};

    final locationMap = data['location'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['location'])
        : <String, dynamic>{};

    final coords = _toDoubleList(data['locationCoordinates']);

    final lat = _toDouble(data['latitude']) ??
        _toDouble(locationMap['latitude']) ??
        (coords.isNotEmpty ? coords[0] : null);

    final lng = _toDouble(data['longitude']) ??
        _toDouble(locationMap['longitude']) ??
        (coords.length > 1 ? coords[1] : null);

    final resolvedAddress = (data['address'] ?? '').toString().trim().isNotEmpty
        ? data['address'].toString()
        : (locationMap['address'] ?? '').toString();

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
      address: resolvedAddress,
      latitude: lat,
      longitude: lng,
      locationCoordinates: coords,
      location: locationMap,
      categories: _toStringList(data['categories']),
      workingHours: workingHours,
      distance: distance,
      requestDate: _toDateTime(data['requestDate']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      approvedDate: _toDateTime(data['approvedDate']),
      lastStatusUpdate: _toDateTime(data['lastStatusUpdate']),
    );
  }

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
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'locationCoordinates': locationCoordinates,
      'location': location,
      'categories': categories,
      'workingHours': workingHours,
      'distance': distance,
      'requestDate': requestDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'approvedDate': approvedDate,
      'lastStatusUpdate': lastStatusUpdate,
    };
  }

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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<double> _toDoubleList(dynamic value) {
    if (value is List) {
      return value.map((e) => _toDouble(e) ?? 0.0).toList();
    }
    return <double>[];
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}