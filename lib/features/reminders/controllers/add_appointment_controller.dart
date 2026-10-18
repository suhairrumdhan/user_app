import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../prescription/models/beneficiary_model.dart';
import '../data/models/appointment_reminder_model.dart';
import '../data/models/reminder_owner_embedded.dart';
import 'reminders_controller.dart';

class AddAppointmentController extends GetxController {
  final RemindersController remindersController = Get.find<RemindersController>();

  // ========= Form Fields =========

  final titleController = TextEditingController();
  final notesController = TextEditingController();
  final locationController = TextEditingController();

  final Rxn<BeneficiaryModel> selectedBeneficiary = Rxn<BeneficiaryModel>();

  final Rx<DateTime> appointmentDate = DateTime.now().obs;
  final Rx<TimeOfDay> appointmentTime = TimeOfDay.now().obs;

  /// قبل الموعد بكم دقيقة
  final RxInt remindBeforeMinutes = 30.obs;

  final RxBool saveToHealthRecord = false.obs;
  final RxBool isSaving = false.obs;

  static const List<int> reminderOptions = [5, 10, 15, 30, 60, 120, 1440];

  @override
  void onClose() {
    titleController.dispose();
    notesController.dispose();
    locationController.dispose();
    super.onClose();
  }

  // ========= Setters =========

  void setBeneficiary(BeneficiaryModel beneficiary) {
    selectedBeneficiary.value = beneficiary;
  }

  void setAppointmentDate(DateTime date) {
    appointmentDate.value = DateTime(date.year, date.month, date.day);
  }

  void setAppointmentTime(TimeOfDay time) {
    appointmentTime.value = time;
  }

  void setRemindBeforeMinutes(int minutes) {
    remindBeforeMinutes.value = minutes;
  }

  void toggleSaveToHealthRecord(bool value) {
    saveToHealthRecord.value = value;
  }

  // ========= Computed =========

  DateTime get combinedAppointmentDateTime {
    final date = appointmentDate.value;
    final time = appointmentTime.value;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get reminderTriggerDateTime {
    return combinedAppointmentDateTime.subtract(
      Duration(minutes: remindBeforeMinutes.value),
    );
  }

  bool get isReminderInFuture {
    return reminderTriggerDateTime.isAfter(DateTime.now());
  }

  String get remindBeforeLabel {
    final value = remindBeforeMinutes.value;
    if (value == 1440) return 'قبل يوم';
    if (value >= 60) {
      final hours = value ~/ 60;
      return hours == 1 ? 'قبل ساعة' : 'قبل $hours ساعات';
    }
    return value == 1 ? 'قبل دقيقة' : 'قبل $value دقيقة';
  }

  // ========= Validation =========

  String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'عنوان الموعد مطلوب';
    }
    if (value.trim().length < 2) {
      return 'عنوان الموعد قصير جدًا';
    }
    return null;
  }

  String? validateBeneficiary() {
    if (selectedBeneficiary.value == null) {
      return 'اختر المستفيد أولًا';
    }
    return null;
  }

  String? validateAppointmentDateTime() {
    final appointment = combinedAppointmentDateTime;

    if (!appointment.isAfter(DateTime.now())) {
      return 'وقت الموعد يجب أن يكون في المستقبل';
    }

    final trigger = reminderTriggerDateTime;
    if (!trigger.isAfter(DateTime.now())) {
      return 'وقت التذكير الناتج أصبح في الماضي، اختر موعدًا أبعد أو قلل وقت التذكير';
    }

    return null;
  }

  bool validateAll() {
    return validateTitle(titleController.text) == null &&
        validateBeneficiary() == null &&
        validateAppointmentDateTime() == null;
  }

  // ========= Builders =========

  AppointmentReminderModel buildReminderModel() {
    final beneficiary = selectedBeneficiary.value;
    if (beneficiary == null) {
      throw StateError('Beneficiary is required before building appointment reminder.');
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      throw StateError('Appointment title is required before building reminder.');
    }

    final appointmentDateTime = combinedAppointmentDateTime;
    if (!appointmentDateTime.isAfter(DateTime.now())) {
      throw StateError('Appointment datetime must be in the future.');
    }

    final reminder = AppointmentReminderModel()
      ..title = title
      ..notes = notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim()
      ..location = locationController.text.trim().isEmpty
          ? null
          : locationController.text.trim()
      ..owner = ReminderOwnerEmbedded.fromBeneficiary(beneficiary)
      ..appointmentDateTime = appointmentDateTime
      ..remindBeforeMinutes = remindBeforeMinutes.value
      ..notificationId = null
      ..status = 'active'
      ..saveToHealthRecord = saveToHealthRecord.value
      ..createdAt = DateTime.now();

    return reminder;
  }

  // ========= Prefill =========

  void prefill({
    required String title,
    String? notes,
    String? location,
    BeneficiaryModel? beneficiary,
    DateTime? dateTime,
    int? remindBefore,
  }) {
    titleController.text = title;
    notesController.text = notes ?? '';
    locationController.text = location ?? '';

    if (beneficiary != null) {
      selectedBeneficiary.value = beneficiary;
    }

    if (dateTime != null) {
      appointmentDate.value = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );
      appointmentTime.value = TimeOfDay(
        hour: dateTime.hour,
        minute: dateTime.minute,
      );
    }

    if (remindBefore != null && reminderOptions.contains(remindBefore)) {
      remindBeforeMinutes.value = remindBefore;
    }
  }

  // ========= Save =========

  Future<bool> saveReminder() async {
    if (!validateAll()) return false;

    try {
      isSaving.value = true;

      final reminder = buildReminderModel();
      await remindersController.addAppointmentReminder(reminder);

      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في حفظ تذكير الموعد',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ========= Reset =========

  void resetForm() {
    titleController.clear();
    notesController.clear();
    locationController.clear();

    selectedBeneficiary.value = null;
    appointmentDate.value = DateTime.now();
    appointmentTime.value = TimeOfDay.now();
    remindBeforeMinutes.value = 30;
    saveToHealthRecord.value = false;
    isSaving.value = false;
  }
}