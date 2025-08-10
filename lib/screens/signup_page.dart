import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/widgets/social_sign_in_button.dart';
import 'package:user_application/auth/auth_services.dart';

class FullSignUpPage extends StatefulWidget {
  const FullSignUpPage({super.key});

  @override
  State<FullSignUpPage> createState() => _FullSignUpPageState();
}

class _FullSignUpPageState extends State<FullSignUpPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedGender;
  final _formKey = GlobalKey<FormState>();
  bool rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final authService = AuthService();

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

                      CustomTextField(
                        controller: nameController,
                        label: "الاسم الكامل",
                        validator: (value) => value == null || value.isEmpty
                            ? "يرجى إدخال الاسم"
                            : null,
                      ),
                      CustomTextField(
                        controller: ageController,
                        label: 'العمر (اختياري)',
                        inputType: TextInputType.number,
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
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'الجنس (اختياري)',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: ['ذكر', 'أنثى']
                            .map(
                              (gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedGender = value;
                          });
                        },
                      ),

                      CustomTextField(
                        controller: phoneController,
                        label: "رقم الهاتف (اختياري)",
                        inputType: TextInputType.phone,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (value.length < 8) {
                              return "رقم الهاتف قصير جدًا";
                            }
                          }
                          return null;
                        },
                      ),

                      CustomTextField(
                        controller: emailController,
                        label: "البريد الإلكتروني",
                        inputType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || !value.contains("@")
                            ? "بريد إلكتروني غير صالح"
                            : null,
                      ),
                      CustomTextField(
                        controller: passwordController,
                        label: "كلمة المرور",
                        obscure: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى إدخال كلمة المرور";
                          } else if (value.length < 6) {
                            return "يجب أن تكون كلمة المرور 6 أحرف على الأقل";
                          }
                          return null;
                        },
                        hintText: "6 أحرف على الأقل",
                        isPasswordField: true,
                        showPassword: !_obscurePassword,
                        onVisibilityToggle: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      CustomTextField(
                        controller: confirmPasswordController,
                        label: "تأكيد كلمة المرور",
                        obscure: _obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى تأكيد كلمة المرور";
                          } else if (value != passwordController.text) {
                            return "كلمة المرور غير متطابقة";
                          }
                          return null;
                        },
                        isPasswordField: true,
                        showPassword: !_obscureConfirmPassword,
                        onVisibilityToggle: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),

                      // Remember Me Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            onChanged: (value) {
                              setState(() {
                                rememberMe = value!;
                              });
                            },
                          ),
                          const Text("تذكر كلمة المرور"),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    // تحويل العمر إن وُجد إلى int
                                    final int? age =
                                        ageController.text.isNotEmpty
                                        ? int.tryParse(ageController.text)
                                        : null;

                                    authService.registerWithEmail(
                                      context: context,
                                      email: emailController.text,
                                      password: passwordController.text,
                                      confirmPassword:
                                          confirmPasswordController.text,
                                      name: nameController.text,
                                      gender: selectedGender,
                                      age: age,
                                      phoneNumber: phoneController.text,

                                      // تم تمرير رقم الهاتف
                                      setLoading: (isLoading) {
                                        setState(() {
                                          _isLoading = isLoading;
                                        });
                                      },
                                    );
                                  }
                                },
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text("إنشاء حساب"),
                        ),
                      ),

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
                            onPressed: () => authService.signInWithGoogle(
                              context,
                              (isLoading) {
                                setState(() {
                                  _isLoading = isLoading;
                                });
                              },
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

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
