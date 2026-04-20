import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/previous_medication_model.dart';
import '../services/previous_medications_service.dart';

enum PreviousMedicationsFilter {
  all,
  active,
  completed,
  archived,
  visibleToPharmacist,
  hiddenFromPharmacist,
  withReminder,
  withoutReminder,
}

class PreviousMedicationsController extends GetxController {
  final PreviousMedicationsService _service;

  PreviousMedicationsController({
    PreviousMedicationsService? service,
  }) : _service = service ?? PreviousMedicationsService();

  // =========================================================
  // State
  // =========================================================

  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isProcessing = false.obs;

  final RxList<PreviousMedicationModel> allRecords =
      <PreviousMedicationModel>[].obs;

  final Rx<PreviousMedicationsFilter> selectedFilter =
      PreviousMedicationsFilter.all.obs;

  final RxnString selectedBeneficiaryId = RxnString();
  final RxnString selectedRecordId = RxnString();

  StreamSubscription<List<PreviousMedicationModel>>? _recordsSubscription;

  // =========================================================
  // Lifecycle
  // =========================================================

  @override
  void onInit() {
    super.onInit();
    bindRecordsStream();
  }

  @override
  void onClose() {
    _recordsSubscription?.cancel();
    super.onClose();
  }

  // =========================================================
  // Stream Binding
  // =========================================================

