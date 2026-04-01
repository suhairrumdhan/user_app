import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../controllers/family_controller.dart';
import '../models/family_member_model.dart';

class AddEditFamilyMemberPage extends StatefulWidget {
  final String? memberId;

  const AddEditFamilyMemberPage({super.key, this.memberId});

  @override
  State<AddEditFamilyMemberPage> createState() =>
      _AddEditFamilyMemberPageState();
}

class _AddEditFamilyMemberPageState extends State<AddEditFamilyMemberPage> {
  final controller = Get.find<FamilyController>();
  final Color pPrimaryColor = const Color(0xFF5EABD6);

  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();

  String? relation;
  String? gender;
  DateTime? dateOfBirth;

  bool loading = false;
  bool initialLoading = true;

  final relations = ["أب", "أم", "أخ", "أخت", "ابن", "ابنة", "زوج", "زوجة", "جد", "جدة", "آخر"];
  final genders = ["ذكر", "أنثى"];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (widget.memberId == null) {
      initialLoading = false;
      setState(() {});
      return;
    }

    final member = await controller.getMember(widget.memberId!);

    if (member != null) {
      name.text = member.name;
      relation = member.relation;
      gender = member.gender;
      dateOfBirth = member.dateOfBirth;
    }

    initialLoading = false;
    setState(() {});
  }

  int getAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
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
      setState(() => dateOfBirth = picked);
    }
  }

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    if (relation == null) {
      _showError('يرجى اختيار صلة القرابة');
      return;
    }

    if (gender == null) {
      _showError('يرجى اختيار الجنس');
      return;
    }

    setState(() => loading = true);

    try {
      final member = FamilyMemberModel(
        id: widget.memberId,
        name: name.text.trim(),
        relation: relation,
        gender: gender,
        dateOfBirth: dateOfBirth,
        age: dateOfBirth != null ? getAge(dateOfBirth!) : null,
      );

      if (widget.memberId == null) {
        await controller.addMember(member);
      } else {
        await controller.updateMember(member);
      }

      // Reset loading state before navigation
      if (mounted) {
        setState(() => loading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('حدث خطأ أثناء الحفظ: ${e.toString()}');
        setState(() => loading = false);
      }
    }
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
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.memberId == null ? "إضافة فرد" : "تعديل الفرد",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // المحتوى مع البوكس الأبيض
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

                      // بطاقة المعلومات
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
                            // الاسم
                            _buildTextField(
                              controller: name,
                              label: "الاسم الكامل",
                              icon: Iconsax.user,
                              validator: (v) => v!.isEmpty ? "مطلوب" : null,
                            ),
                            const SizedBox(height: 16),

                            // صلة القرابة
                            _buildDropdownField(
                              value: relation,
                              label: "صلة القرابة",
                              icon: Iconsax.heart,
                              items: relations,
                              onChanged: (v) => setState(() => relation = v),
                            ),
                            const SizedBox(height: 16),

                            // الجنس
                            _buildDropdownField(
                              value: gender,
                              label: "الجنس",
                              icon: Iconsax.user_tag,
                              items: genders,
                              onChanged: (v) => setState(() => gender = v),
                            ),
                            const SizedBox(height: 16),

                            // تاريخ الميلاد
                            _buildDateField(
                              dateOfBirth: dateOfBirth,
                              onTap: pickDate,
                            ),
                            const SizedBox(height: 24),

                            // زر الحفظ
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? hintText,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
        labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
        prefixIcon: Icon(icon, color: pPrimaryColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: DropdownButtonFormField(
        value: value,
        items: items.map((e) {
          return DropdownMenuItem(value: e, child: Text(e));
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
          prefixIcon: Icon(icon, color: pPrimaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? dateOfBirth,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Iconsax.calendar, color: pPrimaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "تاريخ الميلاد",
                    style: TextStyle(
                      color: Color(0xFF7F8C8D),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    dateOfBirth == null
                        ? "اختر التاريخ"
                        : "${dateOfBirth.year}/${dateOfBirth.month}/${dateOfBirth.day}",
                    style: TextStyle(
                      color: dateOfBirth == null ? Colors.grey : const Color(0xFF2C3E50),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}