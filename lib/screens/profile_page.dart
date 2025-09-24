import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ---------- صورة شخصية مع أيقونة تعديل ----------
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF7643), // نفس اللون الأساسي
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
              ),
              const SizedBox(height: 12),
              Text(
                "اسم المستخدم",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "example@email.com",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 24),

              // ---------- العناوين ----------
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
                press: () {},
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
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({
    super.key,
    required this.title,
    required this.subTitle,
    required this.icon,
    required this.press,
  });

  final String title, subTitle;
  final IconData icon;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF7643);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: press,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.black.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}