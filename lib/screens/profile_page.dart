import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/screens/profileCards/edit_profile_page.dart';
import 'package:user_application/screens/profileCards/health_record_page.dart';
import '../controllers/AuthController.dart';
import '../controllers/user_controller.dart';
import '../widgets/profile_menu_card.dart';
import '../services/profile_image_service.dart';

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
                    "إعدادات الحساب",
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
                                icon: Icons.person_outline,
                                title: "معلومات الحساب",
                                subTitle: "تعديل بياناتك الشخصية والطبية",
                                expandableChild: const EditProfilePage(), // الفورم الذي يظهر عند الضغط
                                onTap: () {
                                  // أي إجراء إضافي عند الضغط
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.description_outlined,
                                title: "الوصفات الطبية",
                                subTitle: "عرض وإدارة وصفاتك الطبية",
                              ),
                              ProfileMenuCard(
                                icon: Icons.favorite_border,
                                title: "الأدوية المفضلة",
                                subTitle: "عرض قائمة الأدوية التي تفضلها",
                              ),
                              ProfileMenuCard(
                                icon: Icons.notifications_outlined,
                                title: "تنبيهات الأدوية",
                                subTitle: "إعداد مواعيد التنبيه لتناول الأدوية",
                              ),
                              ProfileMenuCard(
                                icon: Icons.show_chart_outlined,
                                title: "السجل الصحي",
                                subTitle: "تصفح بياناتك الصحية السابقة",
                                onTap: () {
                                  // فتح صفحة السجل الصحي عند الضغط
                                  Get.to(() => HealthRecordsPage());
                                },
                              ),
                              ProfileMenuCard(
                                icon: Icons.security_outlined,
                                title: "إعدادات الخصوصية",
                                subTitle: "تحكم بمن يرى بياناتك الصحية",
                              ),
                              ProfileMenuCard(
                                icon: Icons.share_outlined,
                                title: "شارك التطبيق",
                                subTitle: "انشر التطبيق لأصدقائك وادعمهم صحيًا",
                              ),
                              const SizedBox(height: 24),

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
