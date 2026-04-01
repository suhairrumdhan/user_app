// screens/health_records_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/health_record_controller.dart';
import '../../controllers/family_controller.dart';
import '../../models/family_member_model.dart';
import '../../models/user_model.dart';
import '../../widgets/health_record/health_info_card.dart';
import 'family_member_health_page.dart';

class HealthRecordsPage extends StatelessWidget {
  HealthRecordsPage({super.key});

  final UserController userController = Get.find<UserController>();
  final HealthRecordController healthController = Get.find();
  final FamilyController familyController = Get.find();
  final Color pPrimaryColor = const Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    final user = userController.user.value;
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
                  const Text(
                    "السجل الصحي",
                    style: TextStyle(
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
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      // تبويبات
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            color: pPrimaryColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          tabs: const [
                            Tab(text: "سجلي الصحي"),
                            Tab(text: "أفراد العائلة"),
                          ],
                        ),
                      ),

                      // المحتوى
                      Expanded(
                        child: TabBarView(
                          children: [
                            // سجل المستخدم
                            _buildUserHealthRecords(user),

                            // سجلات أفراد العائلة
                            _buildFamilyMembersHealthRecords(),
                          ],
                        ),
                      ),
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

  Widget _buildUserHealthRecords(UserModel? user) {
    if (user == null) return const SizedBox();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // الحالات الصحية
        HealthInfoCard(
          icon: Iconsax.health,
          title: 'الحالات الصحية',
          items: user.healthConditions ?? [],
          emptyMessage: 'لم يتم تسجيل أي حالة صحية',
          color: pPrimaryColor,
          fieldType: 'healthConditions',
          controller: healthController,
          personType: 'user',
          personId: user.id,
        ),
        const SizedBox(height: 16),

        // الحساسية
        HealthInfoCard(
          icon: Iconsax.warning_2,
          title: 'الحساسية',
          items: user.allergies ?? [],
          emptyMessage: 'لا توجد حساسية مسجلة',
          color: const Color(0xFFFF6B6B),
          fieldType: 'allergies',
          controller: healthController,
          personType: 'user',
          personId: user.id,
        ),
        const SizedBox(height: 16),

        // الأدوية الحالية
        HealthInfoCard(
          icon: Iconsax.hospital,
          title: 'الأدوية الحالية',
          items: user.currentMedications ?? [],
          emptyMessage: 'لا توجد أدوية مسجلة',
          color: const Color(0xFF4CAF50),
          fieldType: 'currentMedications',
          controller: healthController,
          personType: 'user',
          personId: user.id,
        ),
      ],
    );
  }

  Widget _buildFamilyMembersHealthRecords() {
    return StreamBuilder<List<FamilyMemberModel>>(
      stream: familyController.getMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5EABD6)),
            ),
          );
        }

        final members = snapshot.data!;

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.people,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "لا يوجد أفراد عائلة",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "أضف أفراد عائلتك أولاً",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildFamilyMemberCard(member);
          },
        );
      },
    );
  }

  Widget _buildFamilyMemberCard(FamilyMemberModel member) {
    return GestureDetector(
      onTap: () {
        Get.to(() => FamilyMemberHealthPage(member: member));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
          border: Border.all(
            color: Colors.grey[100]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                member.gender == 'ذكر' ? Iconsax.man : Iconsax.woman,
                color: pPrimaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.heart,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "صلة القرابة: ${member.relation ?? '-'}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.cake,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "العمر: ${member.age != null ? '${member.age} سنة' : '-'}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_left_1,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}