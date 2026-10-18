import '../../../shared/libya_phone.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/user_controller.dart';
import '../../auth/services/user_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserController userController = Get.find<UserController>();
  final UserRepository _userRepo = UserRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _loading = false.obs;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthDateController;
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

    _updateControllersFromUser();
  }

  void _updateControllersFromUser() {
    final user = userController.user.value;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';

      if (user.dateOfBirth != null) {
        _selectedBirthDate.value = user.dateOfBirth;
        _birthDateController.text = DateFormat(
          'yyyy/MM/dd',
        ).format(user.dateOfBirth!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthDate.value ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
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
      final newPhone = LibyaPhone.normalize(_phoneController.text);
      final newBirthDate = _selectedBirthDate.value;

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

      await userController.loadUser(userModel.id);
      _showSuccess('تم حفظ التغييرات.');

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('تعذر حفظ البيانات. أعد المحاولة.');
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "معلومات شخصية",
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
    return _buildInfoCard(
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
          validator: (value) => LibyaPhone.validate(value, required: false),
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
    );
  }

  Widget _buildSaveButton() {
    return Obx(
      () => Container(
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.user_edit,
                    color: pPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'المعلومات الشخصية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
            suffixIcon: Icon(
              Iconsax.calendar_1,
              color: pPrimaryColor,
              size: 18,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
