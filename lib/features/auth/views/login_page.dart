import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/custom_text_field.dart';
import 'package:user_application/features/auth/services/auth_services.dart';

// Controller للـ Login
class LoginController extends GetxController {
  String email = '';
  String password = '';
  var isLoading = false.obs;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final authService = AuthService();

  void setLoading(bool value) {
    isLoading.value = value;
  }

  // إضافة دالة لتنظيف الحقول
  void clearFields() {
    emailController.clear();
    passwordController.clear();
    email = '';
    password = '';
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late LoginController controller;

  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    // استخدام Get.put مع tag فريد لضمان إنشاء نسخة جديدة
    // أو استخدام Get.find إذا كانت موجودة بالفعل
    if (Get.isRegistered<LoginController>()) {
      controller = Get.find<LoginController>();
    } else {
      controller = Get.put(LoginController());
    }
  }

  @override
  void dispose() {
    // تنظيف الحقول عند مغادرة الصفحة
    controller.clearFields();
    // إزالة الـ Controller من الذاكرة إذا أردت
    // Get.delete<LoginController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        // تنظيف الحقول عند الضغط على زر الرجوع
        controller.clearFields();
        return true;
      },
      child: CustomScaffold(
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
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

                        // كلمة المرور مع زر العين
                        CustomTextField(
                          controller: controller.passwordController,
                          label: "كلمة المرور",
                          isPasswordField: true,
                          showPassword: showPassword,
                          onVisibilityToggle: () {
                            setState(() => showPassword = !showPassword);
                          },
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

                        const SizedBox(height: 24),

                        // زر تسجيل الدخول
                        Obx(() => Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5EABD6),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5EABD6).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: controller.isLoading.value
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5EABD6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: controller.isLoading.value
                                ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              "تسجيل الدخول",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )),

                        const SizedBox(height: 20),

                        // زر Google
                        Obx(() => Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: controller.isLoading.value
                                ? null
                                : () => controller.authService.signInWithGoogle(
                              context,
                              controller.setLoading,
                            ),
                            icon: const Icon(Bootstrap.google, color: Colors.red),
                            label: const Text(
                              "التسجيل باستخدام Google",
                              style: TextStyle(
                                color: Color(0xFF2C3E50),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        )),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // مؤشر التحميل overlay
            Obx(() => controller.isLoading.value
                ? Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
                : const SizedBox()),
          ],
        ),
      ),
    );
  }
}