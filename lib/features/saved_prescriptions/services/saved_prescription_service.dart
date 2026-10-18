import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../search/services/medicine_normalizer.dart';
import '../models/saved_prescription_model.dart';

class SavedPrescriptionService {
  SavedPrescriptionService({
    FirebaseFirestore? firestore,
    String? Function()? currentUserId,
    Future<String> Function(File, String, String?)? uploadFile,
    Future<void> Function(String)? deleteFile,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _uploadFile = uploadFile,
       _deleteFile = deleteFile;

  static final SavedPrescriptionService instance = SavedPrescriptionService();
  final FirebaseFirestore _firestore;
  final String? Function() _currentUserId;
  final Future<String> Function(File, String, String?)? _uploadFile;
  final Future<void> Function(String)? _deleteFile;
  final _cleaning = <String>{};
  FirebaseStorage get _storage => FirebaseStorage.instance;

  String get _userId {
    final uid = _currentUserId();
    if (uid == null || uid.isEmpty)
      throw StateError('سجل الدخول لإدارة الوصفات.');
    return uid;
  }

  void _requireUser(String uid) {
    if (_currentUserId() != uid)
      throw StateError('تغير الحساب. افتح الوصفة من الحساب الحالي.');
  }

  Future<String> _upload(File file, String path, String? contentType) async {
    if (_uploadFile != null) return _uploadFile(file, path, contentType);
    final ref = _storage.ref(path);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> _removeFile(String path) async {
    if (_deleteFile != null) return _deleteFile(path);
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_prescriptions');
  }

  Stream<List<SavedPrescriptionModel>> getSavedPrescriptions() {
    final uid = _userId;
    return _collection(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      _requireUser(uid);
      for (final doc in snapshot.docs) {
        if (doc.data()['state'] == 'deleting') {
          unawaited(
            _finishDelete(uid, doc.id, doc.data()['storagePath'] as String?),
          );
        }
      }
      return snapshot.docs
          .where((doc) => !['saving', 'deleting'].contains(doc.data()['state']))
          .map(SavedPrescriptionModel.fromDoc)
          .toList();
    });
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

    final fileHash = originalFile == null
        ? null
        : sha256.convert(await originalFile.readAsBytes()).toString();
    final names =
        medicines
            .map(
              (medicine) =>
                  MedicineNormalizer.normalize(medicine.displayName.trim()),
            )
            .toList()
          ..sort();
    final uniqueKey = sha256
        .convert(
          utf8.encode(
            jsonEncode([userId, beneficiary.id, source, names, fileHash]),
          ),
        )
        .toString();
    final docRef = _collection(userId).doc(uniqueKey);
    final fileName = originalFile?.path.split(Platform.pathSeparator).last;
    final extension = fileName != null && fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'file';
    final storagePath = originalFile == null
        ? null
        : 'users/$userId/saved_prescriptions/$uniqueKey/original_file';

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

    final record = <String, dynamic>{
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
      'originalFileUrl': null,
      'originalFileName': fileName,
      'originalFileType': originalFileType,
      'storagePath': storagePath,
      'title': title,
      'note': note,
      'searchHistory': [now],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final saved = await _firestore.runTransaction((transaction) async {
      _requireUser(userId);
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        if (snapshot.data()?['state'] == 'deleting')
          throw StateError('الوصفة قيد الحذف. حاول مرة أخرى.');
        return snapshot.data()?['state'] != 'saving';
      }
      transaction.set(docRef, {...record, 'state': 'saving'});
      return false;
    });
    if (saved) return docRef.id;
    _requireUser(userId);
    final url = originalFile == null
        ? null
        : await _upload(
            originalFile,
            storagePath!,
            _resolveContentType(originalFileType, extension),
          );
    await _firestore.runTransaction((transaction) async {
      _requireUser(userId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data()?['state'] == 'deleting') {
        throw StateError('الوصفة لم تعد متاحة للحفظ.');
      }
      if (snapshot.data()?['state'] != 'saving') return;
      transaction.update(docRef, {
        'state': 'saved',
        'originalFileUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  Future<void> deletePrescription(SavedPrescriptionModel prescription) async {
    final uid = _userId;
    if (prescription.userId != uid)
      throw StateError('الوصفة لا تخص الحساب الحالي.');
    final ref = _collection(uid).doc(prescription.id);
    final path = await _firestore.runTransaction((transaction) async {
      _requireUser(uid);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return null;
      transaction.update(ref, {
        'state': 'deleting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return snapshot.data()?['storagePath'] as String?;
    });
    // The durable deletion marker is the user-visible commit. Failed file cleanup
    // remains discoverable and is resumed when the archive is opened again.
    await _finishDelete(uid, prescription.id, path);
  }

  Future<void> _finishDelete(String uid, String id, String? path) async {
    final key = '$uid:$id';
    if (!_cleaning.add(key)) return;
    try {
      _requireUser(uid);
      if (path != null && path.isNotEmpty) {
        if (!path.startsWith('users/$uid/saved_prescriptions/$id/')) {
          throw StateError('مسار ملف الوصفة غير صالح.');
        }
        await _removeFile(path);
      }
      await _firestore.runTransaction((transaction) async {
        _requireUser(uid);
        final ref = _collection(uid).doc(id);
        final snapshot = await transaction.get(ref);
        if (snapshot.data()?['state'] == 'deleting') transaction.delete(ref);
      });
    } catch (error) {
      // Keep the committed marker and storage path for safe retry.
      print('Prescription cleanup deferred: $error');
    } finally {
      _cleaning.remove(key);
    }
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
