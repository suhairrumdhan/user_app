import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/auth_services.dart';
import '../../controllers/user_controller.dart';
import '../../auth/user_repository.dart';
import '../../widgets/custom_text_field.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserController userController = Get.find<UserController>();
  final AuthService _authService = AuthService();
  final UserRepository _userRepo = UserRepository.instance;

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    final user = userController.user.value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userModel = userController.user.value;
      if (user == null || userModel == null) return;

      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final newPhone = _phoneController.text.trim();
      final newPassword = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (newName.isNotEmpty && newName != userModel.name) {
        await _userRepo.updateUserFields(userModel.id, {'name': newName});
        await user.updateDisplayName(newName);
      }
      if (newEmail.isNotEmpty && newEmail != userModel.email) {
        await user.updateEmail(newEmail);
        await _userRepo.updateUserFields(userModel.id, {'email': newEmail});
      }
      if (newPhone.isNotEmpty && newPhone != userModel.phone) {
        await _userRepo.updateUserFields(userModel.id, {'phone': newPhone});
      }
      if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
        if (newPassword != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كلمة المرور وتأكيدها غير متطابقين')),
          );
          return;
        }
        await user.updatePassword(newPassword);
      }

      await userController.loadUser(userModel.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ التغييرات بنجاح')),
      );

      Get.back();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ غير متوقع: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = userController.user.value;

    return Scaffold(
      backgroundColor: Colors.white, // الخلفية العامة بيضاء
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, // البوكس أبيض
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.transparent, // إزالة الحدود الرمادية
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  inputType: TextInputType.text,
                  validator: (value) =>
                  value == null || value.isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  inputType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                    if (!value.contains('@')) return 'بريد إلكتروني غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور الجديدة',
                  obscure: !_showPassword,
                  isPasswordField: true,
                  showPassword: _showPassword,
                  onVisibilityToggle: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'تأكيد كلمة المرور',
                  obscure: !_showConfirmPassword,
                  isPasswordField: true,
                  showPassword: _showConfirmPassword,
                  onVisibilityToggle: () {
                    setState(() => _showConfirmPassword = !_showConfirmPassword);
                  },
                ),
                const SizedBox(height: 8),
                // زر الحفظ
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5EABD6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text(
                      'حفظ التغييرات',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
