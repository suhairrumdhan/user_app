import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/controllers/main_navigation_controller.dart';
import '../../../app/core/utils/location_utils.dart';
import '../../family/controllers/family_controller.dart';
import '../../insurance/controllers/insurance_controller.dart';
import '../../orders/models/order_status.dart';
import '../../orders/views/confirm_order_sheet.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../../pharmacy/views/home_page.dart';
import '../../profile/controllers/user_controller.dart';
import '../../search/controllers/search_controller.dart';
import '../../search/models/matched_medicine_result.dart';
import '../../search/models/medicine_search_request.dart';
import '../../search/models/pharmacy_search_filters.dart';
import '../../search/services/medicine_normalizer.dart';
import '../../search/views/pharmacy_result_card.dart';
import '../../search/views/search_filters_card.dart';
import '../../search/views/search_results_map.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/beneficiary_model.dart';
import '../models/medicine_model.dart';
import '../widgets/beneficiary_selector_sheet.dart';
import 'manual_medicine_search_page.dart';

class SearchResultsPage extends StatefulWidget {
  final List<MedicineModel> medicines;
  final String searchSource;
  final BeneficiaryModel? initialBeneficiary;
  final String? prescriptionId;
  final String? prescriptionImageUrl;
  final String? prescriptionText;

  const SearchResultsPage({
    super.key,
    required this.medicines,
    this.searchSource = 'manual',
    this.initialBeneficiary,
    this.prescriptionId,
    this.prescriptionImageUrl,
    this.prescriptionText,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({super.key, required this.child, required this.onChange});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextSize = context.size;
      if (contextSize == null) return;
      if (_oldSize == contextSize) return;

      _oldSize = contextSize;
      widget.onChange(contextSize);
    });

