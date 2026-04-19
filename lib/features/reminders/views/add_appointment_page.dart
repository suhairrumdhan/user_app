import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/add_appointment_controller.dart';

class AddAppointmentPage extends StatefulWidget {
  const AddAppointmentPage({super.key});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);

  late final AddAppointmentController controller;
  late final FamilyController familyController;
  late final UserController userController;
  late final AuthController authController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = Get.put(AddAppointmentController());
    familyController = Get.isRegistered<FamilyController>()
        ? Get.find<FamilyController>()
        : Get.put(FamilyController());
    userController = Get.find<UserController>();
    authController = Get.find<AuthController>();
  }

  @override
  void dispose() {
    if (Get.isRegistered<AddAppointmentController>()) {
      Get.delete<AddAppointmentController>();
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
                                  const SizedBox(height: 2),
                                  Text(
                                    item.relation,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.appointmentDate.value,
      firstDate: DateTime.now(),
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
      controller.setAppointmentDate(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.appointmentTime.value,
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
      controller.setAppointmentTime(picked);
    }
  }

  Future<void> _save() async {
    final beneficiaryError = controller.validateBeneficiary();
    final dateError = controller.validateAppointmentDateTime();

    if (!_formKey.currentState!.validate()) return;

    if (beneficiaryError != null) {
      _showError(beneficiaryError);
      return;
    }

    if (dateError != null) {
      _showError(dateError);
      return;
    }

    final success = await controller.saveReminder();
    if (!success) return;

    if (!mounted) return;
    Get.back();
    Get.snackbar(
      'تم الحفظ',
      'تم إنشاء تذكير الموعد بنجاح',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
    );
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

  String _formatDate(DateTime value) {
    return '${value.year}/${value.month}/${value.day}';
  }

  String _formatTime(TimeOfDay value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: rPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'إضافة تذكير موعد',
                      style: TextStyle(
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
                              child: Icon(
                                Iconsax.calendar_1,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'حدد بيانات الموعد ووقت التذكير المناسب قبل الموعد.',
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
                        controller: controller.titleController,
                        label: 'عنوان الموعد',
                        icon: Iconsax.calendar_1,
                        validator: controller.validateTitle,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: controller.locationController,
                        label: 'المكان',
                        icon: Iconsax.location,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: controller.notesController,
                        label: 'ملاحظات',
                        icon: Iconsax.note_1,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Obx(() {
                        final beneficiary = controller.selectedBeneficiary.value;
                        return _buildPickerCard(
                          icon: Iconsax.profile_2user,
                          label: 'المستفيد',
                          value: beneficiary == null
                              ? 'اختر المستفيد'
                              : '${beneficiary.name} • ${beneficiary.relation}',
                          onTap: _pickBeneficiary,
                        );
                      }),
                      const SizedBox(height: 14),
                      Obx(() {
                        return _buildPickerCard(
                          icon: Iconsax.calendar_1,
                          label: 'تاريخ الموعد',
                          value: _formatDate(controller.appointmentDate.value),
                          onTap: _pickDate,
                        );
                      }),
                      const SizedBox(height: 14),
                      Obx(() {
                        return _buildPickerCard(
                          icon: Iconsax.clock,
                          label: 'وقت الموعد',
                          value: _formatTime(controller.appointmentTime.value),
                          onTap: _pickTime,
                        );
                      }),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: rLightColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: rPrimaryColor.withOpacity(0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Iconsax.notification_bing,
                                    color: rPrimaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'التذكير قبل الموعد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: rTextDarkColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Obx(() {
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AddAppointmentController
                                    .reminderOptions
                                    .map((minutes) {
                                  final isSelected =
                                      controller.remindBeforeMinutes.value ==
                                          minutes;
                                  return ChoiceChip(
                                    label: Text(
                                      _remindLabel(minutes),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : rTextDarkColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (_) =>
                                        controller.setRemindBeforeMinutes(
                                            minutes),
                                    selectedColor: rPrimaryColor,
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: rPrimaryColor.withOpacity(0.14),
                                    ),
                                  );
                                }).toList(),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Obx(() {
                        return SwitchListTile(
                          value: controller.saveToHealthRecord.value,
                          onChanged: controller.toggleSaveToHealthRecord,
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                          activeColor: rPrimaryColor,
                          title: const Text(
                            'ربطه كسجل صحي مهم',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rTextDarkColor,
                            ),
                          ),
                          subtitle: const Text(
                            'سيتم تمييز هذا الموعد داخل نظام التذكيرات الصحية لاستخدامه لاحقًا',
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      Obx(() {
                        return SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                            controller.isSaving.value ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: rPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: controller.isSaving.value
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'حفظ الموعد',
                              style: TextStyle(
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

  String _remindLabel(int value) {
    if (value == 1440) return 'يوم';
    if (value >= 60) {
      final hours = value ~/ 60;
      return hours == 1 ? 'ساعة' : '$hours ساعات';
    }
    return '$value دقيقة';
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
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12.5,
                    ),
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