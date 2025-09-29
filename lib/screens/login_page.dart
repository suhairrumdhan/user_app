import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/widgets/social_sign_in_button.dart';
import 'package:user_application/auth/auth_services.dart';

// Controller للـ Login
class LoginController extends GetxController {
  final email = ''.obs;
  final password = ''.obs;
  final rememberMe = false.obs;
  final isLoading = false.obs;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();
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
          Align(
            alignment: Alignment.topCenter,
            child: Container(height: height * 0.25, color: Colors.transparent),
          ),
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
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        "تسجيل الدخول",
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // البريد الإلكتروني
                      CustomTextField(
                        controller: controller.emailController,
                        label: "البريد الإلكتروني",
                        inputType: TextInputType.emailAddress,
                        onChanged: (value) => controller.email.value = value,
                        validator: (value) =>
                        value == null || !value.contains("@")
                            ? "بريد إلكتروني غير صالح"
                            : null,
                      ),
                      // كلمة المرور
                      Obx(() => CustomTextField(
                        controller: controller.passwordController,
                        label: "كلمة المرور",
                        obscure: true,
                        onChanged: (value) => controller.password.value = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى إدخال كلمة المرور";
                          } else if (value.length < 6) {
                            return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                          }
                          return null;
                        },
                      )),

                      // تذكر كلمة المرور
                      Obx(() => Row(
                        children: [
                          Checkbox(
                              value: controller.rememberMe.value,
                              onChanged: (value) =>
                              controller.rememberMe.value = value!),
                          const Text("تذكر كلمة المرور"),
                        ],
                      )),
                      const SizedBox(height: 24),

                      // زر تسجيل الدخول
                      // زر تسجيل الدخول
                      Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                            if (_formKey.currentState!.validate()) {
                              controller.authService.loginWithEmail(
                                context: context,
                                email: controller.email.value,
                                password: controller.password.value,
                                setLoading: (loading) =>
                                controller.isLoading.value = loading,
                              );
                            }
                          },
                          child: controller.isLoading.value
                              ? const CircularProgressIndicator()
                              : const Text("تسجيل الدخول"),
                        ),
                      )),


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
                            icon: Icon(Bootstrap.google),
                            onPressed: () => controller.authService.signInWithGoogle(
                              context,
                                  (isLoading) =>
                              controller.isLoading.value = isLoading,
                            ),
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          SocialSignInButton(
                            icon: Icon(Bootstrap.github),
                            onPressed: () {},
                            color: const Color(0xFF4267B2),
                          ),
                          const SizedBox(width: 16),
                          SocialSignInButton(
                            icon: Icon(Bootstrap.facebook),
                            onPressed: () {},
                            color: const Color(0xFF1DA1F2),
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

          // مؤشر التحميل
          Obx(() => controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox()),
        ],
      ),
    );
  }
}
