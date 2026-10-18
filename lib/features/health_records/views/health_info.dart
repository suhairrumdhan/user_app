import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:user_application/features/pharmacy/views/home_page.dart';
import '../../profile/controllers/user_controller.dart';
import '../../../app/core/widgets/custom_dropdown_field.dart';
import '../../../app/core/widgets/custom_text_field.dart';

class HealthInfoScreen extends StatefulWidget {
  const HealthInfoScreen({super.key});

  @override
  State<HealthInfoScreen> createState() => _HealthInfoScreenState();
}

class _HealthInfoScreenState extends State<HealthInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserController userController = Get.find<UserController>();

  String? bloodType;
  String? gender;
  DateTime? dateOfBirth;
  String phone = '';
  String allergies = '';
  String medications = '';
  List<String> chronicDiseases = [];
  final TextEditingController otherDiseaseController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  final List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  final List<String> genders = ['ذكر', 'أنثى'];
  final List<String> commonDiseases = [
    'السكري',
    'ضغط الدم',
    'أمراض القلب',
    'الربو',
    'أمراض الكلى',
  ];

  @override
  void initState() {
    super.initState();

    final user = userController.user.value;
    if (user != null) {
      bloodType = user.bloodType;
      gender = user.gender;
      dateOfBirth = user.dateOfBirth;
      phone = user.phone ?? '';
      allergies = user.allergies.join(', ');
      medications = user.currentMedications.join(', ');
      chronicDiseases = List.from(user.healthConditions);
      if (dateOfBirth != null) {
        dateController.text =
            "${dateOfBirth!.year}-${dateOfBirth!.month}-${dateOfBirth!.day}";
      }
    }
  }

  void _toggleDisease(String disease) {
    setState(() {
      if (chronicDiseases.contains(disease)) {
        chronicDiseases.remove(disease);
      } else {
        chronicDiseases.add(disease);
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selectedDate != null) {
      setState(() {
        dateOfBirth = selectedDate;
        dateController.text =
            "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
      });
    }
  }

  Future<void> _saveHealthInfo() async {
    try {
      final allDiseases = List<String>.from(chronicDiseases);
      if (otherDiseaseController.text.trim().isNotEmpty) {
        allDiseases.add(otherDiseaseController.text.trim());
      }

      final allergiesList = allergies
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final medicationsList = medications
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await userController.updateHealthInfo(
        bloodType: bloodType,
        gender: gender,
        dateOfBirth: dateOfBirth,
        phone: phone.isNotEmpty ? phone : null,
        healthConditions: allDiseases,
        allergies: allergiesList,
        currentMedications: medicationsList,
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في حفظ المعلومات')));
    }
  }

  Future<void> _skipHealthInfo() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعلومات الصحية'),
        actions: [
          TextButton(
            onPressed: _skipHealthInfo,
            child: const Text('تخطي', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text('خطوة اختيارية', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            CustomDropdownField<String>(
              label: 'فصيلة الدم',
              value: bloodType,
              items: bloodTypes
                  .map((bt) => DropdownMenuItem(value: bt, child: Text(bt)))
                  .toList(),
              onChanged: (val) => setState(() => bloodType = val),
              icon: OctIcons
                  .code_of_conduct, // ✅ Pass IconData directly (no Icon wrapper)
            ),

            CustomDropdownField<String>(
              label: 'الجنس',
              value: gender,
              items: genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) => setState(() => gender = val),
              icon: Iconsax
                  .man_outline, // ✅ Pass IconData directly (no Icon wrapper)
            ),
            // تاريخ الميلاد
            CustomTextField(
              controller: dateController,
              label: 'تاريخ الميلاد',
              inputType: TextInputType.datetime,
              onChanged: (_) {},
              onVisibilityToggle: null,
              showPassword: false,
              icon: Icons.calendar_month,
              obscure: false,
              isPasswordField: false,
              onTap: _pickDateOfBirth,
            ),
            const SizedBox(height: 16),

            // الحساسية
            CustomTextField(
              controller: TextEditingController(text: allergies),
              label: 'الحساسية (افصل بين الأنواع بفاصلة)',
              inputType: TextInputType.text,
              onChanged: (val) => allergies = val,
            ),
            const SizedBox(height: 16),

            // الأدوية الحالية
            CustomTextField(
              controller: TextEditingController(text: medications),
              label: 'الأدوية الحالية (افصل بين الأنواع بفاصلة)',
              inputType: TextInputType.text,
              onChanged: (val) => medications = val,
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: otherDiseaseController,
              label: 'الأمراض المزمنة والحالات الصحية',
              inputType: TextInputType.text,
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _saveHealthInfo,
              icon: const Icon(EvaIcons.checkmark),
              label: const Text('حفظ المعلومات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EABD6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _skipHealthInfo,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text(
                'تخطي الآن',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
