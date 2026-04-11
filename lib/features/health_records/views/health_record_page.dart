// screens/health_records_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../profile/controllers/user_controller.dart';
import '../controllers/health_record_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../family/models/family_member_model.dart';
import '../../profile/models/user_model.dart';
import '../widgets/health_info_card.dart';
import '../../family/views/family_member_health_page.dart';

class HealthRecordsPage extends StatelessWidget {
  HealthRecordsPage({super.key});

  final UserController userController = Get.find<UserController>();
  final HealthRecordController healthController = Get.find();
  final FamilyController familyController = Get.find();
  final Color pPrimaryColor = const Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6E8CFB),
                                Color(0xFF5EABD6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF5EABD6).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF7F8C8D),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          splashBorderRadius: BorderRadius.circular(30),
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.health_and_safety_outlined, size: 18),
                              text: "سجلي الصحي",
                            ),
                            Tab(
                              icon: Icon(Icons.family_restroom_outlined, size: 18),
                              text: "أفراد العائلة",
                            ),
                          ],
                        ),
                      ),

                      // 🔽 المحتوى
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TabBarView(
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildUserHealthRecords(),
                              _buildFamilyMembersHealthRecords(),
                            ],
                          ),
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

  // ✅ بناء سجل المستخدم الصحي مع فصيلة الدم
  Widget _buildUserHealthRecords() {
    return Obx(() {
      final user = userController.user.value;

      if (user == null) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5EABD6)),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 🩸 فصيلة الدم - إضافة جديدة
          HealthInfoCard(
            icon: Iconsax.drop,
            title: 'فصيلة الدم',
            items: user.bloodType != null ? [user.bloodType!] : [],
            emptyMessage: 'لم يتم تحديد فصيلة الدم',
            color: const Color(0xFFE74C3C),
            fieldType: 'bloodType',
            controller: healthController,
            personType: 'user',
            personId: user.id,
          ),

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
    });
  }

  // ✅ بناء سجلات أفراد العائلة
  Widget _buildFamilyMembersHealthRecords() {
    return Obx(() {
      if (familyController.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5EABD6)),
          ),
        );
      }

      final members = familyController.members;

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
    });
  }
  Widget _buildFamilyMemberCard(FamilyMemberModel member) {
    return GestureDetector(
      onTap: () {
        Get.to(() => FamilyMemberHealthPage(memberId: member.id!));
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
                  // 🩸 إضافة فصيلة الدم في البطاقة
                  if (member.bloodType != null && member.bloodType!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.drop,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "فصيلة الدم: ${member.bloodType}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
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