  void bindRecordsStream({
    String? beneficiaryId,
  }) {
    _recordsSubscription?.cancel();

    if (beneficiaryId != null) {
      selectedBeneficiaryId.value =
      beneficiaryId.trim().isEmpty ? null : beneficiaryId.trim();
    }

    isLoading.value = true;

    _recordsSubscription = _service
        .watchAll(
      beneficiaryId: selectedBeneficiaryId.value,
    )
        .listen(
          (records) {
        allRecords.assignAll(records);
        isLoading.value = false;
      },
      onError: (_) {
        isLoading.value = false;
        Get.snackbar(
          'خطأ',
          'تعذر تحميل الأدوية السابقة',
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }

  Future<void> refreshRecords() async {
    try {
      isRefreshing.value = true;

      final data = await _service.getAll(
        beneficiaryId: selectedBeneficiaryId.value,
      );

      allRecords.assignAll(data);
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث الأدوية السابقة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isRefreshing.value = false;
    }
  }

  // =========================================================
  // Filters
  // =========================================================

  void setFilter(PreviousMedicationsFilter filter) {
    selectedFilter.value = filter;
  }

  void setBeneficiaryFilter(String? beneficiaryId) {
    final cleaned = beneficiaryId?.trim();
    selectedBeneficiaryId.value =
    (cleaned == null || cleaned.isEmpty) ? null : cleaned;
    bindRecordsStream();
  }

  void clearBeneficiaryFilter() {
    selectedBeneficiaryId.value = null;
    bindRecordsStream();
  }

  void selectRecord(String? recordId) {
    final cleaned = recordId?.trim();
    selectedRecordId.value =
    (cleaned == null || cleaned.isEmpty) ? null : cleaned;
  }

  void clearSelectedRecord() {
    selectedRecordId.value = null;
  }

  // =========================================================
  // Derived Lists / Stats
  // =========================================================

  List<PreviousMedicationModel> get filteredRecords {
    final filter = selectedFilter.value;
    final source = List<PreviousMedicationModel>.from(allRecords);

    switch (filter) {
      case PreviousMedicationsFilter.all:
        return source;

      case PreviousMedicationsFilter.active:
        return source.where((e) => e.isActive).toList();

      case PreviousMedicationsFilter.completed:
        return source.where((e) => e.isCompleted).toList();

      case PreviousMedicationsFilter.archived:
        return source.where((e) => e.isArchived).toList();

      case PreviousMedicationsFilter.visibleToPharmacist:
        return source.where((e) => e.isCurrentlyVisibleToPharmacist).toList();

      case PreviousMedicationsFilter.hiddenFromPharmacist:
        return source.where((e) => !e.isCurrentlyVisibleToPharmacist).toList();

      case PreviousMedicationsFilter.withReminder:
        return source.where((e) => e.hasLinkedReminder).toList();

      case PreviousMedicationsFilter.withoutReminder:
        return source.where((e) => !e.hasLinkedReminder).toList();
    }
  }

  PreviousMedicationModel? get selectedRecord {
    final id = selectedRecordId.value;
    if (id == null || id.isEmpty) return null;

    try {
      return allRecords.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  int get totalCount => allRecords.length;
  int get filteredCount => filteredRecords.length;
  int get activeCount => allRecords.where((e) => e.isActive).length;
  int get completedCount => allRecords.where((e) => e.isCompleted).length;
  int get archivedCount => allRecords.where((e) => e.isArchived).length;

  int get visibleToPharmacistCount =>
      allRecords.where((e) => e.isCurrentlyVisibleToPharmacist).length;

  int get hiddenFromPharmacistCount =>
      allRecords.where((e) => !e.isCurrentlyVisibleToPharmacist).length;

  int get withReminderCount =>
      allRecords.where((e) => e.hasLinkedReminder).length;

  int get withoutReminderCount =>
      allRecords.where((e) => !e.hasLinkedReminder).length;

  String getFilterLabel(PreviousMedicationsFilter filter) {
    switch (filter) {
      case PreviousMedicationsFilter.all:
        return 'الكل';
      case PreviousMedicationsFilter.active:
        return 'نشطة';
      case PreviousMedicationsFilter.completed:
        return 'مكتملة';
      case PreviousMedicationsFilter.archived:
        return 'مؤرشفة';
      case PreviousMedicationsFilter.visibleToPharmacist:
        return 'ظاهرة للصيدلي';
      case PreviousMedicationsFilter.hiddenFromPharmacist:
        return 'مخفية عن الصيدلي';
      case PreviousMedicationsFilter.withReminder:
        return 'مرتبطة بتذكير';
      case PreviousMedicationsFilter.withoutReminder:
        return 'بدون تذكير';
    }
  }

  // =========================================================
  // Reads
  // =========================================================

  Future<PreviousMedicationModel?> loadById(String recordId) async {
    try {
      return await _service.getById(recordId);
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحميل تفاصيل الدواء',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  Future<bool> existsForOrderMedicine({
    required String orderId,
    required String ownerBeneficiaryId,
    required String medicineName,
  }) async {
    try {
      return await _service.existsForOrderMedicine(
        orderId: orderId,
        ownerBeneficiaryId: ownerBeneficiaryId,
        medicineName: medicineName,
      );
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // Create
  // =========================================================

  Future<PreviousMedicationModel?> addFromOrderMedicine({
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
    bool showSuccessMessage = false,
  }) async {
    try {
      isProcessing.value = true;

      final record = await _service.addFromOrderMedicine(
        orderId: orderId,
        beneficiarySnapshot: beneficiarySnapshot,
        medicineItem: medicineItem,
        takenAt: takenAt,
        treatmentStartDate: treatmentStartDate,
        treatmentEndDate: treatmentEndDate,
        showToPharmacistFrom: showToPharmacistFrom,
        showToPharmacistUntil: showToPharmacistUntil,
        isVisibleToPharmacist: isVisibleToPharmacist,
        pharmacyId: pharmacyId,
        pharmacyName: pharmacyName,
        notificationId: notificationId,
        notes: notes,
        overwriteIfExists: overwriteIfExists,
      );

      if (showSuccessMessage) {
        Get.snackbar(
          'تم',
          'تمت إضافة الدواء إلى السجل السابق',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      return record;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر إضافة الدواء إلى السجل السابق',
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  Future<List<PreviousMedicationModel>> addBatchFromOrder({
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
    bool showSuccessMessage = false,
  }) async {
    try {
      isProcessing.value = true;

      final records = await _service.addBatchFromOrder(
        orderId: orderId,
        beneficiarySnapshot: beneficiarySnapshot,
        medicineItems: medicineItems,
        takenAt: takenAt,
        treatmentStartDate: treatmentStartDate,
        treatmentEndDate: treatmentEndDate,
        showToPharmacistFrom: showToPharmacistFrom,
        showToPharmacistUntil: showToPharmacistUntil,
        isVisibleToPharmacist: isVisibleToPharmacist,
        pharmacyId: pharmacyId,
        pharmacyName: pharmacyName,
        notificationId: notificationId,
        skipIfAlreadyExists: skipIfAlreadyExists,
      );

      if (showSuccessMessage && records.isNotEmpty) {
        Get.snackbar(
          'تم',
          'تمت إضافة ${records.length} دواء إلى السجل السابق',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      return records;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر إضافة الأدوية إلى السجل السابق',
        snackPosition: SnackPosition.BOTTOM,
      );
      return const [];
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> addManualRecord(PreviousMedicationModel model) async {
    try {
      isProcessing.value = true;
      await _service.addOrUpdateRecord(model, merge: true);
      Get.snackbar(
        'تم',
        'تم حفظ الدواء السابق بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر حفظ الدواء السابق',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  // =========================================================
  // Update / Status
  // =========================================================

  Future<void> markCompleted(String recordId) async {
    try {
      isProcessing.value = true;
      await _service.markCompleted(recordId);
      Get.snackbar(
        'تم',
        'تم تحديث حالة الدواء إلى مكتمل',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث حالة الدواء',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> archiveRecord(String recordId) async {
    try {
      isProcessing.value = true;
      await _service.archiveRecord(recordId);
      Get.snackbar(
        'تم',
        'تمت أرشفة السجل',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر أرشفة السجل',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> stopPharmacistVisibility(String recordId) async {
    try {
      isProcessing.value = true;
      await _service.stopPharmacistVisibility(recordId);
      Get.snackbar(
        'تم',
        'تم إخفاء الدواء عن الصيدلي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث ظهور الدواء للصيدلي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> setPharmacistVisibilityWindow({
    required String recordId,
    required bool isVisibleToPharmacist,
    DateTime? from,
    DateTime? until,
  }) async {
    try {
      isProcessing.value = true;

      await _service.setPharmacistVisibilityWindow(
        recordId: recordId,
        isVisibleToPharmacist: isVisibleToPharmacist,
        from: from,
        until: until,
      );

      Get.snackbar(
        'تم',
        'تم تحديث مدة الظهور للصيدلي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث مدة الظهور للصيدلي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> updateRecord(PreviousMedicationModel updatedModel) async {
    try {
      isProcessing.value = true;

      await _service.addOrUpdateRecord(
        updatedModel.copyWith(touchUpdatedAt: true),
        merge: true,
      );

      Get.snackbar(
        'تم',
        'تم تحديث بيانات الدواء',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث بيانات الدواء',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  // =========================================================
  // Reminder Link
  // =========================================================

  Future<void> markReminderLinked({
    required String recordId,
    required int localReminderId,
  }) async {
    try {
      isProcessing.value = true;

      await _service.markReminderLinked(
        recordId: recordId,
        localReminderId: localReminderId,
      );

      Get.snackbar(
        'تم',
        'تم ربط الدواء بتذكير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر ربط التذكير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> markReminderCompleted({
    required String recordId,
  }) async {
    try {
      isProcessing.value = true;

      await _service.markReminderCompleted(
        recordId: recordId,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر تحديث حالة التذكير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> clearReminderLink({
    required String recordId,
  }) async {
    try {
      isProcessing.value = true;

      await _service.clearReminderLink(
        recordId: recordId,
      );

      Get.snackbar(
        'تم',
        'تم حذف ربط التذكير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر حذف ربط التذكير',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  // =========================================================
  // Delete
  // =========================================================

  Future<void> deleteRecord(String recordId) async {
    try {
      isProcessing.value = true;
      await _service.deleteRecord(recordId);

      if (selectedRecordId.value == recordId) {
        clearSelectedRecord();
      }

      Get.snackbar(
        'تم',
        'تم حذف السجل',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذر حذف السجل',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isProcessing.value = false;
    }
  }

  // =========================================================
  // UI Helpers
  // =========================================================

  Color getStatusColor(PreviousMedicationModel item) {
    if (item.isArchived) return Colors.grey;
    if (item.isCompleted) return Colors.green;
    return const Color(0xFF5EABD6);
  }

  Color getVisibilityColor(PreviousMedicationModel item) {
    return item.isCurrentlyVisibleToPharmacist
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);
  }

  Color getReminderColor(PreviousMedicationModel item) {
    if (item.hasLinkedReminder) {
      return const Color(0xFF7E57C2);
    }
    return const Color(0xFF90A4AE);
  }

  String buildSubtitle(PreviousMedicationModel item) {
    final parts = <String>[];

    if (item.ownerName.trim().isNotEmpty) {
      parts.add(item.ownerName);
    }

    if (item.hasPharmacyName) {
      parts.add(item.pharmacyName!.trim());
    }

    return parts.join(' • ');
  }
}