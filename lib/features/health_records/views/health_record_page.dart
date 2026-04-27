import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../profile/controllers/user_controller.dart';
import '../controllers/health_record_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../family/models/family_member_model.dart';
import '../widgets/health_info_card.dart';
import '../../family/views/family_member_health_page.dart';

class HealthRecordsPage extends StatelessWidget {
  HealthRecordsPage({super.key});

  final UserController userController = Get.find<UserController>();
  final HealthRecordController healthController =
  Get.find<HealthRecordController>();
  final FamilyController familyController = Get.find<FamilyController>();

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);

  static const Color _textPrimary = Color(0xFF2C3E50);
  static const Color _textSecondary = Color(0xFF7F8C8D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الملف الصحي',
                    style: TextStyle(
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
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                            gradient: LinearGradient(
                              colors: [pPrimaryColor, pSecondaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: pPrimaryColor.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: _textSecondary,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          splashBorderRadius: BorderRadius.circular(30),
                          overlayColor:
                          WidgetStateProperty.all(Colors.transparent),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.health_and_safety_outlined,
                                  size: 18),
                              text: 'ملفي الصحي',
                            ),
                            Tab(
                              icon: Icon(Icons.family_restroom_outlined,
                                  size: 18),
                              text: 'أفراد العائلة',
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildUserHealthRecords() {
    return Obx(() {
      final user = userController.user.value;

      if (user == null) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(pPrimaryColor),
          ),
        );
      }

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 24),
        children: [
          _buildTopCard(),
          const SizedBox(height: 18),
          HealthInfoCard(
            icon: Iconsax.drop3,
            title: 'فصيلة الدم',
            items: user.bloodType != null ? [user.bloodType!] : [],
            emptyMessage: 'لم يتم تحديد فصيلة الدم',
            color: pPrimaryColor,
            fieldType: 'bloodType',
            controller: healthController,
            personType: 'user',
            personId: user.id,
          ),
          HealthInfoCard(
            icon: Iconsax.health,
            title: 'الامراض المزمنة والأمراض الحالية',
            items: user.healthConditions ?? [],
            emptyMessage: 'لم يتم تسجيل أي حالة صحية',
            color: pPrimaryColor,
            fieldType: 'healthConditions',
            controller: healthController,
            personType: 'user',
            personId: user.id,
          ),
          HealthInfoCard(
            icon: Iconsax.warning_2,
            title: 'الحساسية',
            items: user.allergies ?? [],
            emptyMessage: 'لا توجد حساسية مسجلة',
            color: pPrimaryColor,
            fieldType: 'allergies',
            controller: healthController,
            personType: 'user',
            personId: user.id,
          ),
          HealthInfoCard(
            icon: Iconsax.hospital,
            title: 'الأدوية الحالية',
            items: user.currentMedications ?? [],
            emptyMessage: 'لا توجد أدوية مسجلة',
            color: pPrimaryColor,
            fieldType: 'currentMedications',
            controller: healthController,
            personType: 'user',
            personId: user.id,
          ),
        ],
      );
    });
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pPrimaryColor, pSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Iconsax.health,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة معلوماتك الصحية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'حدث معلوماتك الصحية الأساسية لتسهيل الطلبات وتحسين دقة الخدمات داخل التطبيق.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMembersHealthRecords() {
    return Obx(() {
      if (familyController.isLoading.value) {
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(pPrimaryColor),
          ),
        );
      }

      final members = familyController.members;

      if (members.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 24),
        itemCount: members.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildFamilyTopCard(),
            );
          }

          final member = members[index - 1];
          return _buildFamilyMemberCard(member);
        },
      );
    });
  }

  Widget _buildFamilyTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pPrimaryColor, pSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Iconsax.people,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السجلات الصحية للعائلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'تابع بيانات أفراد العائلة الصحية بشكل منظم وسريع من مكان واحد.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFamilyTopCard(),
          const SizedBox(height: 40),
          Icon(
            Iconsax.people,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد أفراد عائلة',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف أفراد العائلة أولاً لعرض سجلاتهم الصحية هنا',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMemberCard(FamilyMemberModel member) {
    return GestureDetector(
      onTap: () {
        Get.to(() => FamilyMemberHealthPage(memberId: member.id!));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: pPrimaryColor.withOpacity(0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: pLightColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                member.gender == 'ذكر' ? Iconsax.man : Iconsax.woman,
                color: pPrimaryColor,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetaChip(
                        icon: Iconsax.heart,
                        label: member.relation?.isNotEmpty == true
                            ? member.relation!
                            : 'غير محدد',
                      ),
                      _buildMetaChip(
                        icon: Iconsax.cake,
                        label: member.age != null
                            ? '${member.age} سنة'
                            : 'العمر غير محدد',
                      ),
                      if (member.bloodType != null &&
                          member.bloodType!.isNotEmpty)
                        _buildMetaChip(
                          icon: Iconsax.drop3,
                          label: member.bloodType!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Iconsax.arrow_left_1,
              color: Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pPrimaryColor.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: pPrimaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}