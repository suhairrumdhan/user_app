import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../prescription/models/beneficiary_model.dart';
import '../data/models/medication_reminder_model.dart';
import '../data/models/reminder_owner_embedded.dart';
import '../domain/helpers/reminder_time_helper.dart';
import 'reminders_controller.dart';

class AddMedicationReminderController extends GetxController {
  final RemindersController remindersController = Get.find<RemindersController>();

  // ========= Form Fields =========

  final medicineNameController = TextEditingController();
  final dosageController = TextEditingController();
  final routeController = TextEditingController();
  final notesController = TextEditingController();

  final Rxn<BeneficiaryModel> selectedBeneficiary = Rxn<BeneficiaryModel>();

  final Rx<DateTime> startDate = DateTime.now().obs;
  final Rxn<DateTime> endDate = Rxn<DateTime>();

  final RxList<String> times = <String>[].obs;

  final RxBool saveToHealthRecord = false.obs;
  final RxBool isSaving = false.obs;

  // ========= Lifecycle =========

  @override
  void onClose() {
    medicineNameController.dispose();
    dosageController.dispose();
    routeController.dispose();
    notesController.dispose();
    super.onClose();
  }

  // ========= Setters =========

  void setBeneficiary(BeneficiaryModel beneficiary) {
    selectedBeneficiary.value = beneficiary;
  }

  void setStartDate(DateTime date) {
    startDate.value = DateTime(date.year, date.month, date.day);
  }

  void setEndDate(DateTime? date) {
    if (date == null) {
      endDate.value = null;
      return;
    }
    endDate.value = DateTime(date.year, date.month, date.day);
  }

  void toggleSaveToHealthRecord(bool value) {
    saveToHealthRecord.value = value;
  }

  // ========= Time Management =========

  void addTime(TimeOfDay time) {
    final formatted = ReminderTimeHelper.formatTimeOfDay(time);
    final updated = [...times, formatted];
    times.value = ReminderTimeHelper.normalizeAndSortTimes(updated);
  }

  void removeTime(String time) {
    final updated = [...times]..remove(time);
    times.value = ReminderTimeHelper.normalizeAndSortTimes(updated);
  }

  void replaceTime({
    required String oldTime,
    required TimeOfDay newTime,
  }) {
    final formatted = ReminderTimeHelper.formatTimeOfDay(newTime);
    final updated = [...times];
    final index = updated.indexOf(oldTime);
    if (index != -1) {
      updated[index] = formatted;
    } else {
      updated.add(formatted);
    }
    times.value = ReminderTimeHelper.normalizeAndSortTimes(updated);
  }

  bool hasTime(String time) {
    return times.contains(time);
  }

  // ========= Validation =========

  String? validateMedicineName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم الدواء مطلوب';
    }
    if (value.trim().length < 2) {
      return 'اسم الدواء قصير جدًا';
    }
    return null;
  }

  String? validateBeneficiary() {
    if (selectedBeneficiary.value == null) {
      return 'اختر المستفيد أولًا';
    }
    return null;
  }

  String? validateTimes() {
    if (times.isEmpty) {
      return 'أضف وقتًا واحدًا على الأقل';
    }
    return null;
  }

  String? validateDateRange() {
    final end = endDate.value;
    if (end == null) return null;

    final start = startDate.value;
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);

    if (endOnly.isBefore(startOnly)) {
      return 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
    }
    return null;
  }

  bool validateAll() {
    return validateMedicineName(medicineNameController.text) == null &&
        validateBeneficiary() == null &&
        validateTimes() == null &&
        validateDateRange() == null;
  }

  // ========= Builders =========

  MedicationReminderModel buildReminderModel() {
    final beneficiary = selectedBeneficiary.value;
    if (beneficiary == null) {
      throw StateError('Beneficiary is required before building reminder.');
    }

    final medicineName = medicineNameController.text.trim();
    if (medicineName.isEmpty) {
      throw StateError('Medicine name is required before building reminder.');
    }

    final reminder = MedicationReminderModel()
      ..medicineName = medicineName
      ..dosage = dosageController.text.trim().isEmpty
          ? null
          : dosageController.text.trim()
      ..route = routeController.text.trim().isEmpty
          ? null
          : routeController.text.trim()
      ..notes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim()
      ..owner = ReminderOwnerEmbedded.fromBeneficiary(beneficiary)
      ..startDate = startDate.value
      ..endDate = endDate.value
      ..times = ReminderTimeHelper.normalizeAndSortTimes([...times])
      ..notificationIds = <int>[]
      ..status = 'active'
      ..saveToHealthRecord = saveToHealthRecord.value
      ..createdAt = DateTime.now();

    return reminder;
  }

  // ========= Prefill =========

  void prefillFromMedicine({
    required String medicineName,
    String? dosage,
    String? route,
    BeneficiaryModel? beneficiary,
  }) {
    medicineNameController.text = medicineName;
    dosageController.text = dosage ?? '';
    routeController.text = route ?? '';

    if (beneficiary != null) {
      selectedBeneficiary.value = beneficiary;
    }
  }

  // ========= Save =========

  Future<bool> saveReminder() async {
    if (!validateAll()) return false;

    try {
      isSaving.value = true;

      final reminder = buildReminderModel();
      await remindersController.addMedicationReminder(reminder);

      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في حفظ التذكير: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ========= Reset =========

  void resetForm() {
    medicineNameController.clear();
    dosageController.clear();
    routeController.clear();
    notesController.clear();

    selectedBeneficiary.value = null;
    startDate.value = DateTime.now();
    endDate.value = null;
    times.clear();
    saveToHealthRecord.value = false;
    isSaving.value = false;
  }
}