import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:user_application/features/profile/views/edit_profile_page.dart';
import 'package:user_application/features/health_records/views/health_record_page.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../family/controllers/family_controller.dart';
import '../../health_records/controllers/health_record_controller.dart';
import '../../insurance/views/insurance_page.dart';
import '../../previous_medications/views/previous_medications_page.dart';
import '../../saved_prescriptions/views/saved_prescriptions_page.dart';
import '../controllers/user_controller.dart';
import '../widgets/profile_menu_card.dart';
import '../../../app/core/services/profile_image_service.dart';
import '../../family/views/family_page.dart';
import '../../reminders/views/reminders_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final ScrollController _scrollController = ScrollController();
  double _avatarScale = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // كلما تنزل، صغّر الصورة تدريجياً حتى نصف الحجم
    double offset = _scrollController.offset;
    double newScale = (1 - (offset / 200)).clamp(0.5, 1.0);
    if (newScale != _avatarScale) {
      setState(() {
        _avatarScale = newScale;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final UserController userController = Get.find<UserController>();

    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // ===== AppBar ثابت =====
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
                    "الملف الشخصي",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ===== محتوى الصفحة مع Scroll =====
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) => true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // ===== صورة البروفايل المتحركة =====
                      Obx(() {
                        final userModel = userController.user.value;
                        final authUser = authController.user.value;
                        String? photoUrl =
                            userModel?.profileImageUrl ?? authUser?.photoURL;

                        return Column(
                          children: [
                            AnimatedScale(
                              scale: _avatarScale,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor:
                                    Colors.white.withOpacity(0.3),
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => ProfileImageService
                                          .showImagePickerBottomSheet(
                                        context,
                                        userController,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: pPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ===== الاسم والبريد =====
                            Text(
                              (userModel?.name?.isNotEmpty == true
                                  ? userModel!.name
                                  : authUser?.displayName) ??
                                  'مستخدم',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (userModel?.email?.isNotEmpty == true
                                  ? userModel!.email
                                  : authUser?.email) ??
                                  'لا يوجد بريد إلكتروني',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }),

                      const SizedBox(height: 20),

                      // ===== البوكس الأبيض =====
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              ProfileMenuCard(
                                icon: Icons.settings,
                                title: "إعدادات الحساب",
                                subTitle: "تعديل بياناتك الشخصية، معلومات الاتصال، كلمة المرور ",
                                //expandableChild:  // الفورم الذي يظهر عند الضغط
                                onTap: () {
                                  // أي إجراء إضافي عند الضغط
                                  Get.to(() => const EditProfilePage());
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.family_restroom,
                                title: "أفراد العائلة",
                                subTitle: "عرض وإدارة أفراد عائلتك ",
                                onTap: () {
                                  Get.to(() => FamilyPage());
                                },
                              ),

                              ProfileMenuCard(
                                icon: Icons.history_outlined,
                                title: "سجل الأدوية",
                                subTitle: "سجل الأدوية  لك وأفراد العائلة ",
                                onTap: () {
                                  Get.to(() => const PreviousMedicationsPage());
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.alarm_outlined,
                                title: "التذكيرات",
                                subTitle: "إدارة تنبيهات الأدوية والمواعيد",
                                onTap: () {
                                  Get.to(() => const RemindersPage());
                                },
                              ),

                              ProfileMenuCard(
                                icon: Iconsax.save_2,
                                title: "وصفاتك المحفوظة",
                                subTitle: "تصفح الوصفات التي قمت بحفظها",
                                onTap: () {
                                  Get.to(() => const SavedPrescriptionsPage());
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.monitor_heart,
                                title: "السجلات الصحية",
                                subTitle: " تصفح البيانات الصحية لك ولأفراد عائلتك",
                                onTap: () {
                                  Get.put(FamilyController());         // أول واحد
                                  Get.put(HealthRecordController());   // بعده
                                  Get.to(() => HealthRecordsPage());
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.health_and_safety_outlined,
                                title: "التأمين الصحي",
                                subTitle: "عرض وإدارة شركات التأمين ",
                                onTap: () {
                                  Get.to(() => InsurancePage());
                                },
                              ),
                              // ===== زر تسجيل الخروج =====
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showLogoutDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.logout,
                                          size: 24,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'تسجيل الخروج',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
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

  void _showLogoutDialog(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              authController.signOut();
            },
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
