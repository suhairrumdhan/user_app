import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/custom_text_field.dart';
import 'package:user_application/features/auth/services/auth_services.dart';
import 'package:user_application/features/auth/views/forgot_password_page.dart';

// Controller للـ Login
class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var isLoading = false.obs;

  // متغيرات للتحقق المباشر
  final emailError = ''.obs;
  final passwordError = ''.obs;

  final authService = AuthService();

  void setLoading(bool value) {
    isLoading.value = value;
  }

  // دالة التحقق من البريد الإلكتروني
  String? validateEmail(String value) {
    if (value.isEmpty) {
      return "❌ يرجى إدخال البريد الإلكتروني";
    }

    // تحقق من وجود @ و . بعدها
    if (!value.contains('@')) {
      return "❌ البريد الإلكتروني يجب أن يحتوي على @";
    }

    final parts = value.split('@');
    if (parts.length != 2) {
      return "❌ البريد الإلكتروني غير صالح";
    }

    if (parts[0].isEmpty) {
      return "❌ يرجى إدخال الجزء الأول من البريد الإلكتروني";
    }

    if (!parts[1].contains('.')) {
      return "❌ البريد الإلكتروني يجب أن يحتوي على دومين صحيح (مثال: gmail.com)";
    }

    final domainParts = parts[1].split('.');
    if (domainParts.length < 2 || domainParts.any((p) => p.isEmpty)) {
      return "❌ صيغة الدومين غير صحيحة";
    }

    return null;
  }

  // دالة التحقق من كلمة المرور
  String? validatePassword(String value) {
    if (value.isEmpty) {
      return "❌ يرجى إدخال كلمة المرور";
    }

    if (value.length < 6) {
      return "❌ كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    }

    return null;
  }

  // دالة تنظيف الحقول والأخطاء
  void clearFields() {
    emailController.clear();
    passwordController.clear();
    emailError.value = '';
    passwordError.value = '';
  }

  // دالة مساعدة لإظهار رسائل الخطأ من السيرفر
  void showServerError(String message, {bool isError = true}) {
    Get.snackbar(
      isError ? "خطأ" : "تنبيه",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red[50] : Colors.orange[50],
      colorText: isError ? Colors.red[800]! : Colors.orange[800]!,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      snackStyle: SnackStyle.FLOATING,
      icon: Icon(
        isError ? Icons.error_outline : Icons.warning_amber_rounded,
        color: isError ? Colors.red[800] : Colors.orange[800],
      ),
    );
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
    if (Get.isRegistered<LoginController>()) {
      controller = Get.find<LoginController>();
    } else {
      controller = Get.put(LoginController());
    }
  }

  @override
  void dispose() {
    controller.clearFields();
    super.dispose();
  }

  // دالة معالجة تسجيل الدخول مع Validation كامل
  void handleLogin() {
    // إخفاء لوحة المفاتيح
    FocusScope.of(context).unfocus();

    // التحقق من صحة النموذج
    if (_formKey.currentState!.validate()) {
      // التحقق الإضافي من البريد وكلمة المرور قبل الإرسال
      final email = controller.emailController.text.trim();
      final password = controller.passwordController.text;

      // تحقق إضافي (لأمان إضافي)
      if (email.isEmpty) {
        controller.showServerError("يرجى إدخال البريد الإلكتروني");
        return;
      }

      if (password.isEmpty) {
        controller.showServerError("يرجى إدخال كلمة المرور");
        return;
      }

      if (password.length < 6) {
        controller.showServerError("كلمة المرور يجب أن تكون 6 أحرف على الأقل");
        return;
      }

      // تنفيذ عملية تسجيل الدخول
      controller.authService.loginWithEmail(
        context: context,
        email: email,
        password: password,
        setLoading: controller.setLoading,
        onError: (errorMessage) {
          controller.showServerError(errorMessage);
        },
      );
    } else {
      // إذا فشل الـ validation، نعرض رسالة عامة
      controller.showServerError(
        "يرجى التأكد من إدخال البريد الإلكتروني وكلمة المرور بشكل صحيح",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        controller.clearFields();
        return true;
      },
      child: CustomScaffold(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: height * 0.25,
                color: Colors.transparent,
              ),
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
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C3E50),
                              ),
                        ),
                        const SizedBox(height: 24),

                        // البريد الإلكتروني مع Validation متقدم
                        CustomTextField(
                          controller: controller.emailController,
                          label: "البريد الإلكتروني",
                          inputType: TextInputType.emailAddress,
                          onChanged: (value) {
                            // مسح الخطأ عند الكتابة
                            if (controller.emailError.value.isNotEmpty) {
                              controller.emailError.value = '';
                            }
                          },
                          validator: (value) =>
                              controller.validateEmail(value ?? ''),
                        ),

                        const SizedBox(height: 16),

                        // كلمة المرور مع Validation
                        CustomTextField(
                          controller: controller.passwordController,
                          label: "كلمة المرور",
                          isPasswordField: true,
                          showPassword: showPassword,
                          onVisibilityToggle: () {
                            setState(() => showPassword = !showPassword);
                          },
                          onChanged: (value) {
                            // مسح الخطأ عند الكتابة
                            if (controller.passwordError.value.isNotEmpty) {
                              controller.passwordError.value = '';
                            }
                          },
                          validator: (value) =>
                              controller.validatePassword(value ?? ''),
                        ),

                        Obx(
                          () => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : () => Get.to(
                                      () => ForgotPasswordPage(
                                        initialEmail: controller
                                            .emailController
                                            .text
                                            .trim(),
                                      ),
                                    ),
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  color: Color(0xFF5EABD6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // زر تسجيل الدخول
                        Obx(
                          () => Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5EABD6),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF5EABD6,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : handleLogin,
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
                          ),
                        ),

                        const SizedBox(height: 20),

                        // زر Google
                        Obx(
                          () => Container(
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
                                  : () =>
                                        controller.authService.signInWithGoogle(
                                          context,
                                          controller.setLoading,
                                        ),
                              icon: const Icon(
                                Bootstrap.google,
                                color: Colors.red,
                              ),
                              label: const Text(
                                "تسجيل الدخول باستخدام Google",
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // مؤشر التحميل overlay
            Obx(
              () => controller.isLoading.value
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
      ),
    );
  }
}