    return widget.child;
  }
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final SearchController controller = Get.find<SearchController>();
  late final PageController _pageController;
  final Map<int, double> _cardHeights = {};
  double _currentCardHeight = 450;
  int _currentPage = 0;
  late final InsuranceController? _insuranceController;
  late BeneficiaryModel? _selectedBeneficiary;
  LatLng? _currentPosition;

  double selectedDistance = 4;
  bool useInsurance = false;
  bool availableNowOnly = false;
  bool fullMatchOnly = false;
  bool similarProductsAllowed = true;
  bool priceFilterEnabled = false;
  String minPriceText = '';
  String maxPriceText = '';
  String priceRangeMode = 'between';
  String selectedSort = PharmacySearchSort.nearest;

  bool _isMedicinesExpanded = false;
  bool _didAutoSearch = false;
  static bool _searchInFlight = false;
  bool _showMap = false;
  PharmacyModel? _focusedMapPharmacy;

  @override
  void initState() {
    super.initState();

    _insuranceController = Get.isRegistered<InsuranceController>()
        ? Get.find<InsuranceController>()
        : Get.put(InsuranceController());

    _selectedBeneficiary = widget.initialBeneficiary;
    if (_selectedBeneficiary != null) {
      controller.setBeneficiary(_selectedBeneficiary!);
    }

    _pageController = PageController(viewportFraction: 0.90);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didAutoSearch) {
        _didAutoSearch = true;
        _runSearch();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _buildRequestKey(String raw) {
    final normalized = MedicineNormalizer.normalize(raw);
    final safe = normalized.isNotEmpty ? normalized : raw.trim().toUpperCase();
    return '${safe}_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _runSearch() async {
    if (_searchInFlight) return;
    _searchInFlight = true;
    try {
      final selectedMinimum = double.tryParse(minPriceText.trim());
      final selectedMaximum = double.tryParse(maxPriceText.trim());
      final minPrice = priceFilterEnabled && priceRangeMode != 'maximumOnly'
          ? selectedMinimum
          : null;
      final maxPrice = priceFilterEnabled && priceRangeMode != 'minimumOnly'
          ? selectedMaximum
          : null;
      if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الحد الأدنى للسعر يجب ألا يتجاوز الحد الأعلى'),
          ),
        );
        return;
      }
      controller.updateFilters(
        controller.filters.value.copyWith(
          maxDistanceKm: selectedDistance,
          insuranceOnly: useInsurance,
          availableNowOnly: availableNowOnly,
          fullMatchOnly: fullMatchOnly,
          alternativesAllowed: similarProductsAllowed,
          sortBy: selectedSort,
          minPrice: minPrice,
          maxPrice: maxPrice,
          clearMinPrice: minPrice == null,
          clearMaxPrice: maxPrice == null,
        ),
      );

      List<String> insuranceCodes = [];
      if (useInsurance) {
        insuranceCodes = _resolveInsuranceCodes();
      }

      final position = await LocationUtils.getCurrentPosition(context);

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _focusedMapPharmacy = null;
      });

      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديد موقعك؛ ستظهر النتائج دون تطبيق فلتر المسافة.',
            ),
          ),
        );
      }

      await controller.runSearch(
        userInsuranceCodes: insuranceCodes,
        userLat: position?.latitude,
        userLng: position?.longitude,
      );

      if (!mounted) return;

      if (controller.results.isEmpty &&
          controller.errorMessage.value.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(controller.errorMessage.value)));
      }
    } finally {
      _searchInFlight = false;
    }
  }

  List<String> _resolveInsuranceCodes() {
    final insuranceController = _insuranceController;
    final beneficiary = _selectedBeneficiary;
    if (insuranceController == null || beneficiary == null) return [];

    final active = insuranceController.insurances.where((item) {
      if (!item.isActive) return false;
      return item.coveredMemberIds.contains(
        beneficiary.isSelf ? 'self' : beneficiary.id,
      );
    });

    return active
        .map((item) => item.companyCode.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
  }

  List<BeneficiaryModel> _buildBeneficiaries() {
    final beneficiaries = <BeneficiaryModel>[];
    final userController = Get.find<UserController>();
    final familyController = Get.find<FamilyController>();
    final currentUser = userController.user.value;

    beneficiaries.add(
      BeneficiaryModel(
        id: currentUser?.id ?? 'self',
        name: (currentUser?.name ?? '').trim().isNotEmpty
            ? currentUser!.name
            : 'أنا',
        type: 'self',
        relation: 'أنا',
      ),
    );

    for (final member in familyController.members) {
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

  Future<BeneficiaryModel?> _selectBeneficiary({required String title}) async {
    final result = await showModalBottomSheet<BeneficiarySelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BeneficiarySelectorSheet(
        beneficiaries: _buildBeneficiaries(),
        showSaveOption: false,
        title: title,
      ),
    );

    return result?.beneficiary;
  }

  Future<void> _handleInsuranceChanged(bool enabled) async {
    if (!enabled) {
      setState(() => useInsurance = false);
      return;
    }

    final beneficiary =
        _selectedBeneficiary ??
        await _selectBeneficiary(title: 'مستفيد التأمين');

    if (!mounted || beneficiary == null) return;

    _selectedBeneficiary = beneficiary;
    controller.setBeneficiary(beneficiary);

    final codes = _resolveInsuranceCodes();
    if (codes.isEmpty) {
      setState(() {
        useInsurance = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد تأمين نشط يغطي المستفيد المختار'),
        ),
      );
      return;
    }

    setState(() => useInsurance = true);
  }

  List<PharmacyModel> get _displayResults => controller.displayResults;

  RangeValues get _availablePriceBounds {
    final prices = controller.results
        .map((result) => result.totalEstimatedPrice)
        .where((price) => price > 0 && price.isFinite)
        .toList();

    if (prices.isEmpty) return const RangeValues(0, 100);

    prices.sort();
    final lowest = prices.first;
    final highest = prices.last;
    final spread = highest - lowest;
    final margin = spread > 0 ? spread * 0.15 : (lowest * 0.20).clamp(10, 50);
    final minimum =
        (((lowest - margin).clamp(0, double.infinity)) / 10)
            .floor()
            .toDouble() *
        10;
    var maximum = ((highest + margin) / 10).ceil().toDouble() * 10;
    if (maximum <= minimum) maximum = minimum + 10;

    return RangeValues(minimum, maximum);
  }

  RangeValues get _selectedPriceRange {
    final bounds = _availablePriceBounds;
    var minimum = double.tryParse(minPriceText) ?? bounds.start;
    var maximum = double.tryParse(maxPriceText) ?? bounds.end;
    minimum = minimum.clamp(bounds.start, bounds.end).toDouble();
    maximum = maximum.clamp(bounds.start, bounds.end).toDouble();
    if (minimum > maximum) return bounds;
    return RangeValues(minimum, maximum);
  }

  Future<void> _editMedicines() async {
    final editedMedicines = await Navigator.push<List<MedicineModel>>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualMedicineSearchPage(
          initialMedicines: widget.medicines,
          searchSource: widget.searchSource,
          isReviewMode: true,
          returnEditedMedicines: true,
        ),
      ),
    );

    if (editedMedicines == null || editedMedicines.isEmpty) return;

    final editedRequests = editedMedicines.map((medicine) {
      final raw = medicine.displayName.trim();

      return MedicineSearchRequest(
        requestKey: _buildRequestKey(raw),
        rawText: raw,
        normalizedText: MedicineNormalizer.normalize(raw),
        strength: MedicineNormalizer.extractStrength(raw),
        dosageForm: MedicineNormalizer.extractDosageForm(raw),
        baseName: MedicineNormalizer.extractBaseName(raw),
        searchTokens: MedicineNormalizer.buildSearchTokens(raw),
        resolvedDisplayName: raw,
      );
    }).toList();

    controller.clearAll();
    controller.setSearchSource(widget.searchSource);
    if (_selectedBeneficiary != null) {
      controller.setBeneficiary(_selectedBeneficiary!);
    }
    controller.setRequests(editedRequests);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          medicines: editedMedicines,
          searchSource: widget.searchSource,
          initialBeneficiary: _selectedBeneficiary,
          prescriptionId: widget.prescriptionId,
          prescriptionImageUrl: widget.prescriptionImageUrl,
          prescriptionText: widget.prescriptionText,
        ),
      ),
    );
  }

  void _handleAlternativeSelection({
    required String pharmacyId,
    required String requestKey,
    required MatchedMedicineResult newSelection,
  }) {
    controller.replaceMatchedMedicine(
      pharmacyId: pharmacyId,
      requestKey: requestKey,
      newSelection: newSelection,
    );

    if (!mounted) return;
    setState(() {});
  }

  void _showPharmacyDetails(PharmacyModel pharmacy) {
    PharmacyResultCard.showDetails(
      context,
      pharmacy: pharmacy,
      onSelectAlternative: _handleAlternativeSelection,
    );
  }

  void _openPharmacyOnMap(PharmacyModel pharmacy) {
    setState(() {
      _focusedMapPharmacy = pharmacy;
      _showMap = true;
    });
  }

  void _showChatUnavailableBeforeOrder() {
    Get.snackbar(
      'المحادثة غير متاحة الآن',
      'يمكن فتح المحادثة بعد إنشاء الطلب فقط',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _openOrderSheet(PharmacyModel pharmacy) async {
    debugPrint(
      'Opening order sheet: pharmacyId=${pharmacy.id} '
      'matches=${pharmacy.matchedMedicines.length}',
    );
    final beneficiary =
        _selectedBeneficiary ?? await _selectBeneficiary(title: 'مستفيد الطلب');

    if (!mounted || beneficiary == null) return;

    _selectedBeneficiary = beneficiary;
    controller.setBeneficiary(beneficiary);

    final requestSource = widget.searchSource == 'prescription'
        ? OrderRequestSource.prescription
        : OrderRequestSource.manual;

    final order = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmOrderSheet(
        pharmacy: pharmacy,
        beneficiary: beneficiary,
        useInsurance: useInsurance,
        requestSource: requestSource,
        prescriptionId: widget.prescriptionId,
        prescriptionImageUrl: widget.prescriptionImageUrl,
        prescriptionText: widget.prescriptionText,
        metadata: {'searchFlow': widget.searchSource},
      ),
    );

    if (order != null) {
      controller.clearAll();
      final navigationController = Get.find<MainNavigationController>();
      navigationController.goOrders();
      Get.offAll(() => const HomePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SearchUiColors.light,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: SearchUiColors.primary),
          title: const Text(
            'نتائج البحث',
            style: TextStyle(
              color: SearchUiColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: SafeArea(
          child: Obx(
            () => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopSummaryCard(),
                        const SizedBox(height: 14),
                        _buildMedicinesExpandableCard(),
                        const SizedBox(height: 14),
                        _buildFiltersSection(),
                        const SizedBox(height: 14),
                        _buildEstimateNotice(),
                        const SizedBox(height: 14),
                        _buildSearchResultsSection(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: SearchUiColors.primary.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Iconsax.search_normal_1,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بحث عن ${widget.medicines.length} دواء',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  useInsurance ? 'مع التأمين الصحي' : 'بدون التأمين الصحي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _editMedicines,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'تعديل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesExpandableCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _isMedicinesExpanded = !_isMedicinesExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SearchUiColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Iconsax.box,
                      color: SearchUiColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'الأدوية المطلوبة',
                      style: TextStyle(
                        color: SearchUiColors.primary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SearchUiColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.medicines.length}',
                      style: const TextStyle(
                        color: SearchUiColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isMedicinesExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: SearchUiColors.primary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: _isMedicinesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: List.generate(widget.medicines.length, (index) {
                  final medicine = widget.medicines[index];

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index == widget.medicines.length - 1 ? 0 : 10,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SearchUiColors.light,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SearchUiColors.primary.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                SearchUiColors.primary,
                                SearchUiColors.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            medicine.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    final subtitle = [
      'المسافة ${selectedDistance.toStringAsFixed(0)} كم',
      if (useInsurance) 'تأمين',
      if (availableNowOnly) 'متاح الآن',
      if (fullMatchOnly) 'تطابق كامل',
      if (priceFilterEnabled) 'نطاق سعري',
    ].join(' • ');

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Container(
        decoration: _cardDecoration(),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SearchUiColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Iconsax.setting_4,
              color: SearchUiColors.primary,
              size: 20,
            ),
          ),
          title: const Text(
            'خيارات البحث',
            style: TextStyle(
              color: SearchUiColors.primary,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SearchFiltersCard(
                selectedDistance: selectedDistance,
                useInsurance: useInsurance,
                availableNowOnly: availableNowOnly,
                fullMatchOnly: fullMatchOnly,
                similarProductsAllowed: similarProductsAllowed,
                priceFilterEnabled: priceFilterEnabled,
                selectedSort: selectedSort,
                minimumAvailablePrice: _availablePriceBounds.start,
                maximumAvailablePrice: _availablePriceBounds.end,
                selectedPriceRange: _selectedPriceRange,
                priceRangeMode: priceRangeMode,
                onDistanceChanged: (v) => setState(() => selectedDistance = v),
                onInsuranceChanged: _handleInsuranceChanged,
                onAvailableNowChanged: (v) =>
                    setState(() => availableNowOnly = v),
                onFullMatchChanged: (v) => setState(() => fullMatchOnly = v),
                onSimilarProductsChanged: (v) =>
                    setState(() => similarProductsAllowed = v),
                onPriceFilterChanged: (enabled) {
                  setState(() {
                    priceFilterEnabled = enabled;
                    if (enabled) {
                      final bounds = _availablePriceBounds;
                      minPriceText = bounds.start.toString();
                      maxPriceText = bounds.end.toString();
                    } else {
                      minPriceText = '';
                      maxPriceText = '';
                    }
                  });
                },
                onSortChanged: (v) => setState(() => selectedSort = v),
                onPriceRangeChanged: (range) => setState(() {
                  minPriceText = range.start.toString();
                  maxPriceText = range.end.toString();
                }),
                onPriceRangeModeChanged: (mode) =>
                    setState(() => priceRangeMode = mode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.20)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'الأسعار والتوفر تقديرية وتخضع لمراجعة الصيدلية. المنتجات المتشابهة بالاسم ليست بدائل علاجية معتمدة إلا بعد مراجعة الصيدلي.',
              style: TextStyle(
                color: SearchUiColors.darkText,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsSection() {
    if (controller.isLoading.value) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: _cardDecoration(),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: SearchUiColors.primary),
              SizedBox(height: 14),
              Text(
                'جاري البحث عن الصيدليات المناسبة...',
                style: TextStyle(
                  color: SearchUiColors.darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Center(
          child: Text(
            controller.errorMessage.value.isNotEmpty
                ? controller.errorMessage.value
                : 'اضغط على زر تحديث نتائج الصيدليات لبدء البحث',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final results = _displayResults;
    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Text(
          'تعذر تحميل بيانات الصيدليات المطابقة',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: SearchUiColors.softText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.86;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الصيدليات المناسبة (${results.length})',
          style: const TextStyle(
            color: SearchUiColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildResultsViewToggle(),
        const SizedBox(height: 10),
        if (_showMap) ...[
          SearchResultsMap(
            key: ValueKey('results-map-${_focusedMapPharmacy?.id ?? 'all'}'),
            pharmacies: results,
            userPosition: _currentPosition,
            focusedPharmacy: _focusedMapPharmacy,
            onOrder: _openOrderSheet,
            onDetails: _showPharmacyDetails,
            interactive: false,
            onOpenInteractive: () => _openInteractiveResultsMap(results),
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اسحب لليمين أو اليسار',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(results.length, (index) {
                final result = results[index];

                return Container(
                  width: cardWidth,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
                  child: PharmacyResultCard(
                    pharmacy: result,
                    onSelectAlternative: _handleAlternativeSelection,
                    onTapDetails: null,
                    onTapChat: _showChatUnavailableBeforeOrder,
                    onTapOpenMap: () => _openPharmacyOnMap(result),
                    onTapOrder: () => _openOrderSheet(result),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsViewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SearchUiColors.primary.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildViewToggleButton(
              icon: Icons.view_carousel_rounded,
              label: 'قائمة النتائج',
              selected: !_showMap,
              onTap: () => setState(() {
                _showMap = false;
                _focusedMapPharmacy = null;
              }),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildViewToggleButton(
              icon: Iconsax.map_1,
              label: 'معاينة الخريطة',
              selected: _showMap,
              onTap: () => setState(() {
                _focusedMapPharmacy = null;
                _showMap = true;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? SearchUiColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : SearchUiColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : SearchUiColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInteractiveResultsMap(List<PharmacyModel> results) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('خريطة نتائج البحث'),
            centerTitle: true,
          ),
          body: SearchResultsMap(
            pharmacies: results,
            userPosition: _currentPosition,
            focusedPharmacy: _focusedMapPharmacy,
            onOrder: _openOrderSheet,
            onDetails: _showPharmacyDetails,
            expanded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
          child: ElevatedButton.icon(
            onPressed: controller.isLoading.value ? null : _runSearch,
            icon: controller.isLoading.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Iconsax.shop),
            label: Text(
              controller.isLoading.value
                  ? 'جاري البحث...'
                  : 'تحديث نتائج الصيدليات',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SearchUiColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
