import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/screens/profileCards/account_info_card.dart';
import '../controllers/AuthController.dart';
import '../controllers/user_controller.dart';
import '../widgets/profile_menu_card.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final UserController userController = Get.find<UserController>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ---------- صورة شخصية ----------
              Obx(() {
                final userModel = userController.user.value;
                final authUser = authController.user.value;

                String? photoUrl = authUser?.photoURL;

                return Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF7643),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              // ---------- الاسم ----------
              Obx(() {
                final userModel = userController.user.value;
                final authUser = authController.user.value;

                final displayName = (userModel?.name?.isNotEmpty == true
                    ? userModel!.name
                    : authUser?.displayName) ?? 'مستخدم';

                return Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                );
              }),

              const SizedBox(height: 4),

              // ---------- البريد ----------
              Obx(() {
                final userModel = userController.user.value;
                final authUser = authController.user.value;

                final email = (userModel?.email?.isNotEmpty == true
                    ? userModel!.email
                    : authUser?.email) ?? 'لا يوجد بريد إلكتروني';


                return Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // ---------- إعدادات الحساب ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "إعدادات الحساب",
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "قم بتعديل معلوماتك الصحية والإشعارات والتفضيلات",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---------- الكروت ----------
              ProfileMenuCard(
                icon: Icons.person_outline,
                title: "معلومات الحساب",
                subTitle: "تعديل بياناتك الشخصية والطبية",
                press: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      contentPadding: const EdgeInsets.all(16),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: const AccountInfoCard(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسناً'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              ProfileMenuCard(
                icon: Icons.description_outlined,
                title: "الوصفات الطبية",
                subTitle: "عرض وإدارة وصفاتك الطبية",
                press: () {},
              ),
              ProfileMenuCard(
                icon: Icons.favorite_border,
                title: "الأدوية المفضلة",
                subTitle: "عرض قائمة الأدوية التي تفضلها",
                press: () {},
              ),
              ProfileMenuCard(
                icon: Icons.notifications_outlined,
                title: "تنبيهات الأدوية",
                subTitle: "إعداد مواعيد التنبيه لتناول الأدوية",
                press: () {},
              ),
              ProfileMenuCard(
                icon: Icons.show_chart_outlined,
                title: "السجل الصحي",
                subTitle: "تصفح بياناتك الصحية السابقة",
                press: () {},
              ),
              ProfileMenuCard(
                icon: Icons.security_outlined,
                title: "إعدادات الخصوصية",
                subTitle: "تحكم بمن يرى بياناتك الصحية",
                press: () {},
              ),
              ProfileMenuCard(
                icon: Icons.share_outlined,
                title: "شارك التطبيق",
                subTitle: "انشر التطبيق لأصدقائك وادعمهم صحيًا",
                press: () {},
              ),

              const SizedBox(height: 24),

              // ---------- زر تسجيل الخروج ----------
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _showLogoutDialog(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.logout,
                            size: 24,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
            child: const Text('تسجيل الخروج',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserController userController) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: const Text('هذه الميزة قيد التطوير'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
