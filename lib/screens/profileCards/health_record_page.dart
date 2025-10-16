import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/user_controller.dart';
import '../../widgets/profile_menu_card.dart';

class HealthRecordsPage extends StatelessWidget {
  HealthRecordsPage({super.key});
  final UserController userController = Get.find<UserController>();

  @override
  Widget build(BuildContext context) {
    final user = userController.user.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("السجل الصحي"),
        backgroundColor: const Color(0xFF5EABD6),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // الحالات الصحية
            ProfileMenuCard(
              icon: Icons.health_and_safety_outlined,
              title: "الحالات الصحية",
              subTitle: user.healthConditions.isNotEmpty
                  ? user.healthConditions.join(", ")
                  : "لم يتم تسجيل أي حالة صحية",
              onTap: () {
                // يمكن فتح تفاصيل أو تعديل هنا
              },
            ),
            const SizedBox(height: 12),

            // الحساسية
            ProfileMenuCard(
              icon: Icons.warning_amber_outlined,
              title: "الحساسية",
              subTitle: user.allergies.isNotEmpty
                  ? user.allergies.join(", ")
                  : "لا توجد حساسية مسجلة",
              onTap: () {},
            ),
            const SizedBox(height: 12),

            // الأدوية الحالية
            ProfileMenuCard(
              icon: Icons.medication_outlined,
              title: "الأدوية الحالية",
              subTitle: user.currentMedications.isNotEmpty
                  ? user.currentMedications.join(", ")
                  : "لا توجد أدوية مسجلة",
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
