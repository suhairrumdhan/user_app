import 'package:flutter/material.dart';
import 'package:user_application/features/auth/views/login_page.dart';
import 'package:user_application/features/auth/views/signup_page.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/welcome_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key}); // ✅   هنا

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Column(
        children: [
          Flexible(
            flex: 8,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 40),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      color: Colors.white, // ✅ اللون الأبيض الأساسي للنصوص
                    ),
                    children: [
                      TextSpan(
                        text: 'مرحبا بك \n',
                        style: TextStyle(
                          fontSize: 45.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: 'في روشيتة هنا بوابتك الى الصيدليات \n',
                        style: TextStyle(fontSize: 20.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'تسجيل الدخول',
                      onTap: LoginPage(),
                      color: Colors.transparent,
                      textColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: WelcomeButton(
                      buttonText: 'إنشاء حساب جديد',
                      onTap:  SignUpPage(),
                      color: Color(0xFFE0F7FA),
                      textColor: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
