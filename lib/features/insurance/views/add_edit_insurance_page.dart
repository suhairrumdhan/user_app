import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../family/controllers/family_controller.dart';
import '../../family/models/family_member_model.dart';
import '../controllers/insurance_controller.dart';
import '../models/insurance_model.dart';

class AddEditInsurancePage extends StatefulWidget {
  final String? insuranceId;

  const AddEditInsurancePage({super.key, this.insuranceId});

  @override
  State<AddEditInsurancePage> createState() => _AddEditInsurancePageState();
}

class _AddEditInsurancePageState extends State<AddEditInsurancePage> {
  late final InsuranceController controller;
  late final FamilyController familyController;

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF8F9FA);
  final Color pAccentColor = const Color(0xFF4CAF50);

  final _formKey = GlobalKey<FormState>();

  final companyNameController = TextEditingController();
  final cardNumberController = TextEditingController();
  final companyCodeController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  bool loading = false;
  bool initialLoading = true;
  bool beneficiaryLocked = false;

  /// لكل مستفيد وثيقة واحدة ورقم وثيقة مستقل.
  String selectedBeneficiaryId = 'self';

  @override
  void initState() {
    super.initState();

    controller = Get.isRegistered<InsuranceController>()
        ? Get.find<InsuranceController>()
        : Get.put(InsuranceController());

    familyController = Get.isRegistered<FamilyController>()
        ? Get.find<FamilyController>()
        : Get.put(FamilyController());

    loadData();
  }

  Future<void> loadData() async {
    if (widget.insuranceId == null) {
      initialLoading = false;
      setState(() {});
      return;
    }

    final insurance = await controller.getInsurance(widget.insuranceId!);

    if (insurance != null) {
      companyCodeController.text = insurance.companyCode;
      companyNameController.text = insurance.companyName;
      cardNumberController.text = insurance.cardNumber;
      startDate = insurance.startDate;
      endDate = insurance.endDate;
      selectedBeneficiaryId = insurance.beneficiaryId.isNotEmpty
          ? insurance.beneficiaryId
          : 'self';
      beneficiaryLocked = insurance.beneficiaryId.isNotEmpty;
    }

    initialLoading = false;
    setState(() {});
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    companyNameController.dispose();
    cardNumberController.dispose();
    super.dispose();
  }

  Future<void> pickDate({required bool isStart}) async {
    final initialDate = (isStart ? startDate : endDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: pPrimaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null) {
      _showError('يرجى اختيار تاريخ بداية التغطية');
      return;
    }

    if (endDate == null) {
      _showError('يرجى اختيار تاريخ نهاية التغطية');
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      _showError('تاريخ نهاية التغطية يجب أن يكون بعد البداية');
      return;
    }

    setState(() => loading = true);

    try {
      final selectedMember = familyController.members.firstWhereOrNull(
        (member) => member.id == selectedBeneficiaryId,
      );
      final insurance = InsuranceModel(
        id: widget.insuranceId ?? '',
        companyCode: companyCodeController.text.trim().toUpperCase(),
        companyName: companyNameController.text.trim(),
        cardNumber: cardNumberController.text.trim(),
        beneficiaryId: selectedBeneficiaryId,
        beneficiaryType: selectedBeneficiaryId == 'self' ? 'self' : 'family',
        beneficiaryName: selectedBeneficiaryId == 'self'
            ? 'صاحب الحساب'
            : (selectedMember?.name ?? ''),
        startDate: startDate,
        endDate: endDate,
        coveredMemberIds: <String>[selectedBeneficiaryId],
      );

      if (widget.insuranceId == null) {
        await controller.addInsurance(insurance);
      } else {
        await controller.updateInsurance(insurance);
      }

      if (mounted) {
        setState(() => loading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('حدث خطأ أثناء الحفظ');
        setState(() => loading = false);
      }
    }
  }

  void _selectBeneficiary(String id) {
    setState(() => selectedBeneficiaryId = id);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'اختر التاريخ';
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (initialLoading) {
      return Scaffold(
        backgroundColor: pPrimaryColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.insuranceId == null
                        ? "إضافة شركة تأمين"
                        : "تعديل شركة التأمين",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: companyNameController,
                              label: "اسم شركة التأمين",
                              icon: Iconsax.building_4,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? "مطلوب"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: companyCodeController,
                              label: "كود شركة التأمين",
                              icon: Iconsax.code,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? "مطلوب"
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: cardNumberController,
                              label: "رقم وثيقة التأمين للمستفيد",
                              icon: Iconsax.card,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? "مطلوب"
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildDateField(
                              label: "بداية التغطية",
                              icon: Iconsax.calendar_1,
                              value: _formatDate(startDate),
                              onTap: () => pickDate(isStart: true),
                            ),
                            const SizedBox(height: 16),

                            _buildDateField(
                              label: "نهاية التغطية",
                              icon: Iconsax.calendar_remove,
                              value: _formatDate(endDate),
                              onTap: () => pickDate(isStart: false),
                            ),
                            const SizedBox(height: 20),

                            _buildCoveredMembersSection(),
                            const SizedBox(height: 24),

                            _buildSaveButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildCoveredMembersSection() {
    final familyMembers = familyController.members;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pPrimaryColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.profile_2user, color: pPrimaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                "صاحب وثيقة التأمين",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildMemberChip(
            id: 'self',
            label: 'أنا',
            isSelected: selectedBeneficiaryId == 'self',
          ),

          if (familyMembers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: familyMembers.map((FamilyMemberModel member) {
                final id = member.id;
                final selected = selectedBeneficiaryId == id;
                return _buildMemberChip(
                  id: id,
                  label: member.name,
                  isSelected: selected,
                  subLabel: member.relation,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberChip({
    required String id,
    required String label,
    required bool isSelected,
    String? subLabel,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: beneficiaryLocked ? null : () => _selectBeneficiary(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? pPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? pPrimaryColor : pPrimaryColor.withOpacity(0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Iconsax.tick_circle : Iconsax.add_circle,
              size: 18,
              color: isSelected ? Colors.white : pPrimaryColor,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subLabel != null && subLabel.isNotEmpty)
                  Text(
                    subLabel,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
              ],
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
        prefixIcon: Icon(icon, color: pPrimaryColor, size: 20),
        filled: true,
        fillColor: pLightColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pPrimaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: pLightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: pPrimaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF7F8C8D),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: value == 'اختر التاريخ'
                          ? Colors.grey
                          : const Color(0xFF2C3E50),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_down_1, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: pPrimaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : save,
        style: ElevatedButton.styleFrom(
          backgroundColor: pPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "حفظ",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
