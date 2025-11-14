// widgets/health_record/basic_info_card.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/health_record_controller.dart';

class BasicInfoCard extends StatelessWidget {
  final dynamic user;
  final HealthRecordController controller;

  BasicInfoCard({super.key, required this.user, required this.controller});

  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> genders = ['ذكر', 'أنثى'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInfoRows(),
          const SizedBox(height: 8),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1877F2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF1877F2),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'المعلومات الأساسية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRows() {
    return Column(
      children: [
        _buildInfoRow('فصيلة الدم', user.bloodType ?? 'غير محدد'),
        const SizedBox(height: 12),
        _buildInfoRow('الجنس', user.gender ?? 'غير محدد'),
        const SizedBox(height: 12),
        _buildInfoRow(
            'تاريخ الميلاد',
            user.dateOfBirth != null
                ? '${user.dateOfBirth!.year}-${user.dateOfBirth!.month}-${user.dateOfBirth!.day}'
                : 'غير محدد'
        ),
        const SizedBox(height: 12),
        _buildInfoRow('رقم الهاتف', user.phone ?? 'غير محدد'),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return Container(
      width: double.infinity,
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: _showEditDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1877F2),
          side: const BorderSide(color: Color(0xFF1877F2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'تعديل المعلومات الأساسية',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    String? selectedBloodType = user.bloodType;
    String? selectedGender = user.gender;

    // إذا كانت القيمة غير موجودة في القائمة، نضعها null
    if (selectedBloodType != null && !bloodTypes.contains(selectedBloodType)) {
      selectedBloodType = null;
    }
    if (selectedGender != null && !genders.contains(selectedGender)) {
      selectedGender = null;
    }

    final phoneController = TextEditingController(text: user.phone ?? '');
    final dateController = TextEditingController(
        text: user.dateOfBirth != null
            ? "${user.dateOfBirth!.year}-${user.dateOfBirth!.month}-${user.dateOfBirth!.day}"
            : ''
    );

    DateTime? selectedDate = user.dateOfBirth;

    final BuildContext dialogContext = Get.context!;

    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'تعديل المعلومات الأساسية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. قائمة منسدلة لفصائل الدم - اختيارية
                DropdownButtonFormField<String>(
                  value: selectedBloodType,
                  decoration: const InputDecoration(
                    labelText: 'فصيلة الدم (اختياري)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('غير محدد'),
                    ),
                    ...bloodTypes.map((String bloodType) {
                      return DropdownMenuItem<String>(
                        value: bloodType,
                        child: Text(bloodType),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    selectedBloodType = newValue;
                  },
                ),
                const SizedBox(height: 16),

                // 2. قائمة منسدلة للجنس - اختيارية
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'الجنس (اختياري)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('غير محدد'),
                    ),
                    ...genders.map((String gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    selectedGender = newValue;
                  },
                ),
                const SizedBox(height: 16),

                // 3. رقم الهاتف - اختياري
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // 4. تاريخ الميلاد - اختياري
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      selectedDate = pickedDate;
                      dateController.text = "${pickedDate.year}-${pickedDate.month}-${pickedDate.day}";
                    } else {
                      // إذا المستخدم ما اختار تاريخ، نحطه null
                      selectedDate = null;
                      dateController.text = '';
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الميلاد (اختياري)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  print('💾 بدء حفظ البيانات...');

                  final bloodType = selectedBloodType;
                  final gender = selectedGender;
                  final phone = phoneController.text.isEmpty ? null : phoneController.text;
                  final dateOfBirth = selectedDate;

                  // حفظ البيانات
                  await controller.updateAdditionalHealthInfo(
                    bloodType: bloodType,
                    gender: gender,
                    phone: phone,
                    dateOfBirth: dateOfBirth,
                  );

                  print('✅ تم الحفظ بنجاح');

                  // إغلاق أي ديالوج مفتوح (مهما كان نوعه)
                  if (Navigator.canPop(Get.context!)) {
                    Navigator.of(Get.context!).pop(); // يسكر الديالوج حتى لو فتح بـ showDialog
                  }

                  // تحديث الواجهة
                  Get.forceAppUpdate();

                  // إظهار إشعار النجاح
                  Get.snackbar(
                    'تم الحفظ',
                    'تم حفظ المعلومات بنجاح ✅',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );

                } catch (e) {
                  print('❌ خطأ في الحفظ: $e');
                  Get.snackbar(
                    'خطأ',
                    'فشل في حفظ البيانات: $e',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
              ),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}