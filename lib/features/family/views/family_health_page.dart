import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/family_controller.dart';

class FamilyHealthPage extends StatefulWidget {
  final String memberId;

  const FamilyHealthPage({super.key, required this.memberId});

  @override
  State<FamilyHealthPage> createState() => _FamilyHealthPageState();
}

class _FamilyHealthPageState extends State<FamilyHealthPage> {

  final controller = Get.find<FamilyController>();

  final bloodType = TextEditingController();
  final allergies = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final member = await controller.getMember(widget.memberId);

    if (member != null) {
      bloodType.text = member.bloodType ?? '';
      allergies.text = member.allergies.join(',');
    }

    loading = false;
    setState(() {});
  }

  Future<void> save() async {
    setState(() => loading = true);

    final member = await controller.getMember(widget.memberId);

    if (member == null) return;

    member.bloodType = bloodType.text;
    member.allergies = allergies.text.split(',');

    await controller.updateMember(member);

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("الملف الصحي")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: bloodType,
              decoration: const InputDecoration(labelText: "فصيلة الدم"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: allergies,
              decoration: const InputDecoration(labelText: "الحساسية"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: save,
              child: const Text("حفظ"),
            )
          ],
        ),
      ),
    );
  }
}