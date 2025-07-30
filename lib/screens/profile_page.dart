import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                "إعدادات الحساب",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                "قم بتعديل معلوماتك الصحية والإشعارات والتفضيلات",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ProfileMenuCard(
                svgSrc: "assets / icons / profile.svg",
                title: "معلومات الحساب",
                subTitle: "تعديل بياناتك الشخصية والطبية",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/prescription.svg",
                title: "الوصفات الطبية",
                subTitle: "عرض وإدارة وصفاتك الطبية",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/meds.svg",
                title: "الأدوية المفضلة",
                subTitle: "عرض قائمة الأدوية التي تفضلها",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/reminder.svg",
                title: "تنبيهات الأدوية",
                subTitle: "إعداد مواعيد التنبيه لتناول الأدوية",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/ history.svg",
                title: "السجل الصحي",
                subTitle: "تصفح بياناتك الصحية السابقة",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/privacy.svg",
                title: "إعدادات الخصوصية",
                subTitle: "تحكم بمن يرى بياناتك الصحية",
                press: () {},
              ),
              ProfileMenuCard(
                svgSrc: "assets/icons/share.svg",
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
    required this.svgSrc,
    required this.press,
  });

  final String title, subTitle, svgSrc;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: press,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SvgPicture.asset(
                svgSrc,
                height: 24,
                width: 24,
                colorFilter: ColorFilter.mode(
                  const Color(0xFF010F07).withOpacity(0.64),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subTitle,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF010F07).withOpacity(0.54),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_outlined, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
