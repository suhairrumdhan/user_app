import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../family/controllers/family_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../../saved_prescriptions/services/saved_prescription_service.dart';
import '../../search/models/medicine_search_request.dart';
import '../../search/models/medicine_suggestion.dart';
import '../../search/controllers/search_controller.dart';
import '../../search/services/medicine_normalizer.dart';
import '../../search/services/medicine_identity.dart';
import '../../search/services/medicine_suggestion_service.dart';
import '../models/beneficiary_model.dart';
import '../models/medicine_model.dart';
import '../services/manual_medicine_analysis_service.dart';
import '../widgets/beneficiary_selector_sheet.dart';
import 'search_results_page.dart';

class ManualMedicineSearchPage extends StatefulWidget {
  final List<MedicineModel>? initialMedicines;
  final String searchSource; // manual | prescription
  final bool isReviewMode;

  // ملف الوصفة عند بدء البحث من صورة أو PDF.
  final File? prescriptionFile;
  final String? prescriptionFileType; // image | pdf
  final bool returnEditedMedicines;

  const ManualMedicineSearchPage({
    super.key,
    this.initialMedicines,
    this.searchSource = 'manual',
    this.isReviewMode = false,
    this.prescriptionFile,
    this.prescriptionFileType,
    this.returnEditedMedicines = false,
  });

  @override
  State<ManualMedicineSearchPage> createState() =>
      _ManualMedicineSearchPageState();
}

class _ManualMedicineSearchPageState extends State<ManualMedicineSearchPage> {
  final TextEditingController _medicineController = TextEditingController();
  final FocusNode _medicineFocusNode = FocusNode();
  final MedicineSuggestionService _suggestionService =
      MedicineSuggestionService();
  final ManualMedicineAnalysisService _manualAnalysisService =
      ManualMedicineAnalysisService();
  final List<ManualMedicineAnalysis> _manualAnalysis = [];
  bool _manualReviewStarted = false;
  bool _isAnalyzingManual = false;
  Timer? _suggestionDebounce;
  List<MedicineSuggestion> _suggestions = const [];
  bool _isLoadingSuggestions = false;
  int _suggestionRequestId = 0;
  int? _editingMedicineIndex;
  int? _expandedSuggestionIndex;

  final UserController _userController = Get.find<UserController>();
  final FamilyController _familyController = Get.find<FamilyController>();

  late final SearchController _searchController;

