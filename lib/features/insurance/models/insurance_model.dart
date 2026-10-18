import 'package:cloud_firestore/cloud_firestore.dart';

class InsuranceModel {
  final String id;
  final String companyCode;
  final String companyName;
  final String cardNumber;
  final String beneficiaryId;
  final String beneficiaryType;
  final String beneficiaryName;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> coveredMemberIds;

  const InsuranceModel({
    this.id = '',
    required this.companyCode,
    required this.companyName,
    required this.cardNumber,
    required this.beneficiaryId,
    required this.beneficiaryType,
    required this.beneficiaryName,
    this.startDate,
    this.endDate,
    this.coveredMemberIds = const [],
  });

  factory InsuranceModel.fromMap(String id, Map<String, dynamic> data) {
    final legacyMembers = List<String>.from(data['coveredMemberIds'] ?? []);
    final storedBeneficiaryId = (data['beneficiaryId'] ?? '').toString().trim();
    final beneficiaryId = storedBeneficiaryId.isNotEmpty
        ? storedBeneficiaryId
        : (legacyMembers.length == 1 ? legacyMembers.first : '');
    return InsuranceModel(
      id: id,
      companyName: (data['companyName'] ?? '').toString(),
      companyCode: (data['companyCode'] ?? '').toString(),
      cardNumber: (data['policyNumber'] ?? data['cardNumber'] ?? '').toString(),
      beneficiaryId: beneficiaryId,
      beneficiaryType:
          (data['beneficiaryType'] ??
                  (beneficiaryId == 'self' ? 'self' : 'family'))
              .toString(),
      beneficiaryName: (data['beneficiaryName'] ?? '').toString(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      coveredMemberIds: beneficiaryId.isNotEmpty
          ? <String>[beneficiaryId]
          : legacyMembers,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyCode': companyCode,
      'cardNumber': cardNumber,
      'policyNumber': cardNumber,
      'beneficiaryId': beneficiaryId,
      'beneficiaryType': beneficiaryType,
      'beneficiaryName': beneficiaryName,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'coveredMemberIds': <String>[beneficiaryId],
      'schemaVersion': 2,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  InsuranceModel copyWith({
    String? id,
    String? companyName,
    String? cardNumber,
    String? beneficiaryId,
    String? beneficiaryType,
    String? beneficiaryName,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? coveredMemberIds,
  }) {
    return InsuranceModel(
      id: id ?? this.id,
      companyCode: companyCode,
      companyName: companyName ?? this.companyName,
      cardNumber: cardNumber ?? this.cardNumber,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      beneficiaryType: beneficiaryType ?? this.beneficiaryType,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
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
