import 'package:flutter/material.dart' hide SearchController;
import 'package:iconsax/iconsax.dart';
import 'package:get/get.dart';

import '../../family/controllers/family_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../../search/models/medicine_search_request.dart';
import '../../search/controllers/search_controller.dart';
import '../../search/services/medicine_normalizer.dart';
import '../models/beneficiary_model.dart';
import '../models/medicine_model.dart';
import '../widgets/beneficiary_selector_sheet.dart';
import 'search_results_page.dart';

class ManualMedicineSearchPage extends StatefulWidget {
  final List<MedicineModel>? initialMedicines;
  final String searchSource; // manual | prescription
  final bool isReviewMode;

  const ManualMedicineSearchPage({
    super.key,
    this.initialMedicines,
    this.searchSource = 'manual',
    this.isReviewMode = false,
  });

  @override
  State<ManualMedicineSearchPage> createState() =>
      _ManualMedicineSearchPageState();
}

class _ManualMedicineSearchPageState extends State<ManualMedicineSearchPage> {
  final TextEditingController _medicineController = TextEditingController();
  final FocusNode _medicineFocusNode = FocusNode();

  final UserController _userController = Get.find<UserController>();
  final FamilyController _familyController = Get.find<FamilyController>();

  late final SearchController _searchController;

  final List<MedicineModel> _medicines = [];

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);
  final Color pAccentColor = const Color(0xFF4CAF50);
  final Color pWarningColor = const Color(0xFFF59E0B);

  bool get _isPrescriptionMode => widget.searchSource == 'prescription';

  @override
  void initState() {
    super.initState();

    _searchController = Get.isRegistered<SearchController>()
        ? Get.find<SearchController>()
        : Get.put(SearchController());

    if (widget.initialMedicines != null && widget.initialMedicines!.isNotEmpty) {
      _medicines.addAll(widget.initialMedicines!);
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _medicineFocusNode.dispose();
    super.dispose();
  }

  void _addMedicine() {
    final text = _medicineController.text.trim();
    if (text.isEmpty) return;

    final exists = _medicines.any(
          (item) => item.name.toLowerCase().trim() == text.toLowerCase().trim(),
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

  List<MedicineSearchRequest> _buildRequestsFromMedicines() {
    return _medicines.map((medicine) {
      final raw = medicine.displayName.trim();

      return MedicineSearchRequest(
        rawText: raw,
        normalizedText: MedicineNormalizer.normalize(raw),
        strength: MedicineNormalizer.extractStrength(raw),
        dosageForm: MedicineNormalizer.extractDosageForm(raw),
      );
    }).toList();
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

    // ✅ في وضع المراجعة: فقط نرجع القائمة المعدلة
    if (widget.isReviewMode) {
      Navigator.pop(context, List<MedicineModel>.from(_medicines));
      return;
    }

    // ✅ في الوضع العادي: نكمل اختيار المستفيد ثم النتائج
    _openBeneficiarySelector();
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
            final requests = _buildRequestsFromMedicines();

            _searchController.clearAll();
            _searchController.setSearchSource(widget.searchSource);
            _searchController.setBeneficiary(beneficiary);
            _searchController.setRequests(requests);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchResultsPage(
                  medicines: List<MedicineModel>.from(_medicines),
                  beneficiary: beneficiary,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String get _pageTitle {
    if (widget.isReviewMode && _isPrescriptionMode) {
      return 'مراجعة الأدوية المستخرجة';
    }
    return 'البحث اليدوي عن دواء';
  }

  String get _topTitle {
    if (widget.isReviewMode && _isPrescriptionMode) {
      return 'راجعي الأدوية المستخرجة من الوصفة';
    }
    return 'ابحثي عن أكثر من دواء بسهولة';
  }

  String get _topSubtitle {
    if (widget.isReviewMode && _isPrescriptionMode) {
      return 'يمكنك حذف أي دواء غير صحيح، وإضافة أدوية أخرى قبل متابعة البحث.';
    }
    return 'أضيفي الأدوية التي تريدين البحث عنها، ثم انتقلي لاختيار المستفيد وإكمال الطلب.';
  }

  String get _bottomButtonText {
    if (widget.isReviewMode && _isPrescriptionMode) {
      return 'اعتماد الأدوية والمتابعة';
    }
    return 'متابعة';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pLightColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: pPrimaryColor),
        title: Text(
          _pageTitle,
          style: TextStyle(
            color: pPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    final topColor = widget.isReviewMode ? pWarningColor : pPrimaryColor;
    final secondColor = widget.isReviewMode ? const Color(0xFFFBBF24) : pSecondaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            topColor,
            secondColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: topColor.withOpacity(0.22),
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
            child: Icon(
              widget.isReviewMode ? Iconsax.document_text : Iconsax.search_normal_1,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _topTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _topSubtitle,
                  style: const TextStyle(
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
            widget.isReviewMode ? 'إضافة/تعديل دواء' : 'إضافة دواء',
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
              label: Text(widget.isReviewMode ? 'إضافة دواء آخر' : 'إضافة إلى القائمة'),
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
                widget.isReviewMode ? 'الأدوية بعد المراجعة' : 'الأدوية المضافة',
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
            widget.isReviewMode
                ? 'راجعي القائمة أو أضيفي دواءً جديدًا'
                : 'لم يتم إضافة أي دواء بعد',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isReviewMode
                ? 'يمكنك تعديل النتائج المستخرجة قبل متابعة البحث'
                : 'ابدئي بكتابة اسم الدواء ثم اضغطي على زر الإضافة',
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
              backgroundColor: widget.isReviewMode ? pWarningColor : pPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              _bottomButtonText,
              style: const TextStyle(
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