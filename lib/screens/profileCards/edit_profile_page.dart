import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

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
  final _loading = false.obs;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  final _showCurrentPassword = false.obs;
  final _showPassword = false.obs;
  final _showConfirmPassword = false.obs;
  final _isPersonalInfoExpanded = false.obs;
  final _isPasswordExpanded = false.obs;
  final _selectedBirthDate = Rx<DateTime?>(null);

  // اللون الرئيسي المطابق لصفحة البروفايل
  final Color pPrimaryColor = const Color(0xFF5EABD6);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _birthDateController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _updateControllersFromUser();
  }

  void _updateControllersFromUser() {
    final user = userController.user.value;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';

      if (user.dateOfBirth != null) {
        _selectedBirthDate.value = user.dateOfBirth;
        _birthDateController.text = DateFormat('yyyy/MM/dd').format(user.dateOfBirth!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
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

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate.value ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5EABD6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate.value) {
      _selectedBirthDate.value = picked;
      _birthDateController.text = DateFormat('yyyy/MM/dd').format(picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    _loading.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userModel = userController.user.value;
      if (user == null || userModel == null) return;

      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      final newBirthDate = _selectedBirthDate.value;
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      final Map<String, dynamic> updates = {};

      if (newName.isNotEmpty && newName != userModel.name) {
        updates['name'] = newName;
        await user.updateDisplayName(newName);
      }

      if (newPhone.isNotEmpty && newPhone != userModel.phone) {
        updates['phone'] = newPhone;
      }

      if (newBirthDate != null && newBirthDate != userModel.dateOfBirth) {
        updates['dateOfBirth'] = newBirthDate;
      }

      if (updates.isNotEmpty) {
        await _userRepo.updateUserFields(userModel.id, updates);
      }

      if (_isPasswordExpanded.value && newPassword.isNotEmpty) {
        if (currentPassword.isEmpty) {
          _showError('يرجى إدخال كلمة المرور الحالية');
          return;
        }

        if (newPassword != confirmPassword) {
          _showError('كلمة المرور وتأكيدها غير متطابقين');
          return;
        }

        final isCurrentPasswordValid = await _verifyCurrentPassword(currentPassword);
        if (!isCurrentPasswordValid) {
          _showError('كلمة المرور الحالية غير صحيحة');
          return;
        }

        await user.updatePassword(newPassword);
      }

      await userController.loadUser(userModel.id);
      _showSuccess('تم حفظ التغييرات بنجاح');

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('خطأ غير متوقع: ${e.toString()}');
    } finally {
      if (mounted) {
        _loading.value = false;
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (userController.user.value == null) {
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(pPrimaryColor),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: pPrimaryColor,
        body: SafeArea(
          child: Column(
            children: [
              // AppBar بنفس تصميم ProfilePage
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "تعديل الملف الشخصي",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // المحتوى مع البوكس الأبيض
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [

                        // بطاقة المعلومات الشخصية
                        _buildPersonalInfoCard(),
                        const SizedBox(height: 16),

                        // بطاقة تغيير كلمة المرور
                        _buildPasswordCard(),
                        const SizedBox(height: 30),

                        // زر الحفظ
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }


  Widget _buildPersonalInfoCard() {
    return Obx(() => _buildExpandableCard(
      title: 'المعلومات الشخصية',
      icon: Iconsax.user_edit,
      isExpanded: _isPersonalInfoExpanded.value,
      onToggle: () => _isPersonalInfoExpanded.toggle(),
      children: [
        _buildModernTextField(
          controller: _nameController,
          label: 'الاسم الكامل',
          icon: Iconsax.user,
          validator: (value) =>
          value == null || value.isEmpty ? 'يرجى إدخال الاسم' : null,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _phoneController,
          label: 'رقم الهاتف',
          icon: Iconsax.call,
          inputType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: _birthDateController,
          label: 'تاريخ الميلاد',
          icon: Iconsax.calendar,
          onTap: () => _selectBirthDate(context),
        ),
      ],
    ));
  }

  Widget _buildPasswordCard() {
    return Obx(() => _buildExpandableCard(
      title: 'تغيير كلمة المرور',
      icon: Iconsax.lock,
      isExpanded: _isPasswordExpanded.value,
      onToggle: () => _isPasswordExpanded.toggle(),
      children: [
        Obx(() => _buildModernPasswordField(
          controller: _currentPasswordController,
          label: 'كلمة المرور الحالية',
          showPassword: _showCurrentPassword.value,
          onToggle: () => _showCurrentPassword.toggle(),
          validator: (value) {
            if (_isPasswordExpanded.value && (value == null || value.isEmpty)) {
              return 'يرجى إدخال كلمة المرور الحالية';
            }
            return null;
          },
        )),
        const SizedBox(height: 16),
        Obx(() => _buildModernPasswordField(
          controller: _passwordController,
          label: 'كلمة المرور الجديدة',
          showPassword: _showPassword.value,
          onToggle: () => _showPassword.toggle(),
          validator: (value) {
            if (_isPasswordExpanded.value && (value == null || value.isEmpty)) {
              return 'يرجى إدخال كلمة المرور الجديدة';
            }
            if (_isPasswordExpanded.value && value != null && value.length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        )),
        const SizedBox(height: 16),
        Obx(() => _buildModernPasswordField(
          controller: _confirmPasswordController,
          label: 'تأكيد كلمة المرور',
          showPassword: _showConfirmPassword.value,
          onToggle: () => _showConfirmPassword.toggle(),
          validator: (value) {
            if (_isPasswordExpanded.value && (value == null || value.isEmpty)) {
              return 'يرجى تأكيد كلمة المرور';
            }
            if (_isPasswordExpanded.value && value != _passwordController.text) {
              return 'كلمة المرور غير متطابقة';
            }
            return null;
          },
        )),
      ],
    ));
  }

  Widget _buildSaveButton() {
    return Obx(() => Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: pPrimaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading.value ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: pPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading.value
            ? const SizedBox(
          height: 22,
          width: 22,
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
    ));
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: pPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: pPrimaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Iconsax.arrow_up_1 : Iconsax.arrow_down_1,
                      color: pPrimaryColor,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: children),
            ),
          ],
        ],
      ),
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
      style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
        prefixIcon: Icon(icon, color: pPrimaryColor, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pPrimaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
            prefixIcon: Icon(icon, color: pPrimaryColor, size: 20),
            suffixIcon: Icon(Iconsax.calendar_1, color: pPrimaryColor, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: pPrimaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
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
      style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13),
        prefixIcon: Icon(Iconsax.lock, color: pPrimaryColor, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Iconsax.eye_slash : Iconsax.eye,
            color: pPrimaryColor,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pPrimaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}