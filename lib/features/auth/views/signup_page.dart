import '../../../shared/libya_phone.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/custom_text_field.dart';
import 'package:user_application/features/auth/services/auth_services.dart';

// Controller
class SignUpController extends GetxController {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;

  // متغير بسيط لعرض رسالة قوة كلمة المرور
  final passwordStrengthMessage = ''.obs;

  final authService = AuthService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<FormState> get formKey => _formKey;

  // دالة بسيطة لفحص قوة كلمة المرور وعرض رسالة
  void checkPasswordStrength(String password) {
    if (password.isEmpty) {
      passwordStrengthMessage.value = '';
      return;
    }

    bool hasMinLength = password.length >= 6;
    bool hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowerCase = password.contains(RegExp(r'[a-z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int count = 0;
    if (hasMinLength) count++;
    if (hasUpperCase) count++;
    if (hasLowerCase) count++;
    if (hasNumber) count++;
    if (hasSpecialChar) count++;

    if (count == 5) {
      passwordStrengthMessage.value = '✓ كلمة مرور قوية';
    } else if (count >= 3) {
      passwordStrengthMessage.value = '⚠️ كلمة مرور متوسطة';
    } else {
      passwordStrengthMessage.value = '❌ كلمة مرور ضعيفة';
    }
  }

  // دالة التحقق المخصصة لكلمة المرور
  String? validatePassword(String value) {
    if (value.isEmpty) {
      return "يرجى إدخال كلمة المرور";
    }

    if (value.length <= 6) {
      return "❌ كلمة المرور يجب أن تكون أكثر من 6 أحرف";
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return "❌ كلمة المرور يجب أن تحتوي على أرقام";
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return "❌ كلمة المرور يجب أن تحتوي على رموز";
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return "❌ كلمة المرور يجب أن تحتوي على حروف كبيرة";
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return "❌ كلمة المرور يجب أن تحتوي على حروف صغيرة";
    }

    return null;
  }

  // دالة لتنظيف جميع الحقول
  void clearFields() {
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    passwordStrengthMessage.value = '';
  }

  void register(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      authService.registerWithEmail(
        context: context,
        email: emailController.text.trim(),
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
        phoneNumber: LibyaPhone.normalize(phoneController.text),
        name: nameController.text.trim(),
        setLoading: (loading) => isLoading.value = loading,
      );
    }
  }

  void signInWithGoogle(BuildContext context) {
    authService.signInWithGoogle(
      context,
      (loading) => isLoading.value = loading,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  late SignUpController controller;

  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SignUpController>()) {
      controller = Get.find<SignUpController>();
    } else {
      controller = Get.put(SignUpController());
    }

    // إضافة مستمع للتغيرات في حقل كلمة المرور
    controller.passwordController.addListener(() {
      controller.checkPasswordStrength(controller.passwordController.text);
    });
  }

  @override
  void dispose() {
    controller.clearFields();
    super.dispose();
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
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: controller.formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      "تسجيل حساب جديد",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    CustomTextField(
                      controller: controller.nameController,
                      label: "الاسم الكامل",
                      validator: (value) => value == null || value.isEmpty
                          ? "يرجى إدخال الاسم"
                          : null,
                    ),

                    CustomTextField(
                      controller: controller.phoneController,
                      label: "رقم الهاتف",
                      inputType: TextInputType.phone,
                      validator: (value) => LibyaPhone.validate(value),
                    ),

                    CustomTextField(
                      controller: controller.emailController,
                      label: "البريد الإلكتروني",
                      inputType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "يرجى إدخال البريد الإلكتروني";
                        }
                        if (!value.contains("@")) {
                          return "بريد إلكتروني غير صالح";
                        }
                        return null;
                      },
                    ),

                    // حقل كلمة المرور
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          controller: controller.passwordController,
                          label: "كلمة المرور",
                          isPasswordField: true,
                          showPassword: showPassword,
                          onVisibilityToggle: () {
                            setState(() => showPassword = !showPassword);
                          },
                          validator: (value) =>
                              controller.validatePassword(value ?? ''),
                        ),

                        // رسالة قوة كلمة المرور البسيطة
                        Obx(() {
                          if (controller
                              .passwordStrengthMessage
                              .value
                              .isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            child: Text(
                              controller.passwordStrengthMessage.value,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    controller.passwordStrengthMessage.value
                                        .contains('قوية')
                                    ? Colors.green
                                    : controller.passwordStrengthMessage.value
                                          .contains('متوسطة')
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: controller.confirmPasswordController,
                      label: "تأكيد كلمة المرور",
                      isPasswordField: true,
                      showPassword: showConfirmPassword,
                      onVisibilityToggle: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "يرجى تأكيد كلمة المرور";
                        } else if (value !=
                            controller.passwordController.text) {
                          return "كلمة المرور غير متطابقة";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    Obx(
                      () => Container(
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
                              : () => controller.register(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5EABD6),
                            foregroundColor: Colors.white,
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
                                  "إنشاء حساب",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

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
                              : () => controller.signInWithGoogle(context),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
