import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';
import '../../family/controllers/family_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../models/beneficiary_model.dart';
import '../models/beneficiary_model.dart';
import '../models/medicine_model.dart';
import '../widgets/beneficiary_selector_sheet.dart';
import 'manual_search_results_page.dart';

class ManualMedicineSearchPage extends StatefulWidget {
  const ManualMedicineSearchPage({super.key});

  @override
  State<ManualMedicineSearchPage> createState() =>
      _ManualMedicineSearchPageState();
}

class _ManualMedicineSearchPageState extends State<ManualMedicineSearchPage> {
  final TextEditingController _medicineController = TextEditingController();
  final FocusNode _medicineFocusNode = FocusNode();
  final UserController _userController = Get.find<UserController>();
  final FamilyController _familyController = Get.find<FamilyController>();
  final List<MedicineModel> _medicines = [];
  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);
  final Color pAccentColor = const Color(0xFF4CAF50);

  void _addMedicine() {
    final text = _medicineController.text.trim();

    if (text.isEmpty) return;

    final exists = _medicines.any(
          (item) => item.name.toLowerCase() == text.toLowerCase(),
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الدواء موجود بالفعل في القائمة'),
        ),
      );
      return;
    }

    setState(() {
      _medicines.add(MedicineModel(name: text));
      _medicineController.clear();
    });

    _medicineFocusNode.requestFocus();
  }
  void _removeMedicine(int index) {
    setState(() {
      _medicines.removeAt(index);
    });
  }

  void _continue() {
    if (_medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضيفي دواءً واحدًا على الأقل للمتابعة'),
        ),
      );
      return;
    }

    _openBeneficiarySelector();
  }


  @override
  void dispose() {
    _medicineController.dispose();
    _medicineFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // -- الحل الأمثل: استخدام resizeToAvoidBottomInset: false --
    return Scaffold(
      backgroundColor: pLightColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: pPrimaryColor),
        title: Text(
          'البحث اليدوي عن دواء',
          style: TextStyle(
            color: pPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      // الحل الأساسي: منع إعادة حجم الشاشة عند ظهور الكيبورد
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                // تبسيط البادينغ لأننا لن نستخدم viewInsets.bottom بنفس الطريقة
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopCard(),
                    const SizedBox(height: 18),
                    _buildInputSection(),
                    const SizedBox(height: 22),
                    _buildMedicinesSection(),
                  ],
                ),
              ),
            ),
            // تمرير 0 لأننا لن نستخدم viewInsets.bottom، وبدلاً من ذلك نعتمد على SingleChildScrollView
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pPrimaryColor,
            pSecondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Iconsax.search_normal_1,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ابحثي عن أكثر من دواء بسهولة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'أضيفي الأدوية التي تريدين البحث عنها، ثم انتقلي لاختيار المستفيد وإكمال الطلب.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BeneficiaryModel> _buildBeneficiaries() {
    final beneficiaries = <BeneficiaryModel>[];

    final currentUser = _userController.user.value;
    if (currentUser != null) {
      beneficiaries.add(
        BeneficiaryModel(
          id: currentUser.id,
          name: currentUser.name.isNotEmpty ? currentUser.name : 'أنا',
          type: 'self',
          relation: 'أنا',
        ),
      );
    } else {
      beneficiaries.add(
        const BeneficiaryModel(
          id: 'self',
          name: 'أنا',
          type: 'self',
          relation: 'أنا',
        ),
      );
    }

    for (final member in _familyController.members) {
      beneficiaries.add(
        BeneficiaryModel(
          id: member.id,
          name: member.name,
          type: 'family',
          relation: member.relation ?? 'فرد من العائلة',
        ),
      );
    }

    return beneficiaries;
  }

  void _openBeneficiarySelector() {
    final beneficiaries = _buildBeneficiaries();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BeneficiarySelectorSheet(
          beneficiaries: beneficiaries,
          onSelected: (beneficiary) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualSearchResultsPage(
                  medicines: _medicines,
                  beneficiary: beneficiary,
                ),
              ),
            );

            // TODO:
            // هنا لاحقًا ننتقل لصفحة النتائج/الفلاتر
            // مع تمرير:
            // - beneficiary
            // - _medicines
          },
        );
      },
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إضافة دواء',
            style: TextStyle(
              color: pPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicineController,
            focusNode: _medicineFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addMedicine(),
            decoration: InputDecoration(
              hintText: 'اكتبي اسم الدواء هنا',
              prefixIcon: Icon(Iconsax.document_text, color: pPrimaryColor),
              suffixIcon: IconButton(
                onPressed: _addMedicine,
                icon: Icon(Iconsax.add_circle, color: pAccentColor),
              ),
              filled: true,
              fillColor: pLightColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: pPrimaryColor.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: pPrimaryColor, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Iconsax.add),
              label: const Text('إضافة إلى القائمة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: pAccentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.box, color: pPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'الأدوية المضافة',
                style: TextStyle(
                  color: pPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_medicines.length}',
                  style: TextStyle(
                    color: pPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_medicines.isEmpty) _buildEmptyState(),
          if (_medicines.isNotEmpty)
            ListView.separated(
              itemCount: _medicines.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildMedicineCard(index, _medicines[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pPrimaryColor.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(
            Iconsax.search_status,
            size: 42,
            color: pPrimaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'لم يتم إضافة أي دواء بعد',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ابدئي بكتابة اسم الدواء ثم اضغطي على زر الإضافة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(int index, MedicineModel medicine) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pPrimaryColor.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pPrimaryColor,
                  pSecondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              medicine.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeMedicine(index),
            icon: const Icon(
              Iconsax.trash,
              color: Colors.redAccent,
            ),
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      // إزالة الاعتماد على bottomPadding وترك padding ثابت
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: pPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'متابعة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}