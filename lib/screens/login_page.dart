import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/widgets/custom_scaffold.dart';
import 'package:user_application/widgets/custom_text_field.dart';
import 'package:user_application/widgets/social_sign_in_button.dart';
import 'package:user_application/auth/auth_services.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
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
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: emailController,
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
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: passwordController,
                        label: "كلمة المرور",
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            // TODO: إضافة صفحة استعادة كلمة المرور
                          },
                          child: const Text("نسيت كلمة المرور؟"),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    authService.loginWithEmail(
                                      context: context,
                                      email: emailController.text,
                                      password: passwordController.text,
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
                              : const Text("تسجيل الدخول"),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      Text(
                        "أو يمكنك تسجيل الدخول باستخدام:",
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
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("ليس لديك حساب؟"),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FullSignUpPage(),
                                ),
                              );
                            },
                            child: const Text("إنشاء حساب جديد"),
                          ),
                        ],
                      ),
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
