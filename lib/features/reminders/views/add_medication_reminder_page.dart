import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../health_records/controllers/health_record_controller.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/add_medication_reminder_controller.dart';
import '../data/models/medication_reminder_model.dart';
import '../widgets/time_chip.dart';
import '../../previous_medications/services/previous_medications_service.dart';

class AddMedicationReminderPage extends StatefulWidget {
  const AddMedicationReminderPage({super.key, this.reminder});

  final MedicationReminderModel? reminder;

  @override
  State<AddMedicationReminderPage> createState() =>
      _AddMedicationReminderPageState();
}

class _AddMedicationReminderPageState extends State<AddMedicationReminderPage> {
  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);

  late final AddMedicationReminderController controller;
  late final FamilyController familyController;
  late final UserController userController;
  late final AuthController authController;
  late final HealthRecordController healthRecordController;

  final _formKey = GlobalKey<FormState>();
  bool _saveInProgress = false;
  final PreviousMedicationsService previousMedicationsService =
      PreviousMedicationsService();
  @override
  void initState() {
    super.initState();
    controller = Get.put(
      AddMedicationReminderController(existingReminder: widget.reminder),
    );
    familyController = Get.isRegistered<FamilyController>()
        ? Get.find<FamilyController>()
        : Get.put(FamilyController());
    userController = Get.find<UserController>();
    authController = Get.find<AuthController>();
    healthRecordController = Get.isRegistered<HealthRecordController>()
        ? Get.find<HealthRecordController>()
        : Get.put(HealthRecordController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<AddMedicationReminderController>()) {
      Get.delete<AddMedicationReminderController>();
    }
    super.dispose();
  }

  List<BeneficiaryModel> _buildBeneficiaries() {
    final user = userController.user.value;
    final list = <BeneficiaryModel>[];

    if (user != null) {
      list.add(
        BeneficiaryModel(
          id: user.id,
          name: user.name,
          type: 'self',
          relation: 'أنا',
        ),
      );
    } else if (authController.currentUserId != null) {
      list.add(
        BeneficiaryModel(
          id: authController.currentUserId!,
          name: 'أنا',
          type: 'self',
          relation: 'أنا',
        ),
      );
    }

    for (final member in familyController.members) {
      list.add(
        BeneficiaryModel(
          id: member.id,
          name: member.name,
          type: 'family',
          relation: member.relation ?? 'فرد من العائلة',
        ),
      );
    }

    return list;
  }

  Future<void> _pickBeneficiary() async {
    final beneficiaries = _buildBeneficiaries();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Iconsax.profile_2user, color: rPrimaryColor),
                    SizedBox(width: 8),
                    Text(
                      'لمن هذا التذكير؟',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: rPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...beneficiaries.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        controller.setBeneficiary(item);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: rLightColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: rPrimaryColor.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: rPrimaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.isSelf
                                    ? Iconsax.profile_circle
                                    : Iconsax.people,
                                color: rPrimaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Iconsax.arrow_left_2,
                              color: rPrimaryColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (_, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: rPrimaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.addTime(picked);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart
        ? controller.startDate.value
        : (controller.endDate.value ?? controller.startDate.value);

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      builder: (_, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: rPrimaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isStart) {
        controller.setStartDate(picked);
      } else {
        controller.setEndDate(picked);
      }
    }
  }

  Future<void> _syncMedicationToHealthRecord({
    int? linkedReminderLocalId,
  }) async {
    if (!controller.saveToHealthRecord.value) return;

    final beneficiary = controller.selectedBeneficiary.value;
    final medicineName = controller.medicineNameController.text.trim();

    if (beneficiary == null || medicineName.isEmpty) return;

    if (beneficiary.isSelf) {
      final user = userController.user.value;
      if (user == null) return;

      final meds = [...user.currentMedications];
      if (!meds.contains(medicineName)) meds.add(medicineName);

      await healthRecordController.updateUserHealthRecords(
        currentMedications: meds,
      );
    } else {
      final member = familyController.members.firstWhereOrNull(
        (e) => e.id == beneficiary.id,
      );
      if (member == null) return;

      final meds = [...member.currentMedications];
      if (!meds.contains(medicineName)) meds.add(medicineName);

      await healthRecordController.updateFamilyMemberHealthRecords(
        memberId: member.id,
        currentMedications: meds,
      );
    }

    await previousMedicationsService.addFromMedicationReminder(
      ownerBeneficiaryId: beneficiary.id,
      ownerName: beneficiary.name,
      ownerType: beneficiary.type,
      ownerRelation: beneficiary.relation,
      medicineName: medicineName,
      dosage: controller.dosageController.text.trim(),
      route: controller.routeController.text.trim(),
      notes: controller.notesController.text.trim(),
      treatmentStartDate: controller.startDate.value,
      treatmentEndDate: controller.endDate.value,
      linkedReminderLocalId: linkedReminderLocalId,
    );
  }

  Future<void> _save() async {
    if (_saveInProgress) return;
    setState(() => _saveInProgress = true);

    try {
      final beneficiaryError = controller.validateBeneficiary();
      final timesError = controller.validateTimes();
      final rangeError = controller.validateDateRange();

      if (!_formKey.currentState!.validate()) return;

      if (beneficiaryError != null) {
        _showError(beneficiaryError);
        return;
      }

      if (timesError != null) {
        _showError(timesError);
        return;
      }

      if (rangeError != null) {
        _showError(rangeError);
        return;
      }

      final reminder = await controller.saveReminder();
      if (reminder == null) return;

      if (!controller.isEditing) {
        await _syncMedicationToHealthRecord(linkedReminderLocalId: reminder.id);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final wasEditing = controller.isEditing;
      Navigator.of(context).pop(true);
      if (!wasEditing) {
        messenger.showSnackBar(
          const SnackBar(content: Text('تم إنشاء تذكير الدواء بنجاح')),
        );
      }
    } finally {
      if (mounted) setState(() => _saveInProgress = false);
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'تنبيه',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: rPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.isEditing
                          ? 'تعديل تذكير الدواء'
                          : 'إضافة تذكير دواء',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [rPrimaryColor, rSecondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: rPrimaryColor.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white24,
                              child: Icon(Iconsax.book, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'أدخل بيانات الدواء وحدد الأوقات المناسبة ليذكرك التطبيق تلقائيًا.',
                                style: TextStyle(
                                  color: Colors.white,
                                  height: 1.6,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildTextField(
                        controller: controller.medicineNameController,
                        label: 'اسم الدواء',
                        icon: Iconsax.book,
                        validator: controller.validateMedicineName,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: controller.dosageController,
                        label: 'الجرعة',
                        icon: Iconsax.archive_1,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: controller.routeController,
                        label: 'طريقة الاستخدام',
                        icon: Iconsax.health,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: controller.notesController,
                        label: 'ملاحظات',
                        icon: Iconsax.note_1,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        final beneficiary =
                            controller.selectedBeneficiary.value;
                        return _buildPickerCard(
                          icon: Iconsax.profile_2user,
                          label: 'المستفيد',
                          value: beneficiary == null
                              ? 'اختر المستفيد'
                              : beneficiary.name,
                          onTap: _pickBeneficiary,
                        );
                      }),
                      const SizedBox(height: 14),
                      Obx(() {
                        return _buildPickerCard(
                          icon: Iconsax.calendar_1,
                          label: 'تاريخ البداية',
                          value: _formatDate(controller.startDate.value),
                          onTap: () => _pickDate(isStart: true),
                        );
                      }),
                      const SizedBox(height: 14),
                      Obx(() {
                        return _buildPickerCard(
                          icon: Iconsax.calendar_remove,
                          label: 'تاريخ النهاية',
                          value: controller.endDate.value == null
                              ? 'اختياري'
                              : _formatDate(controller.endDate.value),
                          onTap: () => _pickDate(isStart: false),
                        );
                      }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: rLightColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: rPrimaryColor.withOpacity(0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Iconsax.clock, color: rPrimaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'أوقات التذكير',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rTextDarkColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Obx(() {
                              if (controller.times.isEmpty) {
                                return Text(
                                  'لم تتم إضافة أي أوقات بعد',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12.5,
                                  ),
                                );
                              }

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: controller.times.map((time) {
                                  return TimeChip(
                                    time: time,
                                    onDelete: () => controller.removeTime(time),
                                  );
                                }).toList(),
                              );
                            }),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Iconsax.add, size: 18),
                                label: const Text('إضافة وقت'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: rPrimaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(() {
                        return SwitchListTile(
                          value: controller.saveToHealthRecord.value,
                          onChanged: controller.toggleSaveToHealthRecord,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          activeColor: rPrimaryColor,
                          title: const Text(
                            'إضافته إلى السجل الصحي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rTextDarkColor,
                            ),
                          ),
                          subtitle: const Text(
                            'عند الحفظ سيتم إضافة اسم الدواء إلى الأدوية الحالية لهذا المستفيد',
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      Obx(() {
                        final isSaving = controller.isSaving.value;
                        final saveDisabled = _saveInProgress || isSaving;
                        return SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: saveDisabled ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: rPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: saveDisabled
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    controller.isEditing
                                        ? 'حفظ التعديلات'
                                        : 'حفظ التذكير',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: rPrimaryColor),
        filled: true,
        fillColor: rLightColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: rPrimaryColor.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rPrimaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rLightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rPrimaryColor.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Icon(icon, color: rPrimaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: rTextDarkColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_down_1, color: Colors.black45, size: 18),
          ],
        ),
      ),
    );
  }
}
