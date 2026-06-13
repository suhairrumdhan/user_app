import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../auth/controllers/auth_controller.dart';
import '../models/previous_medication_model.dart';

class PreviousMedicationsService {
  static final PreviousMedicationsService _instance =
  PreviousMedicationsService._internal();

  factory PreviousMedicationsService() => _instance;

  PreviousMedicationsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthController get _authController => Get.find<AuthController>();

  String? get _currentUserId => _authController.currentUserId;

  CollectionReference<Map<String, dynamic>> _userPreviousMedsRef(
      String userId,
      ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('previous_medications');
  }

  String resolveUserId([String? userId]) {
    final resolved = (userId ?? _currentUserId)?.trim();
    if (resolved == null || resolved.isEmpty) {
      throw StateError('User ID is required but was not available.');
    }
    return resolved;
  }

  // =========================================================
  // Streams
  // =========================================================

  Stream<List<PreviousMedicationModel>> watchAll({
    String? userId,
    String? beneficiaryId,
    String? status,
  }) {
    final resolvedUserId = resolveUserId(userId);

    Query<Map<String, dynamic>> query = _userPreviousMedsRef(resolvedUserId);

    if (beneficiaryId != null && beneficiaryId.trim().isNotEmpty) {
      query = query.where(
        'ownerBeneficiaryId',
        isEqualTo: beneficiaryId.trim(),
      );
    }

    if (status != null && status.trim().isNotEmpty) {
      query = query.where(
        'status',
        isEqualTo: status.trim(),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map(
          (snapshot) => snapshot.docs
          .map(PreviousMedicationModel.fromFirestore)
          .toList(),
    );
  }

  Stream<List<PreviousMedicationModel>> watchVisibleToPharmacist({
    String? userId,
    String? beneficiaryId,
  }) {
    final resolvedUserId = resolveUserId(userId);

    Query<Map<String, dynamic>> query = _userPreviousMedsRef(resolvedUserId)
        .where('isVisibleToPharmacist', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (beneficiaryId != null && beneficiaryId.trim().isNotEmpty) {
      query = _userPreviousMedsRef(resolvedUserId)
          .where('ownerBeneficiaryId', isEqualTo: beneficiaryId.trim())
          .where('isVisibleToPharmacist', isEqualTo: true)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      final all = snapshot.docs
          .map(PreviousMedicationModel.fromFirestore)
          .toList();

      return all.where((item) => item.isCurrentlyVisibleToPharmacist).toList();
    });
  }

  // =========================================================
  // Reads
  // =========================================================

  Future<List<PreviousMedicationModel>> getAll({
    String? userId,
    String? beneficiaryId,
    String? status,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    Query<Map<String, dynamic>> query = _userPreviousMedsRef(resolvedUserId);

    if (beneficiaryId != null && beneficiaryId.trim().isNotEmpty) {
      query = query.where(
        'ownerBeneficiaryId',
        isEqualTo: beneficiaryId.trim(),
      );
    }

    if (status != null && status.trim().isNotEmpty) {
      query = query.where(
        'status',
        isEqualTo: status.trim(),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    final snapshot = await query.get();

    return snapshot.docs.map(PreviousMedicationModel.fromFirestore).toList();
  }

  Future<List<PreviousMedicationModel>> getVisibleToPharmacist({
    String? userId,
    String? beneficiaryId,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    Query<Map<String, dynamic>> query = _userPreviousMedsRef(resolvedUserId)
        .where('isVisibleToPharmacist', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (beneficiaryId != null && beneficiaryId.trim().isNotEmpty) {
      query = _userPreviousMedsRef(resolvedUserId)
          .where('ownerBeneficiaryId', isEqualTo: beneficiaryId.trim())
          .where('isVisibleToPharmacist', isEqualTo: true)
          .orderBy('createdAt', descending: true);
    }

    final snapshot = await query.get();

    final all = snapshot.docs.map(PreviousMedicationModel.fromFirestore).toList();

    return all.where((item) => item.isCurrentlyVisibleToPharmacist).toList();
  }

  Future<PreviousMedicationModel?> getById(
      String recordId, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    final doc = await _userPreviousMedsRef(resolvedUserId).doc(recordId).get();

    if (!doc.exists) return null;
    return PreviousMedicationModel.fromFirestore(doc);
  }

  Future<bool> existsForOrderMedicine({
    required String orderId,
    required String ownerBeneficiaryId,
    required String medicineName,
    String? userId,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    final docId = PreviousMedicationModel.buildDocId(
      orderId: orderId,
      ownerBeneficiaryId: ownerBeneficiaryId,
      medicineName: medicineName,
    );

    final doc = await _userPreviousMedsRef(resolvedUserId).doc(docId).get();
    return doc.exists;
  }

  // =========================================================
  // Writes
  // =========================================================

  Future<void> addRecord(
      PreviousMedicationModel model, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    if (model.id.trim().isEmpty) {
      throw ArgumentError('Previous medication id must not be empty.');
    }

    await _userPreviousMedsRef(resolvedUserId)
        .doc(model.id)
        .set(model.toMap(includeServerTimestamp: true));
  }
  Future<PreviousMedicationModel> addFromMedicationReminder({
    String? userId,
    required String ownerBeneficiaryId,
    required String ownerName,
    required String ownerType,
    required String ownerRelation,
    required String medicineName,
    String? dosage,
    String? route,
    String? notes,
    DateTime? treatmentStartDate,
    DateTime? treatmentEndDate,
    int? linkedReminderLocalId,
  }) async {
    final resolvedUserId = resolveUserId(userId);
    final now = DateTime.now();

    final recordId = _buildReminderRecordId(
      ownerBeneficiaryId: ownerBeneficiaryId,
      medicineName: medicineName,
      linkedReminderLocalId: linkedReminderLocalId,
    );

    final record = PreviousMedicationModel(
      id: recordId,
      userId: resolvedUserId,
      ownerBeneficiaryId: ownerBeneficiaryId,
      ownerName: ownerName,
      ownerType: ownerType,
      ownerRelation: ownerRelation,
      medicineName: medicineName.trim(),
      dosage: _readNullableString(dosage),
      route: _readNullableString(route),
      notes: _readNullableString(notes),
      pharmacyId: null,
      pharmacyName: null,
      orderId: null,
      addedFromNotificationId: null,
      takenAt: now,
      treatmentStartDate: treatmentStartDate,
      treatmentEndDate: treatmentEndDate,
      showToPharmacistFrom: now,
      showToPharmacistUntil: treatmentEndDate,
      isVisibleToPharmacist: true,
      reminderStatus: linkedReminderLocalId == null
          ? PreviousMedicationReminderStatus.none
          : PreviousMedicationReminderStatus.linked,
      linkedReminderLocalId: linkedReminderLocalId,
      status: _resolveInitialStatus(treatmentEndDate),
      createdAt: now,
      updatedAt: now,
    );

    await addOrUpdateRecord(record, userId: resolvedUserId, merge: true);
    return record;
  }

  String _buildReminderRecordId({
    required String ownerBeneficiaryId,
    required String medicineName,
    int? linkedReminderLocalId,
  }) {
    final safeOwner = _safeDocPart(ownerBeneficiaryId);
    final safeMedicine = _safeDocPart(medicineName);
    final reminderPart = linkedReminderLocalId?.toString() ?? 'manual';

    return 'reminder_${reminderPart}_${safeOwner}_$safeMedicine';
  }

  String _safeDocPart(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    if (cleaned.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  Future<void> addOrUpdateRecord(
      PreviousMedicationModel model, {
        String? userId,
        bool merge = true,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    if (model.id.trim().isEmpty) {
      throw ArgumentError('Previous medication id must not be empty.');
    }

    final data = model.copyWith(
      touchUpdatedAt: true,
    ).toMap(includeServerTimestamp: false);

    data['updatedAt'] = FieldValue.serverTimestamp();
    data['createdAt'] = FieldValue.serverTimestamp();

    await _userPreviousMedsRef(resolvedUserId).doc(model.id).set(
      data,
      SetOptions(merge: merge),
    );
  }

  Future<void> addRecordsBatch(
      List<PreviousMedicationModel> records, {
        String? userId,
      }) async {
    if (records.isEmpty) return;

    final resolvedUserId = resolveUserId(userId);
    final batch = _firestore.batch();

    for (final record in records) {
      if (record.id.trim().isEmpty) continue;

      final ref = _userPreviousMedsRef(resolvedUserId).doc(record.id);

      final data = record.toMap(includeServerTimestamp: false);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      batch.set(ref, data, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<PreviousMedicationModel> addFromOrderMedicine({
    String? userId,
    required String orderId,
    required Map<String, dynamic> beneficiarySnapshot,
    required Map<String, dynamic> medicineItem,
    required DateTime takenAt,
    DateTime? treatmentStartDate,
    DateTime? treatmentEndDate,
    DateTime? showToPharmacistFrom,
    DateTime? showToPharmacistUntil,
    bool isVisibleToPharmacist = true,
    String? pharmacyId,
    String? pharmacyName,
    String? notificationId,
    String? notes,
    bool overwriteIfExists = true,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    final ownerBeneficiaryId =
    _readRequiredString(beneficiarySnapshot['beneficiaryId']);
    final ownerName = _readPreferredString(
      beneficiarySnapshot['name'],
      fallback: 'مستفيد',
    );
    final ownerType = _normalizeOwnerType(beneficiarySnapshot['type']);
    final ownerRelation = _readPreferredString(
      beneficiarySnapshot['relationLabel'],
      fallback: ownerType == 'self' ? 'أنا' : 'فرد من العائلة',
    );

    final medicineName = _extractMedicineName(medicineItem);

    final recordId = PreviousMedicationModel.buildDocId(
      orderId: orderId,
      ownerBeneficiaryId: ownerBeneficiaryId,
      medicineName: medicineName,
    );

    final record = PreviousMedicationModel(
      id: recordId,
      userId: resolvedUserId,
      ownerBeneficiaryId: ownerBeneficiaryId,
      ownerName: ownerName,
      ownerType: ownerType,
      ownerRelation: ownerRelation,
      medicineName: medicineName,
      dosage: _extractDosage(medicineItem),
      route: _extractRoute(medicineItem),
      notes: _mergeNotes(
        itemNote: _readNullableString(medicineItem['note']),
        customNote: notes,
      ),
      pharmacyId: _readNullableString(pharmacyId),
      pharmacyName: _readNullableString(pharmacyName),
      orderId: orderId.trim(),
      addedFromNotificationId: _readNullableString(notificationId),
      takenAt: takenAt,
      treatmentStartDate: treatmentStartDate,
      treatmentEndDate: treatmentEndDate,
      showToPharmacistFrom: showToPharmacistFrom,
      showToPharmacistUntil: showToPharmacistUntil,
      isVisibleToPharmacist: isVisibleToPharmacist,
      reminderStatus: PreviousMedicationReminderStatus.none,
      linkedReminderLocalId: null,
      status: _resolveInitialStatus(treatmentEndDate),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final exists = await getById(recordId, userId: resolvedUserId);

    if (exists != null && !overwriteIfExists) {
      return exists;
    }

    await addOrUpdateRecord(record, userId: resolvedUserId, merge: true);
    return record;
  }

  Future<List<PreviousMedicationModel>> addBatchFromOrder({
    String? userId,
    required String orderId,
    required Map<String, dynamic> beneficiarySnapshot,
    required List<Map<String, dynamic>> medicineItems,
    required DateTime takenAt,
    DateTime? treatmentStartDate,
    DateTime? treatmentEndDate,
    DateTime? showToPharmacistFrom,
    DateTime? showToPharmacistUntil,
    bool isVisibleToPharmacist = true,
    String? pharmacyId,
    String? pharmacyName,
    String? notificationId,
    bool skipIfAlreadyExists = true,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    if (medicineItems.isEmpty) return [];

    final ownerBeneficiaryId =
    _readRequiredString(beneficiarySnapshot['beneficiaryId']);
    final ownerName = _readPreferredString(
      beneficiarySnapshot['name'],
      fallback: 'مستفيد',
    );
    final ownerType = _normalizeOwnerType(beneficiarySnapshot['type']);
    final ownerRelation = _readPreferredString(
      beneficiarySnapshot['relationLabel'],
      fallback: ownerType == 'self' ? 'أنا' : 'فرد من العائلة',
    );

    final now = DateTime.now();
    final batch = _firestore.batch();
    final created = <PreviousMedicationModel>[];

    for (final item in medicineItems) {
      final medicineName = _extractMedicineName(item);

      if (medicineName.trim().isEmpty) {
        continue;
      }

      final recordId = PreviousMedicationModel.buildDocId(
        orderId: orderId,
        ownerBeneficiaryId: ownerBeneficiaryId,
        medicineName: medicineName,
      );

      final ref = _userPreviousMedsRef(resolvedUserId).doc(recordId);

      if (skipIfAlreadyExists) {
        final existing = await ref.get();
        if (existing.exists) {
          continue;
        }
      }

      final record = PreviousMedicationModel(
        id: recordId,
        userId: resolvedUserId,
        ownerBeneficiaryId: ownerBeneficiaryId,
        ownerName: ownerName,
        ownerType: ownerType,
        ownerRelation: ownerRelation,
        medicineName: medicineName,
        dosage: _extractDosage(item),
        route: _extractRoute(item),
        notes: _readNullableString(item['note']),
        pharmacyId: _readNullableString(pharmacyId),
        pharmacyName: _readNullableString(pharmacyName),
        orderId: orderId.trim(),
        addedFromNotificationId: _readNullableString(notificationId),
        takenAt: takenAt,
        treatmentStartDate: treatmentStartDate,
        treatmentEndDate: treatmentEndDate,
        showToPharmacistFrom: showToPharmacistFrom,
        showToPharmacistUntil: showToPharmacistUntil,
        isVisibleToPharmacist: isVisibleToPharmacist,
        reminderStatus: PreviousMedicationReminderStatus.none,
        linkedReminderLocalId: null,
        status: _resolveInitialStatus(treatmentEndDate),
        createdAt: now,
        updatedAt: now,
      );

      final data = record.toMap(includeServerTimestamp: false);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      batch.set(ref, data, SetOptions(merge: true));
      created.add(record);
    }

    if (created.isEmpty) return const [];

    await batch.commit();
    return created;
  }

  // =========================================================
  // Lifecycle updates
  // =========================================================

  Future<void> markCompleted(
      String recordId, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'status': PreviousMedicationStatus.completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveRecord(
      String recordId, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'status': PreviousMedicationStatus.archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopPharmacistVisibility(
      String recordId, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'isVisibleToPharmacist': false,
      'showToPharmacistUntil': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPharmacistVisibilityWindow({
    required String recordId,
    String? userId,
    required bool isVisibleToPharmacist,
    DateTime? from,
    DateTime? until,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'isVisibleToPharmacist': isVisibleToPharmacist,
      'showToPharmacistFrom': from != null ? Timestamp.fromDate(from) : null,
      'showToPharmacistUntil':
      until != null ? Timestamp.fromDate(until) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReminderLinked({
    required String recordId,
    required int localReminderId,
    String? userId,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'reminderStatus': PreviousMedicationReminderStatus.linked,
      'linkedReminderLocalId': localReminderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReminderCompleted({
    required String recordId,
    String? userId,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'reminderStatus': PreviousMedicationReminderStatus.completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearReminderLink({
    required String recordId,
    String? userId,
  }) async {
    final resolvedUserId = resolveUserId(userId);

    await _userPreviousMedsRef(resolvedUserId).doc(recordId).update({
      'reminderStatus': PreviousMedicationReminderStatus.none,
      'linkedReminderLocalId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRecord(
      String recordId, {
        String? userId,
      }) async {
    final resolvedUserId = resolveUserId(userId);
    await _userPreviousMedsRef(resolvedUserId).doc(recordId).delete();
  }

  // =========================================================
  // Helpers
  // =========================================================

  String _extractMedicineName(Map<String, dynamic> item) {
    final value = _readPreferredString(
      item['matchedMedicineName'],
      fallback: _readPreferredString(
        item['medicineName'],
        fallback: _readPreferredString(
          item['requestedName'],
          fallback: '',
        ),
      ),
    );

    if (value.trim().isEmpty) {
      throw ArgumentError('Medicine item does not contain a valid medicine name.');
    }

    return value;
  }

  String? _extractDosage(Map<String, dynamic> item) {
    final strength = _readNullableString(item['strength']);
    final dosage = _readNullableString(item['dosage']);

    if (dosage != null && dosage.isNotEmpty) return dosage;
    if (strength != null && strength.isNotEmpty) return strength;

    return null;
  }

  String? _extractRoute(Map<String, dynamic> item) {
    final route = _readNullableString(item['route']);
    if (route != null) return route;

    final dosageForm = _readNullableString(item['dosageForm']);
    if (dosageForm != null) return dosageForm;

    return null;
  }

  String _normalizeOwnerType(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    if (raw == 'self') return 'self';
    if (raw == 'family') return 'family';

    if (raw == 'beneficiarytype.self') return 'self';
    if (raw == 'beneficiarytype.family') return 'family';

    return 'family';
  }

  String _resolveInitialStatus(DateTime? treatmentEndDate) {
    if (treatmentEndDate == null) {
      return PreviousMedicationStatus.active;
    }

    return DateTime.now().isAfter(treatmentEndDate)
        ? PreviousMedicationStatus.completed
        : PreviousMedicationStatus.active;
  }

  String _readRequiredString(dynamic value) {
    final parsed = _readNullableString(value);
    if (parsed == null || parsed.isEmpty) {
      throw ArgumentError('A required string value was missing.');
    }
    return parsed;
  }

  String _readPreferredString(
      dynamic value, {
        required String fallback,
      }) {
    final parsed = _readNullableString(value);
    if (parsed == null || parsed.isEmpty) return fallback;
    return parsed;
  }

  String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  String? _mergeNotes({
    String? itemNote,
    String? customNote,
  }) {
    final a = _readNullableString(itemNote);
    final b = _readNullableString(customNote);

    if (a == null && b == null) return null;
    if (a != null && b == null) return a;
    if (a == null && b != null) return b;
    if (a == b) return a;

    return '$a\n$b';
  }
}