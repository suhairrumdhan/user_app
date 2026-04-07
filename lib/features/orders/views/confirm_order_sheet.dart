import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';

class ConfirmOrderSheet extends StatefulWidget {
  final PharmacyModel pharmacy;
  final BeneficiaryModel beneficiary;
  final List<MedicineModel> medicines;
  final bool useInsurance;
  final OrderRequestSource requestSource;
  final Map<String, dynamic>? metadata;
  final String? prescriptionId;
  final String? prescriptionImageUrl;
  final String? prescriptionText;

  const ConfirmOrderSheet({
    super.key,
    required this.pharmacy,
    required this.beneficiary,
    required this.medicines,
    required this.useInsurance,
    required this.requestSource,
    this.metadata,
    this.prescriptionId,
    this.prescriptionImageUrl,
    this.prescriptionText,
  });

  @override
  State<ConfirmOrderSheet> createState() => _ConfirmOrderSheetState();
}

class _ConfirmOrderSheetState extends State<ConfirmOrderSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  late final List<_SelectableMedicineItem> _availableMedicines;
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _availableMedicines = _buildAvailableMedicines();
  }

  List<_SelectableMedicineItem> _buildAvailableMedicines() {
    final matchedRequestedNames = widget.pharmacy.matchedMedicines
        .map((e) => e.requestedName.trim().toLowerCase())
        .toSet();

    return widget.medicines
        .where(
          (medicine) => matchedRequestedNames.contains(
        medicine.displayName.trim().toLowerCase(),
      ),
    )
        .map(
          (medicine) => _SelectableMedicineItem(
        medicine: medicine,
        isSelected: true,
      ),
    )
        .toList();
  }

  List<MedicineModel> get _selectedMedicines => _availableMedicines
      .where((item) => item.isSelected)
      .map((item) => item.medicine)
      .toList();

  bool get _hasSelectedMedicines => _selectedMedicines.isNotEmpty;


  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    if (!_hasSelectedMedicines) {
      Get.snackbar(
        'تنبيه',
        'اختر دواءً واحدًا على الأقل لإرسال الطلب',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    try {
      final order = await OrderService.instance.createOrder(
        pharmacy: widget.pharmacy,
        beneficiary: widget.beneficiary,
        medicines: _selectedMedicines,
        useInsurance: widget.useInsurance,
        requestSource: widget.requestSource,
        userNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        prescriptionId: widget.prescriptionId,
        prescriptionImageUrl: widget.prescriptionImageUrl,
        prescriptionText: widget.prescriptionText,
        metadata: {
          ...?widget.metadata,
          'sourceLabel': widget.requestSource.label,
          'createdFromSheet': true,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(order);

      Get.snackbar(
        'تم بنجاح',
        'تم إرسال الطلب إلى الصيدلية',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      if (!mounted) return;

      Get.snackbar(
        'خطأ',
        'فشل في إرسال الطلب',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String get _requestSourceLabel {
    return widget.requestSource == OrderRequestSource.manual
        ? 'بحث يدوي'
        : 'وصفة طبية';
  }

  String get _insuranceLabel {
    return widget.useInsurance ? 'مع التأمين' : 'بدون تأمين';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تأكيد الطلب',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: SearchUiColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionCard(
                        child: Column(
                          children: [
                            _sectionHeader(
                              icon: Iconsax.hospital,
                              title: 'الصيدلية المختارة',
                            ),
                            const SizedBox(height: 14),
                            _infoRow(
                              title: 'الاسم',
                              value: widget.pharmacy.displayName,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'العنوان',
                              value: widget.pharmacy.displayAddress,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'الحالة',
                              value: widget.pharmacy.statusLabel,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'السعر التقديري',
                              value: widget.pharmacy.displayPrice,
                            ),
                            if (widget.pharmacy.distanceKm > 0) ...[
                              const SizedBox(height: 10),
                              _infoRow(
                                title: 'المسافة',
                                value: widget.pharmacy.displayDistance,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          children: [
                            _sectionHeader(
                              icon: widget.beneficiary.isSelf
                                  ? Iconsax.profile_circle
                                  : Iconsax.people,
                              title: 'المستفيد',
                            ),
                            const SizedBox(height: 14),
                            _infoRow(
                              title: 'الاسم',
                              value: widget.beneficiary.name,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'الصفة',
                              value: (widget.beneficiary.relation?.trim().isNotEmpty ==
                                  true)
                                  ? widget.beneficiary.relation!.trim()
                                  : (widget.beneficiary.isSelf
                                  ? 'أنا'
                                  : 'فرد من العائلة'),
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'نوع الطلب',
                              value: _requestSourceLabel,
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              title: 'التأمين',
                              value: _insuranceLabel,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                              icon: Iconsax.box,
                              title: 'الأدوية المتوفرة للطلب',
                              trailing: _countBadge(_selectedMedicines.length),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'تم عرض الأدوية المتوفرة فقط، ويمكنك إلغاء أي دواء لا تريدينه.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_availableMedicines.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.18),
                                  ),
                                ),
                                child: const Text(
                                  'لا توجد أدوية متوفرة في هذه الصيدلية لإرسالها في الطلب.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              ...List.generate(_availableMedicines.length, (index) {
                                final item = _availableMedicines[index];

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == _availableMedicines.length - 1 ? 0 : 10,
                                  ),
                                  child: _selectableMedicineTile(
                                    index: index + 1,
                                    item: item,
                                    onChanged: (value) {
                                      setState(() {
                                        item.isSelected = value ?? false;
                                      });
                                    },
                                  ),
                                );
                              }),
                            if (widget.pharmacy.missingMedicines.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.12),
                                  ),
                                ),
                                child: Text(
                                  'أدوية غير متوفرة: ${widget.pharmacy.missingMedicines.join('، ')}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                              icon: Iconsax.note_1,
                              title: 'ملاحظة إضافية',
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _noteController,
                              maxLines: 4,
                              minLines: 3,
                              decoration: InputDecoration(
                                hintText:
                                'أضيفي أي ملاحظة تريدين إيصالها للصيدلية',
                                filled: true,
                                fillColor: SearchUiColors.light,
                                contentPadding: const EdgeInsets.all(14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: SearchUiColors.primary.withOpacity(0.10),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: SearchUiColors.primary.withOpacity(0.10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: SearchUiColors.primary,
                                    width: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SearchUiColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: SearchUiColors.primary.withOpacity(0.08),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Iconsax.info_circle,
                              color: SearchUiColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'بعد تأكيد الطلب سيتم إرساله إلى الصيدلية للمراجعة، ويمكن استخدام الدردشة لاحقًا للاستفسارات فقط.',
                                style: TextStyle(
                                  height: 1.5,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: SearchUiColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isSubmitting || !_hasSelectedMedicines) ? null : _submitOrder, icon: _isSubmitting
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Iconsax.tick_circle),
                      label: Text(
                        _isSubmitting ? 'جاري الإرسال...' : 'تأكيد إرسال الطلب',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SearchUiColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SearchUiColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: SearchUiColors.primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: SearchUiColors.primary,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: SearchUiColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: const TextStyle(
              color: SearchUiColors.darkText,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectableMedicineTile({
    required int index,
    required _SelectableMedicineItem item,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isSelected
            ? SearchUiColors.light
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected
              ? SearchUiColors.primary.withOpacity(0.14)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  SearchUiColors.primary,
                  SearchUiColors.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.medicine.displayName,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: item.isSelected
                    ? SearchUiColors.darkText
                    : Colors.grey.shade500,
              ),
            ),
          ),
          Checkbox(
            value: item.isSelected,
            onChanged: _isSubmitting ? null : onChanged,
            activeColor: SearchUiColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
  Widget _medicineTile({
    required int index,
    required String name,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  SearchUiColors.primary,
                  SearchUiColors.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: SearchUiColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableMedicineItem {
  final MedicineModel medicine;
  bool isSelected;

  _SelectableMedicineItem({
    required this.medicine,
    this.isSelected = true,
  });
}