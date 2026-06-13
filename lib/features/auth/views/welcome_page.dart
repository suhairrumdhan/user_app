import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/features/auth/views/login_page.dart';
import 'package:user_application/features/auth/views/signup_page.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _primaryBlue = Color(0xFF0D47A1);
  static const Color _secondaryBlue = Color(0xFF1565C0);
  static const Color _deepBlue = Color(0xFF0A2F6B);
  static const Color _accentCyan = Color(0xFF4FC3F7);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final width = size.width;
    final height = size.height;

    final bool isShort = height < 700;
    final bool isTablet = width >= 600;

    final double horizontalPadding = math.max(18, math.min(width * 0.065, 30));
    final double topSpacing = math.max(8, math.min(height * 0.018, 18));
    final double bottomSpacing = math.max(8, math.min(height * 0.016, 16));

    final double bannerHeight = math.max(
      140,
      math.min(height * 0.25, isTablet ? 240 : 210),
    );

    final double titleFontSize = math.max(
      28,
      math.min(width * 0.085, isTablet ? 42 : 36),
    );

    final double latinFontSize = math.max(
      14,
      math.min(width * 0.040, 18),
    );

    final double bodyFontSize = math.max(
      13,
      math.min(width * 0.038, 16),
    );

    final double welcomeFontSize = math.max(
      24,
      math.min(width * 0.078, isTablet ? 40 : 32),
    );

    final double subTextFontSize = math.max(
      12.5,
      math.min(width * 0.036, 15),
    );

    final double buttonHeight = math.max(
      50,
      math.min(height * 0.072, 60),
    );

    final double buttonFontSize = math.max(
      15.5,
      math.min(width * 0.043, 18),
    );

    final double chipFontSize = math.max(
      11,
      math.min(width * 0.030, 12.5),
    );

    final double chipIconSize = math.max(
      14,
      math.min(width * 0.040, 16),
    );

    return CustomScaffold(
      child: Stack(
        children: [
          Positioned(
            top: -width * 0.14,
            left: -width * 0.10,
            child: _decorCircle(
              size: width * 0.34,
              color: _accentCyan.withOpacity(0.15),
            ),
          ),
          Positioned(
            top: height * 0.20,
            right: -width * 0.08,
            child: _decorCircle(
              size: width * 0.18,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: -width * 0.18,
            right: -width * 0.10,
            child: _decorCircle(
              size: width * 0.40,
              color: _accentCyan.withOpacity(0.13),
            ),
          ),
          Positioned(
            bottom: height * 0.18,
            left: -width * 0.06,
            child: _decorCircle(
              size: width * 0.15,
              color: Colors.white.withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  SizedBox(height: topSpacing),

                  Expanded(
                    flex: 30,
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        height: bannerHeight,
                        decoration: BoxDecoration(
                          // [CHANGE 1] Reduced transparency (more solid) and slightly darker base
                          color: Colors.black.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(isTablet ? 34 : 28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2), // Slightly more visible border
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        // [CHANGE 2] Made ClipRRect wrap the image directly, removing the inner Padding
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isTablet ? 34 : 28),
                          child: Image.asset(
                            'assets/images/welcome_medicine.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            // No more inner padding, image touches the border directly
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: math.max(8, height * 0.012)),

                  Expanded(
                    flex: 14,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'روشيتة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: 0.2,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTablet ? 520 : 430,
                          ),
                          child: Text(
                            'بوابتك للوصول إلى الصيدليات، إدارة الوصفات، ومتابعة طلبات الدواء بسهولة.',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.84),
                              fontSize: bodyFontSize,
                              height: 1.65,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  Expanded(
                    flex: 18,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: math.max(8, height * 0.010)),
                        Text(
                          'مرحباً بعودتك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: welcomeFontSize,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: math.max(6, height * 0.008)),
                      ],
                    ),
                  ),

                  Expanded(
                    flex: 18,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 480 : 430,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionButton(
                              text: 'تسجيل الدخول',
                              isOutlined: true,
                              height: buttonHeight,
                              fontSize: buttonFontSize,
                              onTap: () => Get.to(() => const LoginPage()),
                            ),
                            SizedBox(height: math.max(10, height * 0.014)),
                            _ActionButton(
                              text: 'إنشاء حساب جديد',
                              isOutlined: false,
                              height: buttonHeight,
                              fontSize: buttonFontSize,
                              onTap: () => Get.to(() => const SignUpPage()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: bottomSpacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );  }

  Widget _decorCircle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final bool isOutlined;
  final double height;
  final double fontSize;
  final VoidCallback onTap;

  const _ActionButton({
    required this.text,
    required this.isOutlined,
    required this.height,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOutlined ? Colors.transparent : Colors.white;
    final textColor = isOutlined ? Colors.white : const Color(0xFF0D47A1);
    final borderColor = Colors.white.withOpacity(isOutlined ? 0.78 : 0.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: borderColor,
                width: 1.3,
              ),
              boxShadow: isOutlined
                  ? []
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final double fontSize;

  const _MiniFeatureChip({
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: math.max(12, fontSize + 2),
        vertical: math.max(8, fontSize - 2),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.92),
            size: iconSize,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}