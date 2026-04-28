import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../search/services/medicine_normalizer.dart';
import '../models/saved_prescription_model.dart';

class SavedPrescriptionService {
  SavedPrescriptionService._();

  static final SavedPrescriptionService instance = SavedPrescriptionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('المستخدم غير مسجل الدخول');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_prescriptions');
  }

  Stream<List<SavedPrescriptionModel>> getSavedPrescriptions() {
    final userId = _userId;

    return _collection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => SavedPrescriptionModel.fromDoc(doc))
          .toList(),
    );
  }

  Future<String> savePrescription({
    required BeneficiaryModel beneficiary,
    required List<MedicineModel> medicines,
    required String source,
    File? originalFile,
    String? originalFileType,
    String? note,
  }) async {
    final userId = _userId;

    final uniqueKey = _buildPrescriptionUniqueKey(
      userId: userId,
      beneficiaryId: beneficiary.id,
      source: source,
      medicines: medicines,
    );

    final duplicate = await _collection(userId)
        .where('uniqueKey', isEqualTo: uniqueKey)
        .limit(1)
        .get();

    if (duplicate.docs.isNotEmpty) {
      final existingDoc = duplicate.docs.first;

      await existingDoc.reference.update({
        'searchHistory': FieldValue.arrayUnion([Timestamp.now()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return existingDoc.id;
    }

    final docRef = _collection(userId).doc();

    String? downloadUrl;
    String? storagePath;
    String? fileName;

    if (originalFile != null) {
      fileName = originalFile.path.split(Platform.pathSeparator).last;
      final extension = fileName.contains('.') ? fileName.split('.').last : '';
      final safeExtension = extension.isEmpty ? 'file' : extension;

      storagePath =
      'users/$userId/saved_prescriptions/${docRef.id}/original_file.$safeExtension';

      final ref = _storage.ref(storagePath);

      await ref.putFile(
        originalFile,
        SettableMetadata(
          contentType: _resolveContentType(originalFileType, safeExtension),
        ),
      );

      downloadUrl = await ref.getDownloadURL();
    }

    final savedMedicines = medicines.map((medicine) {
      final raw = medicine.displayName.trim();

      return SavedPrescriptionMedicine(
        name: raw,
        rawText: raw,
        normalizedText: MedicineNormalizer.normalize(raw),
        strength: MedicineNormalizer.extractStrength(raw),
        dosageForm: MedicineNormalizer.extractDosageForm(raw),
      );
    }).toList();

    final title = _buildTitle(
      beneficiaryName: beneficiary.name,
      medicineCount: medicines.length,
    );

    final now = Timestamp.now();

    await docRef.set({
      'userId': userId,
      'uniqueKey': uniqueKey,
      'beneficiaryId': beneficiary.id,
      'beneficiaryName': beneficiary.name,
      'beneficiaryType': beneficiary.type,
      'beneficiaryRelation': beneficiary.relation,
      'source': source,
      'medicines': savedMedicines.map((e) => e.toMap()).toList(),
      'medicineCount': medicines.length,
      'hasOriginalFile': originalFile != null,
      'originalFileUrl': downloadUrl,
      'originalFileName': fileName,
      'originalFileType': originalFileType,
      'storagePath': storagePath,
      'title': title,
      'note': note,
      'searchHistory': [now],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }
  Future<void> recordPrescriptionSearch(String prescriptionId) async {
    final userId = _userId;

    await _collection(userId).doc(prescriptionId).update({
      'searchHistory': FieldValue.arrayUnion([Timestamp.now()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _buildPrescriptionUniqueKey({
    required String userId,
    required String beneficiaryId,
    required String source,
    required List<MedicineModel> medicines,
  }) {
    final names = medicines
        .map((m) => MedicineNormalizer.normalize(m.displayName.trim()))
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();

    return [
      userId,
      beneficiaryId,
      source,
      names.join('|'),
    ].join('__');
  }
  Future<void> deletePrescription(SavedPrescriptionModel prescription) async {
    final userId = _userId;

    if (prescription.storagePath != null &&
        prescription.storagePath!.trim().isNotEmpty) {
      try {
        await _storage.ref(prescription.storagePath).delete();
      } catch (_) {}
    }

    await _collection(userId).doc(prescription.id).delete();
  }

  Future<void> updateNote({
    required String prescriptionId,
    required String? note,
  }) async {
    final userId = _userId;

    await _collection(userId).doc(prescriptionId).update({
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _buildTitle({
    required String beneficiaryName,
    required int medicineCount,
  }) {
    return 'وصفة $beneficiaryName - $medicineCount أدوية';
  }

  String _resolveContentType(String? fileType, String extension) {
    final type = fileType?.toLowerCase().trim();

    if (type == 'pdf' || extension.toLowerCase() == 'pdf') {
      return 'application/pdf';
    }

    if (type == 'image') {
      final ext = extension.toLowerCase();
      if (ext == 'png') return 'image/png';
      if (ext == 'webp') return 'image/webp';
      return 'image/jpeg';
    }

    return 'application/octet-stream';
  }
}