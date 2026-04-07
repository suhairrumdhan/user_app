import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../app/core/utils/location_utils.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/views/chat_detail_screen.dart';
import '../../insurance/controllers/insurance_controller.dart';
import '../../orders/models/order_status.dart';
import '../../orders/views/confirm_order_sheet.dart';
import '../../orders/views/orders_page.dart';
import '../../pharmacy/models/pharmacy_model.dart';
import '../../search/controllers/search_controller.dart';
import '../../search/models/pharmacy_search_filters.dart';
import '../../search/views/pharmacy_result_card.dart';
import '../../search/views/search_filters_card.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/beneficiary_model.dart';
import '../models/medicine_model.dart';

class SearchResultsPage extends StatefulWidget {
  final List<MedicineModel> medicines;
  final BeneficiaryModel beneficiary;

  const SearchResultsPage({
    super.key,
    required this.medicines,
    required this.beneficiary,
  });

  @override
  State<SearchResultsPage> createState() =>
      _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final SearchController controller = Get.find<SearchController>();
  final ChatService _chatService = ChatService();
  late final InsuranceController? _insuranceController;
  late final PageController _pageController;

  double selectedDistance = 5;
  bool useInsurance = false;
  bool availableNowOnly = false;
  bool fullMatchOnly = false;
  String selectedSort = PharmacySearchSort.nearest;

  bool _isMedicinesExpanded = false;
  int _currentPage = 0;
  bool _didAutoSearch = false;

  @override
  void initState() {
    super.initState();

    _insuranceController = Get.isRegistered<InsuranceController>()
        ? Get.find<InsuranceController>()
        : Get.put(InsuranceController());

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

  Future<void> _runSearch() async {
    controller.setBeneficiary(widget.beneficiary);
    controller.updateFilters(
      controller.filters.value.copyWith(
        maxDistanceKm: selectedDistance,
        insuranceOnly: useInsurance,
        availableNowOnly: availableNowOnly,
        fullMatchOnly: fullMatchOnly,
        alternativesAllowed: false,
        sortBy: selectedSort,
      ),
    );

    List<String> insuranceCodes = [];
    if (useInsurance) {
      insuranceCodes = _resolveInsuranceCodes();
    }

    final position = await LocationUtils.getCurrentPosition(context);

    await controller.runSearch(
      userInsuranceCodes: insuranceCodes,
      userLat: position?.latitude,
      userLng: position?.longitude,
    );

    if (!mounted) return;

    if (controller.results.isEmpty &&
        controller.errorMessage.value.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errorMessage.value)),
      );
    }

    setState(() {
      _currentPage = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  List<String> _resolveInsuranceCodes() {
    final insuranceController = _insuranceController;
    if (insuranceController == null) {
      debugPrint('❌ InsuranceController is null');
      return [];
    }

    final active = insuranceController.insurances.where((item) {
      if (!item.isActive) return false;
      if (widget.beneficiary.isSelf) {
        return true;
      }
      return item.coveredMemberIds.contains(widget.beneficiary.id);
    });

    final result = active
        .map((item) => item.companyCode.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();

    return result;
  }

  List<PharmacyModel> get _displayResults => controller.displayResults;

  List<Widget> _buildPreviewMedicines() {
    final preview = widget.medicines.take(3).map((medicine) {
      return _simpleMedicineTag(medicine.displayName);
    }).toList();

    if (widget.medicines.length > 3) {
      preview.add(_simpleMedicineTag('+${widget.medicines.length - 3}'));
    }

    return preview;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildTopSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SearchUiColors.primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Iconsax.search_normal_1,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الطلب',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بحث عن ${widget.medicines.length} دواء',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text(
                  'تعديل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSummaryChip(
                icon: widget.beneficiary.isSelf
                    ? Iconsax.profile_circle
                    : Iconsax.people,
                label: widget.beneficiary.name,
              ),
              _buildSummaryChip(
                icon: Iconsax.box,
                label: '${widget.medicines.length} أدوية',
              ),
              _buildSummaryChip(
                icon: Iconsax.health,
                label: useInsurance ? 'مع التأمين' : 'بدون تأمين',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
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
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _isMedicinesExpanded = !_isMedicinesExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SearchUiColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Iconsax.box,
                      color: SearchUiColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الأدوية المطلوبة',
                          style: TextStyle(
                            color: SearchUiColors.primary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isMedicinesExpanded
                              ? 'إخفاء القائمة'
                              : 'عرض القائمة المختصرة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildPreviewMedicines(),
                ),
              ),
            ),
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

  Widget _simpleMedicineTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SearchUiColors.primary.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SearchUiColors.darkText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final subtitle = [
      'المسافة ${selectedDistance.toStringAsFixed(0)} كم',
      if (useInsurance) 'تأمين',
      if (availableNowOnly) 'متاح الآن',
      if (fullMatchOnly) 'تطابق كامل',
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SearchUiColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Iconsax.setting_4,
              color: SearchUiColors.primary,
              size: 20,
            ),
          ),
          title: const Text(
            'الفلاتر',
            style: TextStyle(
              color: SearchUiColors.primary,
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
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
                selectedSort: selectedSort,
                onDistanceChanged: (v) => setState(() => selectedDistance = v),
                onInsuranceChanged: (v) => setState(() => useInsurance = v),
                onAvailableNowChanged: (v) =>
                    setState(() => availableNowOnly = v),
                onFullMatchChanged: (v) => setState(() => fullMatchOnly = v),
                onSortChanged: (v) => setState(() => selectedSort = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ القسم المُصلح - النتائج
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
                : 'اضغط على زر عرض الصيدليات المناسبة لبدء البحث',
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
    final screenHeight = MediaQuery.of(context).size.height;
    final sliderHeight = screenHeight * 0.42;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الصيدليات المناسبة (${results.length})',
                style: const TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'اسحب لليمين أو اليسار',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: sliderHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: results.length,
            padEnds: false,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final result = results[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: PharmacyResultCard(
                  pharmacy: result,
                  onTapDetails: null,
                  onTapChat: () async {
                    try {
                      // 🔥 الصحيح
                      final chat = await _chatService.createNewChat(result);

                      Get.to(() => ChatDetailScreen(chat: chat));
                    } catch (e) {
                      Get.snackbar(
                        'خطأ',
                        'فشل في فتح المحادثة',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
                  onTapOrder: () async {
                    final order = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ConfirmOrderSheet(
                        pharmacy: result,
                        beneficiary: widget.beneficiary,
                        medicines: widget.medicines,
                        useInsurance: useInsurance,
                        requestSource: OrderRequestSource.manual,
                        metadata: const {
                          'searchFlow': 'manual',
                        },
                      ),
                    );

                    if (order != null) {
                      Get.to(() => OrdersPage());
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (results.length > 1)
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                results.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? SearchUiColors.primary
                        : SearchUiColors.primary.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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