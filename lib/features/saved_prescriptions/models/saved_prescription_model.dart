import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPrescriptionModel {
  final String id;
  final String userId;

  final String beneficiaryId;
  final String beneficiaryName;
  final String beneficiaryType; // self | family
  final String beneficiaryRelation;

  final String source; // manual | prescription
  final List<SavedPrescriptionMedicine> medicines;
  final int medicineCount;

  final bool hasOriginalFile;
  final String? originalFileUrl;
  final String? originalFileName;
  final String? originalFileType; // image | pdf
  final String? storagePath;

  final String title;
  final String? note;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String uniqueKey;
  final List<DateTime> searchHistory;

  const SavedPrescriptionModel({
    required this.uniqueKey,
    required this.searchHistory,
    required this.id,
    required this.userId,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.beneficiaryType,
    required this.beneficiaryRelation,
    required this.source,
    required this.medicines,
    required this.medicineCount,
    required this.hasOriginalFile,
    this.originalFileUrl,
    this.originalFileName,
    this.originalFileType,
    this.storagePath,
    required this.title,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory SavedPrescriptionModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return SavedPrescriptionModel(
      uniqueKey: data['uniqueKey']?.toString() ?? '',
      searchHistory: ((data['searchHistory'] as List?) ?? [])
          .map(_toDate)
          .whereType<DateTime>()
          .toList(),
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      beneficiaryId: data['beneficiaryId']?.toString() ?? '',
      beneficiaryName: data['beneficiaryName']?.toString() ?? '',
      beneficiaryType: data['beneficiaryType']?.toString() ?? 'self',
      beneficiaryRelation: data['beneficiaryRelation']?.toString() ?? '',
      source: data['source']?.toString() ?? 'manual',
      medicines: ((data['medicines'] as List?) ?? [])
          .map((item) => SavedPrescriptionMedicine.fromMap(
        Map<String, dynamic>.from(item as Map),
      ))
          .toList(),
      medicineCount: data['medicineCount'] ?? 0,
      hasOriginalFile: data['hasOriginalFile'] ?? false,
      originalFileUrl: data['originalFileUrl']?.toString(),
      originalFileName: data['originalFileName']?.toString(),
      originalFileType: data['originalFileType']?.toString(),
      storagePath: data['storagePath']?.toString(),
      title: data['title']?.toString() ?? 'وصفة محفوظة',
      note: data['note']?.toString(),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'uniqueKey': uniqueKey,
      'searchHistory': searchHistory,
      'userId': userId,
      'beneficiaryId': beneficiaryId,
      'beneficiaryName': beneficiaryName,
      'beneficiaryType': beneficiaryType,
      'beneficiaryRelation': beneficiaryRelation,
      'source': source,
      'medicines': medicines.map((e) => e.toMap()).toList(),
      'medicineCount': medicineCount,
      'hasOriginalFile': hasOriginalFile,
      'originalFileUrl': originalFileUrl,
      'originalFileName': originalFileName,
      'originalFileType': originalFileType,
      'storagePath': storagePath,
      'title': title,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class SavedPrescriptionMedicine {
  final String name;
  final String? rawText;
  final String? normalizedText;
  final String? strength;
  final String? dosageForm;

  const SavedPrescriptionMedicine({
    required this.name,
    this.rawText,
    this.normalizedText,
    this.strength,
    this.dosageForm,
  });

  factory SavedPrescriptionMedicine.fromMap(Map<String, dynamic> map) {
    return SavedPrescriptionMedicine(
      name: map['name']?.toString() ?? '',
      rawText: map['rawText']?.toString(),
      normalizedText: map['normalizedText']?.toString(),
      strength: map['strength']?.toString(),
      dosageForm: map['dosageForm']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rawText': rawText,
      'normalizedText': normalizedText,
      'strength': strength,
      'dosageForm': dosageForm,
    };
  }
}