import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../controllers/family_controller.dart';
import '../models/family_member_model.dart';
import 'add_edit_family_member_page.dart';

class FamilyPage extends StatelessWidget {
  FamilyPage({super.key});

  final controller = Get.put(FamilyController());
  final Color pPrimaryColor = const Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar بنفس تصميم ProfilePage
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
                    "أفراد العائلة",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // زر الإضافة
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const AddEditFamilyMemberPage());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Iconsax.add,
                        color: pPrimaryColor,
                        size: 22,
                      ),
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
                child: StreamBuilder<List<FamilyMemberModel>>(
                  stream: controller.getMembers(),
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
                              "لا يوجد أفراد",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "أضف أفراد عائلتك الآن",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Get.to(() => const AddEditFamilyMemberPage());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("إضافة فرد جديد"),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final m = members[index];
                        return _buildMemberCard(m, context); // تمرير context هنا
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(FamilyMemberModel member, BuildContext context) {
    return Container(
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
          // الأيقونة
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

          // المعلومات
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
                if (member.bloodType != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.health,
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
                ],
              ],
            ),
          ),

          // أزرار التعديل والحذف
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: pPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Iconsax.edit,
                    color: pPrimaryColor,
                    size: 20,
                  ),
                  onPressed: () {
                    Get.to(() => AddEditFamilyMemberPage(memberId: member.id));
                  },
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Iconsax.trash,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteDialog(context, member),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showDeleteDialog(BuildContext context, FamilyMemberModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("حذف فرد"),
        content: Text("هل أنت متأكد من حذف ${member.name}؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteMember(member.id!);
            },
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}