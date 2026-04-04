// screens/family_member_health_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../health_records/controllers/health_record_controller.dart';
import '../controllers/family_controller.dart';
import '../models/family_member_model.dart';
import '../../health_records/widgets/health_info_card.dart';

class FamilyMemberHealthPage extends StatelessWidget {
  final String memberId; // تغيير من member إلى memberId

  const FamilyMemberHealthPage({
    super.key,
    required this.memberId,
  });

  final Color pPrimaryColor = const Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    final healthController = Get.find<HealthRecordController>();
    final familyController = Get.find<FamilyController>();

    // استخدام Obx للتفاعل المباشر مع البيانات الحية
    return Obx(() {
      // جلب الفرد من الـ Observable list
      final member = familyController.members.firstWhereOrNull(
              (m) => m.id == memberId
      );

      // إذا لم يتم العثور على الفرد، عرض مؤشر تحميل
      if (member == null) {
        return Scaffold(
          backgroundColor: pPrimaryColor,
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري تحميل البيانات...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
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
                    Expanded(
                      child: Text(
                        "السجل الصحي - ${member.name}",
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
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // معلومات أساسية للفرد (تتغير تلقائياً مع التحديث)
                      _buildMemberBasicInfo(member),
                      const SizedBox(height: 16),

                      // 🩸 فصيلة الدم - إضافة جديدة
                      HealthInfoCard(
                        icon: Iconsax.drop,
                        title: 'فصيلة الدم',
                        items: member.bloodType != null ? [member.bloodType!] : [],
                        emptyMessage: 'لم يتم تحديد فصيلة الدم',
                        color: const Color(0xFFE74C3C),
                        fieldType: 'bloodType',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                      const SizedBox(height: 16),

                      // الحالات الصحية
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
                      const SizedBox(height: 16),

                      // الحساسية
                      HealthInfoCard(
                        icon: Iconsax.warning_2,
                        title: 'الحساسية',
                        items: member.allergies ?? [],
                        emptyMessage: 'لا توجد حساسية مسجلة',
                        color: const Color(0xFFFF6B6B),
                        fieldType: 'allergies',
                        controller: healthController,
                        personType: 'family_member',
                        personId: member.id!,
                      ),
                      const SizedBox(height: 16),

                      // الأدوية الحالية
                      HealthInfoCard(
                        icon: Iconsax.hospital,
                        title: 'الأدوية الحالية',
                        items: member.currentMedications ?? [],
                        emptyMessage: 'لا توجد أدوية مسجلة',
                        color: const Color(0xFF4CAF50),
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

  Widget _buildMemberBasicInfo(FamilyMemberModel member) {
    return Container(
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
              size: 32,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "صلة القرابة: ${member.relation ?? '-'}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (member.age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "العمر: ${member.age} سنة",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                // ملاحظة: تم إزالة عرض فصيلة الدم من هنا لأنها موجودة في بطاقة منفصلة
              ],
            ),
          ),
        ],
      ),
    );
  }
}