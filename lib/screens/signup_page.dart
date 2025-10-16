import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/auth/auth_services.dart';

// Controller
class SignUpController extends GetxController {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController(); // تمت إضافة كونترولر الهاتف
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;

  final authService = AuthService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<FormState> get formKey => _formKey;

  void register(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      authService.registerWithEmail(
        context: context,
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        confirmPassword: confirmPasswordController.text.trim(),
        phoneNumber: phoneController.text.trim(),
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
    phoneController.dispose(); // تمت إضافة التخلص من كونترولر الهاتف
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}

class SignUpPage extends StatelessWidget {
  SignUpPage({super.key});

  final SignUpController controller = Get.put(SignUpController());

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return CustomScaffold(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height * 0.85, // زيادة الارتفاع لاستيعاب الحقل الجديد
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
                    validator: (value) =>
                    value == null || value.isEmpty ? "يرجى إدخال الاسم" : null,
                  ),

                  CustomTextField(
                    controller: controller.phoneController, // حقل الهاتف المضاف
                    label: "رقم الهاتف",
                    inputType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "يرجى إدخال رقم الهاتف";
                      } else if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
                        return "يرجى إدخال رقم هاتف صحيح";
                      } else if (value.length < 8) {
                        return "رقم الهاتف يجب أن يكون 8 أرقام على الأقل";
                      }
                      return null;
                    },
                  ),

                  CustomTextField(
                    controller: controller.emailController,
                    label: "البريد الإلكتروني",
                    inputType: TextInputType.emailAddress,
                    validator: (value) =>
                    value == null || !value.contains("@")
                        ? "بريد إلكتروني غير صالح"
                        : null,
                  ),
                  CustomTextField(
                    controller: controller.passwordController,
                    label: "كلمة المرور",
                    obscure: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "يرجى إدخال كلمة المرور";
                      } else if (value.length < 6) {
                        return "يجب أن تكون 6 أحرف على الأقل";
                      }
                      return null;
                    },
                  ),
                  CustomTextField(
                    controller: controller.confirmPasswordController,
                    label: "تأكيد كلمة المرور",
                    obscure: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "يرجى تأكيد كلمة المرور";
                      } else if (value != controller.passwordController.text) {
                        return "كلمة المرور غير متطابقة";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.register(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6E8CFB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: controller.isLoading.value
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "إنشاء حساب",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )),

                  const SizedBox(height: 16),

                  Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.signInWithGoogle(context),
                      icon: const Icon(Bootstrap.google, color: Colors.red),
                      label: const Text(
                        "التسجيل باستخدام Google",
                        style: TextStyle(color: Colors.black87),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}