import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../notifications/models/app_notification_model.dart';
import '../../search/views/search_ui_colors.dart';
import '../controllers/previous_medications_controller.dart';

class AddPreviousMedicationFromNotificationSheet extends StatefulWidget {
  final AppNotificationModel notification;

  const AddPreviousMedicationFromNotificationSheet({
    super.key,
    required this.notification,
  });

  @override
  State<AddPreviousMedicationFromNotificationSheet> createState() =>
      _AddPreviousMedicationFromNotificationSheetState();
}

class _AddPreviousMedicationFromNotificationSheetState
    extends State<AddPreviousMedicationFromNotificationSheet> {
  final PreviousMedicationsController controller = Get.put(
    PreviousMedicationsController(),
  );

  final TextEditingController _notesController = TextEditingController();

  final RxBool isVisibleToPharmacist = true.obs;
  final RxBool createReminderLater = false.obs;

  DateTime takenAt = DateTime.now();
  DateTime? treatmentStartDate;
  DateTime? treatmentEndDate;
  DateTime? showToPharmacistUntil;

  late final List<Map<String, dynamic>> medicines;
  late final Set<int> selectedIndexes;

  @override
  void initState() {
    super.initState();
    medicines = _extractMedicines(widget.notification);
    selectedIndexes = medicines.isEmpty
        ? <int>{}
        : List<int>.generate(medicines.length, (index) => index).toSet();

    treatmentStartDate = DateTime.now();
    treatmentEndDate = DateTime.now().add(const Duration(days: 7));
    showToPharmacistUntil = treatmentEndDate;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _extractMedicines(AppNotificationModel n) {
    final raw = n.extraData['deliveredMedicines'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _buildBeneficiarySnapshot(AppNotificationModel n) {
    final type = (n.beneficiaryType ?? '').trim().toLowerCase();
    final ownerType = type == 'self' ? 'self' : 'family';

    return {
      'beneficiaryId': (n.beneficiaryId ?? '').trim(),
      'name': (n.beneficiaryName ?? '').trim(),
      'type': ownerType,
      'relationLabel': ownerType == 'self' ? 'أنا' : 'فرد من العائلة',
    };
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ar'),
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SearchUiColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onSelected(DateTime(picked.year, picked.month, picked.day));
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (selectedIndexes.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'اختر دواءً واحدًا على الأقل',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final beneficiaryId = (widget.notification.beneficiaryId ?? '').trim();
    final orderId = (widget.notification.orderId ?? '').trim();

    if (beneficiaryId.isEmpty || orderId.isEmpty) {
      Get.snackbar(
        'خطأ',
        'بيانات الإشعار غير كافية لإضافة الأدوية السابقة',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final selectedMedicines = selectedIndexes.map((i) => medicines[i]).toList();

    final added = await controller.addBatchFromOrder(
      orderId: orderId,
      beneficiarySnapshot: _buildBeneficiarySnapshot(widget.notification),
      medicineItems: selectedMedicines,
      takenAt: takenAt,
      treatmentStartDate: treatmentStartDate,
      treatmentEndDate: treatmentEndDate,
      showToPharmacistFrom: takenAt,
      showToPharmacistUntil: isVisibleToPharmacist.value
          ? showToPharmacistUntil
          : null,
      isVisibleToPharmacist: isVisibleToPharmacist.value,
      pharmacyId: widget.notification.pharmacyId,
      pharmacyName: widget.notification.pharmacyName,
      notificationId: widget.notification.id,
      showSuccessMessage: true,
    );

    if (added.isNotEmpty) {
      Get.back();

      if (createReminderLater.value) {
        Get.snackbar(
          'التذكير',
          'أضف تذكيرًا من صفحة التذكيرات.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  String _medicineName(Map<String, dynamic> item) {
    return (item['matchedMedicineName'] ??
                item['medicineName'] ??
                item['requestedName'] ??
                '')
            .toString()
            .trim()
            .isEmpty
        ? 'دواء'
        : (item['matchedMedicineName'] ??
                  item['medicineName'] ??
                  item['requestedName'])
              .toString()
              .trim();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'إضافة إلى الأدوية السابقة',
                      style: TextStyle(
                        color: SearchUiColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Iconsax.close_circle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'اختر الأدوية لإضافتها إلى السجل الدوائي.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.4,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'الأدوية المستلمة',
                        child: medicines.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'لا توجد أدوية مرفقة داخل هذا الإشعار.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : Column(
                                children: List.generate(medicines.length, (i) {
                                  final item = medicines[i];
                                  final selected = selectedIndexes.contains(i);

                                  return CheckboxListTile(
                                    value: selected,
                                    activeColor: SearchUiColors.primary,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _medicineName(item),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      (item['strength'] ??
                                                  item['dosage'] ??
                                                  item['dosageForm'] ??
                                                  'بدون تفاصيل')
                                              .toString()
                                              .trim()
                                              .isEmpty
                                          ? 'بدون تفاصيل'
                                          : (item['strength'] ??
                                                    item['dosage'] ??
                                                    item['dosageForm'])
                                                .toString()
                                                .trim(),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedIndexes.add(i);
                                        } else {
                                          selectedIndexes.remove(i);
                                        }
                                      });
                                    },
                                  );
                                }),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'إعدادات الفترة',
                        child: Column(
                          children: [
                            _DateTile(
                              label: 'تاريخ الأخذ',
                              value: _formatDate(takenAt),
                              onTap: () => _pickDate(
                                initialDate: takenAt,
                                onSelected: (date) => takenAt = date,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DateTile(
                              label: 'بداية العلاج',
                              value: _formatDate(treatmentStartDate),
                              onTap: () => _pickDate(
                                initialDate:
                                    treatmentStartDate ?? DateTime.now(),
                                onSelected: (date) => treatmentStartDate = date,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DateTile(
                              label: 'نهاية العلاج',
                              value: _formatDate(treatmentEndDate),
                              onTap: () => _pickDate(
                                initialDate: treatmentEndDate ?? DateTime.now(),
                                onSelected: (date) {
                                  treatmentEndDate = date;
                                  showToPharmacistUntil = date;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'الظهور للصيدلي',
                        child: Column(
                          children: [
                            Obx(
                              () => SwitchListTile(
                                value: isVisibleToPharmacist.value,
                                activeColor: SearchUiColors.primary,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'إظهار هذا الدواء للصيدلي مؤقتًا',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: const Text(
                                  'يمكن إيقاف ظهوره لاحقًا مع بقاءه في السجل',
                                ),
                                onChanged: (value) {
                                  isVisibleToPharmacist.value = value;
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () => AnimatedOpacity(
                                opacity: isVisibleToPharmacist.value ? 1 : 0.5,
                                duration: const Duration(milliseconds: 180),
                                child: IgnorePointer(
                                  ignoring: !isVisibleToPharmacist.value,
                                  child: _DateTile(
                                    label: 'يظهر للصيدلي حتى',
                                    value: _formatDate(showToPharmacistUntil),
                                    onTap: () => _pickDate(
                                      initialDate:
                                          showToPharmacistUntil ??
                                          DateTime.now(),
                                      onSelected: (date) =>
                                          showToPharmacistUntil = date,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'خيارات إضافية',
                        child: Column(
                          children: [
                            TextField(
                              controller: _notesController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'ملاحظات اختيارية',
                                filled: true,
                                fillColor: const Color(0xFFF7FAFD),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide(
                                    color: SearchUiColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Obx(
                              () => CheckboxListTile(
                                value: createReminderLater.value,
                                activeColor: SearchUiColors.primary,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'أريد إنشاء تذكير لهذا الدواء لاحقًا',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: const Text(
                                  'سيتم حفظ السجل الآن ثم ربطه بالتذكير لاحقًا',
                                ),
                                onChanged: (value) {
                                  createReminderLater.value = value ?? false;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Obx(
                        () => SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: controller.isProcessing.value
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SearchUiColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: controller.isProcessing.value
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Iconsax.add_circle),
                            label: const Text(
                              'إضافة إلى السجل',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.document_text,
                size: 17,
                color: SearchUiColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Iconsax.calendar_1,
              color: SearchUiColors.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: SearchUiColors.primary,
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
