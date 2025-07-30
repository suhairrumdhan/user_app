import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:user_application/auth/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';

class HealthInfoScreen extends StatefulWidget {
  const HealthInfoScreen({super.key});

  @override
  State<HealthInfoScreen> createState() => _HealthInfoScreenState();
}

class _HealthInfoScreenState extends State<HealthInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  String? bloodType;
  String weight = '';
  String height = '';
  String allergies = '';
  String medications = '';
  List<String> chronicDiseases = [];
  TextEditingController otherDiseaseController = TextEditingController();

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
  final List<String> commonDiseases = [
    'السكري',
    'ضغط الدم',
    'أمراض القلب',
    'الربو',
    'أمراض الكلى',
  ];

  void _toggleDisease(String disease) {
    setState(() {
      if (chronicDiseases.contains(disease)) {
        chronicDiseases.remove(disease);
      } else {
        chronicDiseases.add(disease);
      }
    });
  }

  Future<void> _saveHealthInfo() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('المستخدم غير مسجل الدخول')));
      return;
    }

    try {
      // جمع الأمراض المزمنة
      final allDiseases = List<String>.from(chronicDiseases);
      if (otherDiseaseController.text.trim().isNotEmpty) {
        allDiseases.add(otherDiseaseController.text.trim());
      }

      // تحضير البيانات الصحية
      final Map<String, dynamic> healthData = {
        'healthInfoCompleted': true,
        'bloodType': bloodType,
        'weight': weight.isNotEmpty ? double.tryParse(weight) : null,
        'height': height.isNotEmpty ? double.tryParse(height) : null,
        'healthConditions': allDiseases,
        'allergies': allergies
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'currentMedications': medications
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'lastHealthUpdate': Timestamp.now(),
      };

      // تحديث البيانات في Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .set(healthData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('المعلومات الصحية')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          shadowColor: colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'البيانات الصحية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // فصيلة الدم
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'فصيلة الدم'),
                    items: bloodTypes
                        .map(
                          (bt) => DropdownMenuItem(value: bt, child: Text(bt)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => bloodType = val),
                  ),

                  const SizedBox(height: 16),

                  // الوزن
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'الوزن (كجم)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => weight = val,
                  ),

                  const SizedBox(height: 16),

                  // الطول
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'الطول (سم)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => height = val,
                  ),

                  const SizedBox(height: 16),

                  // الحساسية
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'الحساسية (افصل بين الأنواع بفاصلة)',
                    ),
                    onChanged: (val) => allergies = val,
                  ),

                  const SizedBox(height: 16),

                  // الأدوية الحالية
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'الأدوية الحالية (افصل بين الأنواع بفاصلة)',
                    ),
                    onChanged: (val) => medications = val,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'الأمراض المزمنة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: commonDiseases.map((disease) {
                      final selected = chronicDiseases.contains(disease);
                      return FilterChip(
                        label: Text(disease),
                        selected: selected,
                        onSelected: (_) => _toggleDisease(disease),
                        selectedColor: colorScheme.primary,
                        checkmarkColor: colorScheme.primary,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // أمراض أخرى
                  TextFormField(
                    controller: otherDiseaseController,
                    decoration: const InputDecoration(
                      labelText: 'أمراض أخرى (اختياري)',
                    ),
                  ),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    onPressed: _saveHealthInfo,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ المعلومات'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
