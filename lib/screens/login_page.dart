import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/widgets/social_sign_in_button.dart';
import 'package:user_application/auth/auth_services.dart';

// Controller للـ Login
class LoginController extends GetxController {
  String email = '';
  String password = '';
  bool rememberMe = false; // <-- هنا bool عادي
  bool isLoading = false;  // <-- هنا bool عادي

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();

  void setLoading(bool value) {
    isLoading = value;
    update();
  }

  void toggleRemember(bool value) {
    rememberMe = value;
    update();
  }
}


class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final _formKey = GlobalKey<FormState>();
  final LoginController controller = Get.put(LoginController());

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return CustomScaffold(
      child: Stack(
        children: [
          // الجزء العلوي الشفاف
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: height * 0.25, color: Colors.transparent),
          ),

          // الجزء السفلي الأبيض
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: GetBuilder<LoginController>(
                    builder: (controller) => Column(
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          "تسجيل الدخول",
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),

                        // البريد الإلكتروني
                        CustomTextField(
                          controller: controller.emailController,
                          label: "البريد الإلكتروني",
                          inputType: TextInputType.emailAddress,
                          onChanged: (value) => controller.email = value,
                          validator: (value) => value == null || !value.contains("@")
                              ? "بريد إلكتروني غير صالح"
                              : null,
                        ),

                        // كلمة المرور
                        CustomTextField(
                          controller: controller.passwordController,
                          label: "كلمة المرور",
                          obscure: true,
                          onChanged: (value) => controller.password = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "يرجى إدخال كلمة المرور";
                            } else if (value.length < 6) {
                              return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                            }
                            return null;
                          },
                        ),

                        // تذكر كلمة المرور
                        Row(
                          children: [
                            Checkbox(
                              value: controller.rememberMe,
                              onChanged: (value) =>
                                  controller.toggleRemember(value ?? false),
                            ),
                            const Text("تذكر كلمة المرور"),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // زر تسجيل الدخول
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: controller.isLoading
                                ? null
                                : () {
                              if (_formKey.currentState!.validate()) {
                                controller.authService.loginWithEmail(
                                  context: context,
                                  email: controller.email,
                                  password: controller.password,
                                  setLoading: controller.setLoading,
                                );
                              }
                            },
                            child: controller.isLoading
                                ? const CircularProgressIndicator()
                                : const Text("تسجيل الدخول"),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        Text(
                          "أو تسجيل الدخول باستخدام:",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SocialSignInButton(
                              icon: const Icon(Bootstrap.google),
                              onPressed: () => controller.authService.signInWithGoogle(
                                context,
                                controller.setLoading,
                              ),
                              color: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // مؤشر التحميل
          GetBuilder<LoginController>(
            builder: (controller) => controller.isLoading
                ? Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
