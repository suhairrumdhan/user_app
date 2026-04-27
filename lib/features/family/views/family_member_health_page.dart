import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../health_records/controllers/health_record_controller.dart';
import '../controllers/family_controller.dart';
import '../models/family_member_model.dart';
import '../../health_records/widgets/health_info_card.dart';

class FamilyMemberHealthPage extends StatelessWidget {
  final String memberId;

  const FamilyMemberHealthPage({
    super.key,
    required this.memberId,
  });

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);

  static const Color _textPrimary = Color(0xFF2C3E50);
  static const Color _textSecondary = Color(0xFF7F8C8D);

  @override
  Widget build(BuildContext context) {
    final healthController = Get.find<HealthRecordController>();
    final familyController = Get.find<FamilyController>();

    return Obx(() {
      final member = familyController.members.firstWhereOrNull(
            (m) => m.id == memberId,
      );

      if (member == null) {
        return Scaffold(
          backgroundColor: pPrimaryColor,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'السجل الصحي - ${member.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      _buildTopCard(member),
                      const SizedBox(height: 18),
                      _buildMemberBasicInfo(member),
                      const SizedBox(height: 16),
                      HealthInfoCard(
                        icon: Iconsax.drop3,
                        title: 'فصيلة الدم',
                        items: member.bloodType != null ? [member.bloodType!] : [],
                        emptyMessage: 'لم يتم تحديد فصيلة الدم',
                        color: pPrimaryColor,
                        fieldType: 'bloodType',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                      HealthInfoCard(
                        icon: Iconsax.health,
                        title: 'الحالات الصحية',
                        items: member.healthConditions ?? [],
                        emptyMessage: 'لم يتم تسجيل أي حالة صحية',
                        color: pPrimaryColor,
                        fieldType: 'healthConditions',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                      HealthInfoCard(
                        icon: Iconsax.warning_2,
                        title: 'الحساسية',
                        items: member.allergies ?? [],
                        emptyMessage: 'لا توجد حساسية مسجلة',
                        color: pPrimaryColor,
                        fieldType: 'allergies',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                      HealthInfoCard(
                        icon: Iconsax.hospital,
                        title: 'الأدوية الحالية',
                        items: member.currentMedications ?? [],
                        emptyMessage: 'لا توجد أدوية مسجلة',
                        color: pPrimaryColor,
                        fieldType: 'currentMedications',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTopCard(FamilyMemberModel member) {
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
            child: Icon(
              member.gender == 'ذكر' ? Iconsax.man : Iconsax.woman,
              color: Colors.white,
              size: 28,
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
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'متابعة السجل الصحي والبيانات الطبية الخاصة بهذا الفرد بشكل منظم وواضح.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
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

  Widget _buildMemberBasicInfo(FamilyMemberModel member) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: pLightColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              member.gender == 'ذكر' ? Iconsax.man : Iconsax.woman,
              color: pPrimaryColor,
              size: 26,
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
                    if (member.age != null)
                      _buildMetaChip(
                        icon: Iconsax.cake,
                        label: '${member.age} سنة',
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
        ],
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
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}