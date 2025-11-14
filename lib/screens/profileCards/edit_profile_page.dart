import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/auth_services.dart';
import '../../controllers/user_controller.dart';
import '../../auth/user_repository.dart';

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
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // متغيرات للتحكم في فتح الأقسام
  bool _isPersonalInfoExpanded = false;
  bool _isPasswordExpanded = false;

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
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _verifyCurrentPassword(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
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
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      // تحديث المعلومات الأساسية
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

      // التحقق من تغيير كلمة المرور
      if (_isPasswordExpanded && newPassword.isNotEmpty) {
        if (currentPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال كلمة المرور الحالية')),
          );
          return;
        }

        if (newPassword != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كلمة المرور وتأكيدها غير متطابقين')),
          );
          return;
        }

        // التحقق من كلمة المرور الحالية
        final isCurrentPasswordValid = await _verifyCurrentPassword(currentPassword);
        if (!isCurrentPasswordValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كلمة المرور الحالية غير صحيحة')),
          );
          return;
        }

        // تغيير كلمة المرور
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            // child: IconButton(
            //   icon: const Icon(
            //     Icons.check_rounded,
            //     color: Color(0xFF1877F2),
            //     size: 24,
            //   ),
            //   onPressed: _loading ? null : _saveChanges,
            //),
          ),
        ],
      ),
      body: user == null
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Personal Info Card - قابلة للفتح
            _buildExpandableCard(
              title: 'المعلومات الشخصية',
              isExpanded: _isPersonalInfoExpanded,
              onToggle: () => setState(() => _isPersonalInfoExpanded = !_isPersonalInfoExpanded),
              children: [
                // عرض المعلومات الحالية كنص
                _buildInfoRow('الاسم الكامل', user.name ?? 'غير محدد', Icons.person_outline_rounded),
                const SizedBox(height: 16),
                _buildInfoRow('البريد الإلكتروني', user.email ?? 'غير محدد', Icons.email_outlined),
                const SizedBox(height: 16),
                _buildInfoRow('رقم الهاتف', user.phone ?? 'غير محدد', Icons.phone_iphone_rounded),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // حقول التعديل (تظهر فقط عند الفتح)
                _buildModernTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل الجديد',
                  icon: Icons.person_outline_rounded,
                  validator: (value) =>
                  value == null || value.isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني الجديد',
                  icon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                    if (!value.contains('@')) return 'بريد إلكتروني غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف الجديد',
                  icon: Icons.phone_iphone_rounded,
                  inputType: TextInputType.phone,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Password Card - قابلة للفتح
            _buildExpandableCard(
              title: 'كلمة المرور',
              isExpanded: _isPasswordExpanded,
              onToggle: () => setState(() => _isPasswordExpanded = !_isPasswordExpanded),
              children: [
                // حقول كلمة المرور (تظهر فقط عند الفتح)
                _buildModernPasswordField(
                  controller: _currentPasswordController,
                  label: 'كلمة المرور الحالية',
                  showPassword: _showCurrentPassword,
                  onToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                  validator: (value) {
                    if (_isPasswordExpanded && (value == null || value.isEmpty)) {
                      return 'يرجى إدخال كلمة المرور الحالية';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildModernPasswordField(
                  controller: _passwordController,
                  label: 'كلمة المرور الجديدة',
                  showPassword: _showPassword,
                  onToggle: () => setState(() => _showPassword = !_showPassword),
                  validator: (value) {
                    if (_isPasswordExpanded && (value == null || value.isEmpty)) {
                      return 'يرجى إدخال كلمة المرور الجديدة';
                    }
                    if (_isPasswordExpanded && value != null && value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildModernPasswordField(
                  controller: _confirmPasswordController,
                  label: 'تأكيد كلمة المرور',
                  showPassword: _showConfirmPassword,
                  onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  validator: (value) {
                    if (_isPasswordExpanded && (value == null || value.isEmpty)) {
                      return 'يرجى تأكيد كلمة المرور';
                    }
                    if (_isPasswordExpanded && value != _passwordController.text) {
                      return 'كلمة المرور غير متطابقة';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            Container(
              width: double.infinity,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _loading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'حفظ التغييرات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ويدجت لعرض البطاقة القابلة للفتح
  Widget _buildExpandableCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة مع السهم
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                title == 'المعلومات الشخصية'
                    ? Icons.person_outline_rounded
                    : Icons.lock_outline_rounded,
                color: const Color(0xFF1877F2),
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF1877F2),
              size: 24,
            ),
            onTap: onToggle,
          ),

          // المحتوى (يظهر فقط عند الفتح)
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ويدجت لعرض المعلومات الحالية كنص
  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1877F2)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildModernPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Colors.grey,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1877F2)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}