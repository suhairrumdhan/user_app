import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/widgets/social_sign_in_button.dart';
import 'package:user_application/auth/auth_services.dart';

// إنشاء Controller خاص بالصفحة
class SignUpController extends GetxController {
  final name = ''.obs;
  final email = ''.obs;
  final password = ''.obs;
  final confirmPassword = ''.obs;
  final phone = ''.obs;
  final age = ''.obs;
  final gender = Rxn<String>();
  final rememberMe = false.obs;
  final isLoading = false.obs;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();

  final authService = AuthService();
}

class SignUpPage extends StatelessWidget {
  SignUpPage({super.key});

  final _formKey = GlobalKey<FormState>();
  final SignUpController controller = Get.put(SignUpController());

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
                        "تسجيل حساب جديد",
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // الاسم الكامل
                      CustomTextField(
                        controller: controller.nameController,
                        label: "الاسم الكامل",
                        onChanged: (value) => controller.name.value = value,
                        validator: (value) => value == null || value.isEmpty
                            ? "يرجى إدخال الاسم"
                            : null,
                      ),
                      // العمر (اختياري)
                      CustomTextField(
                        controller: controller.ageController,
                        label: 'العمر (اختياري)',
                        inputType: TextInputType.number,
                        onChanged: (value) => controller.age.value = value,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final age = int.tryParse(value);
                            if (age == null || age < 0 || age > 120) {
                              return 'يرجى إدخال عمر صالح';
                            }
                          }
                          return null;
                        },
                      ),
                      // الجنس (اختياري)
                      Obx(() => DropdownButtonFormField<String>(
                        value: controller.gender.value,
                        decoration: const InputDecoration(
                          labelText: 'الجنس (اختياري)',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: ['ذكر', 'أنثى']
                            .map((gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ))
                            .toList(),
                        onChanged: (value) {
                          controller.gender.value = value;
                        },
                      )),
                      // رقم الهاتف
                      CustomTextField(
                        controller: controller.phoneController,
                        label: "رقم الهاتف (اختياري)",
                        inputType: TextInputType.phone,
                        onChanged: (value) => controller.phone.value = value,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (value.length < 8) {
                              return "رقم الهاتف قصير جدًا";
                            }
                          }
                          return null;
                        },
                      ),
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
                            return "يجب أن تكون كلمة المرور 6 أحرف على الأقل";
                          }
                          return null;
                        },
                      )),
                      // تأكيد كلمة المرور
                      Obx(() => CustomTextField(
                        controller: controller.confirmPasswordController,
                        label: "تأكيد كلمة المرور",
                        obscure: true,
                        onChanged: (value) => controller.confirmPassword.value = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى تأكيد كلمة المرور";
                          } else if (value != controller.password.value) {
                            return "كلمة المرور غير متطابقة";
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

                      // زر إنشاء الحساب
                      Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () {
                            if (_formKey.currentState!.validate()) {
                              final int? age = controller.age.value.isNotEmpty
                                  ? int.tryParse(controller.age.value)
                                  : null;
                              controller.authService.registerWithEmail(
                                context: context,
                                email: controller.email.value,
                                password: controller.password.value,
                                confirmPassword:
                                controller.confirmPassword.value,
                                name: controller.name.value,
                                gender: controller.gender.value,
                                age: age,
                                phoneNumber: controller.phone.value,
                                setLoading: (loading) =>
                                controller.isLoading.value = loading,
                              );
                            }
                          },
                          child: controller.isLoading.value
                              ? const CircularProgressIndicator()
                              : const Text("إنشاء حساب"),
                        ),
                      )),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      Text(
                        "أو يمكنك التسجيل باستخدام:",
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
