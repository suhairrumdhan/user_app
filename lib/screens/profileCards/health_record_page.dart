// screens/health_records_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/health_record_controller.dart';
import '../../widgets/health_record/basic_info_card.dart';
import '../../widgets/health_record/health_info_card.dart';

class HealthRecordsPage extends StatelessWidget {
  HealthRecordsPage({super.key});

  final UserController userController = Get.find<UserController>();
  final HealthRecordController healthController = Get.put(HealthRecordController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final user = userController.user.value;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'السجل الصحي',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: user == null
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // المعلومات الأساسية
          BasicInfoCard(
            user: user  ,
            controller: healthController // أضيفي هذا
          ),
          const SizedBox(height: 16),

          // الحالات الصحية
          HealthInfoCard(
            icon: Icons.health_and_safety_outlined,
            title: 'الحالات الصحية',
            items: user.healthConditions ?? [],
            emptyMessage: 'لم يتم تسجيل أي حالة صحية',
            color: const Color(0xFF1877F2),
            fieldType: 'healthConditions',
            controller: healthController, // أضيفي هذا

          ),
          const SizedBox(height: 16),

          // الحساسية
          HealthInfoCard(
            icon: Icons.warning_amber_outlined,
            title: 'الحساسية',
            items: user.allergies ?? [],
            emptyMessage: 'لا توجد حساسية مسجلة',
            color: const Color(0xFFFF6B6B),
            fieldType: 'allergies',
            controller: healthController, // ✅ أضيفي هذا السطر

          ),
          const SizedBox(height: 16),

          // الأدوية الحالية
          HealthInfoCard(
            icon: Icons.medication_outlined,
            title: 'الأدوية الحالية',
            items: user.currentMedications ?? [],
            emptyMessage: 'لا توجد أدوية مسجلة',
            color: const Color(0xFF4CAF50),
            fieldType: 'currentMedications',
            controller: healthController, // ✅ أضيفي هذا السطر

          ),
        ],
      ),
    );
  }
}