  final List<MedicineModel> _medicines = [];

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);
  final Color pAccentColor = const Color(0xFF4CAF50);
  final Color pSuggestionColor = const Color(0xFFF59E0B);
  bool get _isPrescriptionMode => widget.searchSource == 'prescription';

  @override
  void initState() {
    super.initState();

    _searchController = Get.isRegistered<SearchController>()
        ? Get.find<SearchController>()
        : Get.put(SearchController());

    if (widget.initialMedicines != null &&
        widget.initialMedicines!.isNotEmpty) {
      _medicines.addAll(widget.initialMedicines!);
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _medicineController.dispose();
    _medicineFocusNode.dispose();
    super.dispose();
  }

  void _addMedicine() {
    final text = _medicineController.text.trim();
    if (text.isEmpty) return;

    final normalizedText = MedicineNormalizer.normalize(text);
    final exists = _medicines.asMap().entries.any(
      (entry) =>
          entry.key != _editingMedicineIndex &&
          MedicineNormalizer.normalize(entry.value.name) == normalizedText,
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الدواء موجود بالفعل في القائمة')),
      );
      return;
    }

    setState(() {
      final editingIndex = _editingMedicineIndex;
      if (editingIndex == null) {
        _medicines.add(MedicineModel(name: text));
        if (_manualReviewStarted) {
          _manualAnalysis.add(ManualMedicineAnalysis.manual(text));
        }
      } else {
        _medicines[editingIndex] = MedicineModel(name: text);
        if (_manualReviewStarted) {
          _manualAnalysis[editingIndex] = ManualMedicineAnalysis.manual(text);
        }
      }
      _editingMedicineIndex = null;
      _expandedSuggestionIndex = null;
      _medicineController.clear();
      _suggestions = const [];
      _isLoadingSuggestions = false;
    });

    _medicineFocusNode.requestFocus();
  }

  void _startEditingMedicine(int index) {
    final name = _medicines[index].displayName;
    _medicineController.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() {
      _editingMedicineIndex = index;
      _expandedSuggestionIndex = null;
      _suggestions = const [];
    });
    _medicineFocusNode.requestFocus();
    _onMedicineQueryChanged(name);
  }

  void _cancelMedicineEditing() {
    _suggestionDebounce?.cancel();
    _suggestionRequestId++;
    setState(() {
      _editingMedicineIndex = null;
      _expandedSuggestionIndex = null;
      _medicineController.clear();
      _suggestions = const [];
      _isLoadingSuggestions = false;
    });
    _medicineFocusNode.requestFocus();
  }

  void _onMedicineQueryChanged(String value) {
    _suggestionDebounce?.cancel();
    final requestId = ++_suggestionRequestId;
    final normalized = MedicineNormalizer.normalize(value).replaceAll(' ', '');
    if (normalized.length < 2) {
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadMedicineSuggestions(value, requestId),
    );
  }

  Future<void> _loadMedicineSuggestions(String query, int requestId) async {
    try {
      final suggestions = await _suggestionService.fetchSuggestions(query);
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _suggestions = const [];
        _isLoadingSuggestions = false;
      });
    }
  }

  void _selectSuggestion(MedicineSuggestion suggestion) {
    _suggestionDebounce?.cancel();
    _suggestionRequestId++;
    _medicineController.value = TextEditingValue(
      text: suggestion.medicineName,
      selection: TextSelection.collapsed(
        offset: suggestion.medicineName.length,
      ),
    );
    _addMedicine();
  }

  void _removeMedicine(int index) {
    if (_editingMedicineIndex == index) {
      _suggestionDebounce?.cancel();
      _suggestionRequestId++;
    }
    setState(() {
      _medicines.removeAt(index);
      if (_manualReviewStarted) _manualAnalysis.removeAt(index);
      final expandedIndex = _expandedSuggestionIndex;
      if (expandedIndex == index) {
        _expandedSuggestionIndex = null;
      } else if (expandedIndex != null && expandedIndex > index) {
        _expandedSuggestionIndex = expandedIndex - 1;
      }
      final editingIndex = _editingMedicineIndex;
      if (editingIndex == index) {
        _editingMedicineIndex = null;
        _medicineController.clear();
        _suggestions = const [];
      } else if (editingIndex != null && editingIndex > index) {
        _editingMedicineIndex = editingIndex - 1;
      }
    });
  }

  List<MedicineSearchRequest> _buildRequestsFromMedicines() {
    return _medicines.map((medicine) {
      final raw = medicine.displayName.trim();

      return MedicineSearchRequest(
        rawText: raw,
        normalizedText: MedicineNormalizer.normalize(raw),
        strength: MedicineIdentity.strength(raw),
        dosageForm: MedicineIdentity.form(raw),
        baseName: MedicineIdentity.name(raw),
        searchTokens: MedicineNormalizer.buildSearchTokens(raw),
        resolvedDisplayName: raw,
      );
    }).toList();
  }

  Future<void> _continue() async {
    if (_medicineController.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingMedicineIndex == null
                ? 'أضف الاسم المكتوب إلى القائمة قبل المتابعة'
                : 'احفظ تعديل الدواء أو ألغِه قبل المتابعة',
          ),
        ),
      );
      return;
    }
    if (_medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضيفي دواءً واحدًا على الأقل للمتابعة')),
      );
      return;
    }

    // عند الدخول من صفحة النتائج نعيد القائمة المعدلة فقط.
    if (widget.returnEditedMedicines) {
      Navigator.pop(context, List<MedicineModel>.from(_medicines));
      return;
    }

    if (!_isPrescriptionMode && !_manualReviewStarted) {
      final hasSuggestions = await _analyzeManualNames();
      if (!hasSuggestions && mounted) await _continue();
      return;
    }

    final requests = _buildRequestsFromMedicines();
    final extractedText = _searchController.extractedText.value;

    _searchController.clearAll();
    _searchController.setSearchSource(widget.searchSource);
    _searchController.setRequests(requests);
    if (extractedText.trim().isNotEmpty) {
      _searchController.setExtractedText(extractedText);
    }

    String? savedPrescriptionId;
    if (_isPrescriptionMode) {
      savedPrescriptionId = await _offerOptionalPrescriptionSave();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          medicines: List<MedicineModel>.from(_medicines),
          searchSource: widget.searchSource,
          prescriptionId: savedPrescriptionId,
          prescriptionText: extractedText.trim().isEmpty
              ? null
              : extractedText.trim(),
        ),
      ),
    );
  }

  Future<bool> _analyzeManualNames() async {
    if (_isAnalyzingManual) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    final names = _medicines.map((medicine) => medicine.displayName).toList();
    setState(() => _isAnalyzingManual = true);
    try {
      final results = await _manualAnalysisService.analyzeAll(names);
      if (!mounted) return false;
      setState(() {
        _manualAnalysis
          ..clear()
          ..addAll(results);
        _manualReviewStarted = true;
        _expandedSuggestionIndex = null;
      });
      return results.any(
        (result) => result.status == ManualMedicineAnalysisStatus.matched,
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingManual = false);
    }
  }

  void _toggleManualSuggestions(int index) {
    setState(() {
      _expandedSuggestionIndex = _expandedSuggestionIndex == index
          ? null
          : index;
    });
  }

  void _acceptManualSuggestion(int index, String suggestion) {
    final result = _manualAnalysis[index];
    if (suggestion.trim().isEmpty) return;
    final normalized = MedicineNormalizer.normalize(suggestion);
    final alreadyUsed = _medicines.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          MedicineNormalizer.normalize(entry.value.displayName) == normalized,
    );
    if (alreadyUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاقتراح موجود بالفعل في القائمة')),
      );
      return;
    }
    setState(() {
      _medicines[index] = MedicineModel(name: suggestion);
      _manualAnalysis[index] = result.acceptSuggestion(suggestion);
      _expandedSuggestionIndex = null;
    });
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

  Future<BeneficiaryModel?> _selectBeneficiaryForSaving() async {
    await _familyController.refreshMembers();
    if (!mounted) return null;
    final beneficiaries = _buildBeneficiaries();

    final result = await showModalBottomSheet<BeneficiarySelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BeneficiarySelectorSheet(
        beneficiaries: beneficiaries,
        showSaveOption: false,
        title: 'حفظ الوصفة',
        subtitle: '',
      ),
    );

    return result?.beneficiary;
  }

  Future<String?> _offerOptionalPrescriptionSave() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حفظ الوصفة؟'),
          content: const Text('يمكنك الرجوع إليها لاحقًا من الأرشيف.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('تخطي'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true || !mounted) return null;

    final beneficiary = await _selectBeneficiaryForSaving();
    if (beneficiary == null) return null;

    try {
      final prescriptionId = await SavedPrescriptionService.instance
          .savePrescription(
            beneficiary: beneficiary,
            medicines: List<MedicineModel>.from(_medicines),
            source: widget.searchSource,
            originalFile: widget.prescriptionFile,
            originalFileType: widget.prescriptionFileType,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الوصفة.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
      return prescriptionId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حفظ الوصفة'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }
  }

  String get _pageTitle {
    if (widget.returnEditedMedicines) return 'تعديل قائمة الأدوية';
    if (_isPrescriptionMode) return 'الأدوية المستخرجة';
    return 'البحث اليدوي عن دواء';
  }

  String get _bottomButtonText {
    if (widget.returnEditedMedicines) return 'حفظ التعديلات والعودة';
    if (_isPrescriptionMode) return 'البحث عن الأدوية';
    return _manualReviewStarted ? 'متابعة البحث' : 'البحث عن الدواء';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
              fontSize: 18,
            ),
          ),
        ),
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        AbsorbPointer(
                          absorbing: _isAnalyzingManual,
                          child: _buildInputSection(),
                        ),
                        const SizedBox(height: 12),
                        AbsorbPointer(
                          absorbing: _isAnalyzingManual,
                          child: _buildMedicinesSection(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!keyboardVisible) _buildBottomAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Expanded(
                child: Text(
                  _editingMedicineIndex != null ? 'تعديل الدواء' : 'إضافة دواء',
                  style: TextStyle(
                    color: pPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_editingMedicineIndex != null)
                TextButton.icon(
                  onPressed: _cancelMedicineEditing,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('إلغاء'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _medicineController,
            focusNode: _medicineFocusNode,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onChanged: _onMedicineQueryChanged,
            onSubmitted: (_) => _addMedicine(),
            decoration: InputDecoration(
              hintText: 'اسم الدواء باللغة الإنجليزية',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: Icon(
                Iconsax.search_normal_1,
                color: pPrimaryColor,
                size: 19,
              ),
              suffixIcon: IconButton(
                onPressed: _addMedicine,
                tooltip: _editingMedicineIndex != null
                    ? 'حفظ التعديل'
                    : 'إضافة الدواء',
                icon: Icon(
                  _editingMedicineIndex != null
                      ? Icons.check_circle_outline_rounded
                      : Iconsax.add_circle,
                  color: pAccentColor,
                ),
              ),
              filled: true,
              fillColor: pLightColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pPrimaryColor.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pPrimaryColor, width: 1.4),
              ),
            ),
          ),
          if (_isLoadingSuggestions || _suggestions.isNotEmpty)
            _buildSuggestionPanel(),
        ],
      ),
    );
  }

  Widget _buildSuggestionPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: pPrimaryColor.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isLoadingSuggestions
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 5),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  leading: Icon(
                    Icons.medication_outlined,
                    color: pPrimaryColor,
                    size: 19,
                  ),
                  title: Text(
                    suggestion.medicineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: suggestion.scientificName.isEmpty
                      ? null
                      : Text(
                          suggestion.scientificName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                  trailing: const Icon(Icons.north_west_rounded, size: 17),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
    );
  }

  Widget _buildMedicinesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Icon(Iconsax.box, color: pPrimaryColor, size: 18),
              const SizedBox(width: 7),
              Text(
                'الأدوية المضافة',
                style: TextStyle(
                  color: pPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_medicines.length}',
                  style: TextStyle(
                    color: pPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_medicines.isEmpty) _buildEmptyState(),
          if (_medicines.isNotEmpty)
            ListView.separated(
              itemCount: _medicines.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 7),
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pPrimaryColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.search_status,
            size: 28,
            color: pPrimaryColor.withOpacity(0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (widget.isReviewMode || _manualReviewStarted)
                  ? 'يمكنك إضافة دواء جديد إلى القائمة'
                  : 'اكتب اسم الدواء ثم أضفه إلى القائمة',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(int index, MedicineModel medicine) {
    final isEditing = _editingMedicineIndex == index;
    final isUnmatchedPrescriptionItem =
        _isPrescriptionMode && medicine.needsReview;
    final analysis = _manualReviewStarted ? _manualAnalysis[index] : null;
    final hasSuggestions =
        analysis?.status == ManualMedicineAnalysisStatus.matched &&
        analysis!.suggestionOptions.isNotEmpty;
    final suggestionsExpanded = _expandedSuggestionIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isEditing
            ? pPrimaryColor.withValues(alpha: 0.08)
            : isUnmatchedPrescriptionItem
            ? pSuggestionColor.withValues(alpha: 0.10)
            : pLightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEditing
              ? pPrimaryColor.withValues(alpha: 0.65)
              : isUnmatchedPrescriptionItem
              ? pSuggestionColor.withValues(alpha: 0.70)
              : pPrimaryColor.withOpacity(0.10),
          width: isEditing || isUnmatchedPrescriptionItem ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasSuggestions
              ? () => _toggleManualSuggestions(index)
              : () => _startEditingMedicine(index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [pPrimaryColor, pSecondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              medicine.displayName,
                              style: TextStyle(
                                color: hasSuggestions ? pSuggestionColor : null,
                                fontSize: 13,
                                fontWeight: hasSuggestions
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (hasSuggestions)
                            Icon(
                              suggestionsExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: pSuggestionColor,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _startEditingMedicine(index),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: Icon(Iconsax.edit, size: 18, color: pPrimaryColor),
                      tooltip: 'تعديل',
                    ),
                    IconButton(
                      onPressed: () => _removeMedicine(index),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(
                        Iconsax.trash,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      tooltip: 'حذف',
                    ),
                  ],
                ),
                if (analysis != null) _buildAnalysisDetail(index, analysis),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisDetail(int index, ManualMedicineAnalysis result) {
    if (result.status != ManualMedicineAnalysisStatus.matched ||
        _expandedSuggestionIndex != index ||
        result.suggestionOptions.isEmpty) {
      return const SizedBox.shrink();
    }
    final options = result.suggestionOptions.take(3).toList();
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 41, top: 5, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pSuggestionColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (
            var optionIndex = 0;
            optionIndex < options.length;
            optionIndex++
          ) ...[
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _acceptManualSuggestion(index, options[optionIndex]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        options[optionIndex],
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: pSuggestionColor,
                    ),
                  ],
                ),
              ),
            ),
            if (optionIndex < options.length - 1)
              const Divider(height: 1, indent: 8, endIndent: 8),
          ],
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
            onPressed: _isAnalyzingManual ? null : _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: pPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isAnalyzingManual
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
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
