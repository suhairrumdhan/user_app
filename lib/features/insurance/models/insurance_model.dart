import 'package:cloud_firestore/cloud_firestore.dart';

class InsuranceModel {
  final String id;
  final String companyCode;
  final String companyName;
  final String cardNumber;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> coveredMemberIds;

  const InsuranceModel({
    this.id = '',
    required this.companyCode,
    required this.companyName,
    required this.cardNumber,
    this.startDate,
    this.endDate,
    this.coveredMemberIds = const [],
  });

  factory InsuranceModel.fromMap(String id, Map<String, dynamic> data) {
    return InsuranceModel(
      id: id,
      companyName: (data['companyName'] ?? '').toString(),
      companyCode: (data['companyCode'] ?? '').toString(),
      cardNumber: (data['cardNumber'] ?? '').toString(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      coveredMemberIds: List<String>.from(data['coveredMemberIds'] ?? []),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyCode': companyCode,
      'cardNumber': cardNumber,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'coveredMemberIds': coveredMemberIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
  InsuranceModel copyWith({
    String? id,
    String? companyName,
    String? cardNumber,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? coveredMemberIds,
  }) {
    return InsuranceModel(
      id: id ?? this.id,
      companyCode: companyCode,
      companyName: companyName ?? this.companyName,
      cardNumber: cardNumber ?? this.cardNumber,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coveredMemberIds: coveredMemberIds ?? this.coveredMemberIds,
    );
  }

  bool get isActive {
    if (startDate == null || endDate == null) return false;
    final now = DateTime.now();
    return !now.isBefore(startDate!) && !now.isAfter(endDate!);
  }
}