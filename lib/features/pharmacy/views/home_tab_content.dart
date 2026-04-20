import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../prescription/models/medicine_model.dart';
import '../../prescription/services/drug_parser.dart';
import '../../prescription/services/prescription_api_service.dart';
import '../../prescription/views/manual_medicine_search_page.dart';
import '../../prescription/views/search_results_page.dart';
import '../../prescription/widgets/beneficiary_selector_sheet.dart';
import '../../search/models/medicine_search_request.dart';
import '../../search/services/medicine_normalizer.dart';
import '../models/pharmacy_model.dart';
import 'map_tab.dart';
import '../../prescription/views/preview_screen.dart';
import '../../prescription/services/file_utils.dart';
import '../../../app/core/utils/image_source_dialog.dart';
import '../widgets/pharmacy_glass_card.dart';
import 'dart:ui';
import '../../family/controllers/family_controller.dart';
import '../../search/controllers/search_controller.dart' as app_search;

class HomeTabContent extends StatefulWidget {
  final LatLng? currentPosition;
  final List<PharmacyModel> pharmacies;
  final List<PharmacyModel> allPharmacies;
  final bool isLoading;
  final VoidCallback onRefresh;
  final double selectedDistance;
  final Function(double) onDistanceChanged;

  const HomeTabContent({
    super.key,
    required this.currentPosition,
    required this.pharmacies,
    required this.allPharmacies,
    required this.isLoading,
    required this.onRefresh,
    required this.selectedDistance,
    required this.onDistanceChanged,
  });

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  File? _selectedFile;
  String? _fileType;
  String _extractedText = '';
  bool _isLoading = false;

  final PageController _pageController = PageController(viewportFraction: 0.78);
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  final List<double> _distanceOptions = [1, 2, 3, 4, 5, 10, 15, 20];
  double _tempDistance = 4;

  // استخدام FamilyController
  final FamilyController _familyController = Get.put(FamilyController());

  @override
  void initState() {
    super.initState();
    _tempDistance = widget.selectedDistance;
  }

  Future<bool> _showPreviewDialog(File file, String type) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => PreviewScreen(
        file: file,
        fileType: type,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    ) ??
        false;
  }

  Future<void> _processExtractedText(String text) async {
    try {
      setState(() => _isLoading = true);

      final response = await PrescriptionApiService.analyzePrescription(text);
      final medicines = response['medicines'] as List<dynamic>? ?? [];

      if (medicines.isEmpty) {
        throw Exception('لم يتم العثور على أدوية في الوصفة');
      }

      final parsedMedicines = DrugParser.parseMedicineModels(medicines);
      final parsedRequests = DrugParser.parseSearchRequests(medicines);

      if (parsedMedicines.isEmpty || parsedRequests.isEmpty) {
        throw Exception('فشل تحليل الأدوية');
      }

      final searchController =
      Get.isRegistered<app_search.SearchController>()
          ? Get.find<app_search.SearchController>()
          : Get.put(app_search.SearchController());

      searchController.clearAll();
      searchController.setSearchSource('prescription');
      searchController.setExtractedText(text);
      searchController.setRequests(parsedRequests);

      if (!mounted) return;

      /// 1) مراجعة/تعديل الأدوية عبر نفس صفحة المانول
      final reviewedMedicines = await Navigator.push<List<MedicineModel>>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualMedicineSearchPage(
            initialMedicines: parsedMedicines,
            searchSource: 'prescription',
            isReviewMode: true,
          ),
        ),
      );

      if (reviewedMedicines == null || reviewedMedicines.isEmpty) {
        throw Exception('لم يتم اعتماد أي دواء');
      }

      /// 2) إعادة بناء requests من النسخة المعدلة
      final reviewedRequests = reviewedMedicines.map((medicine) {
        final raw = medicine.displayName.trim();

        return MedicineSearchRequest(
          rawText: raw,
          normalizedText: MedicineNormalizer.normalize(raw),
          strength: MedicineNormalizer.extractStrength(raw),
          dosageForm: MedicineNormalizer.extractDosageForm(raw),
          baseName: MedicineNormalizer.extractBaseName(raw),
          searchTokens: MedicineNormalizer.buildSearchTokens(raw),
          resolvedDisplayName: raw,
        );
      }).toList();

      searchController.clearAll();
      searchController.setSearchSource('prescription');
      searchController.setExtractedText(text);
      searchController.setRequests(reviewedRequests);

      /// 3) اختيار المستفيد بنفس السلكتور
      final beneficiaries = [
        const BeneficiaryModel(
          id: 'self',
          name: 'أنا',
          relation: 'أنا',
          type: 'self',
        ),
        ..._familyController.members.map(
              (member) => BeneficiaryModel(
            id: member.id,
            name: member.name,
            relation: member.relation ?? 'فرد من العائلة',
            type: 'family',
          ),
        ),
      ];

      final beneficiary = await showModalBottomSheet<BeneficiaryModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return BeneficiarySelectorSheet(
            beneficiaries: beneficiaries,
          );
        },
      );

      if (beneficiary == null) return;

      searchController.setBeneficiary(beneficiary);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultsPage(
            medicines: reviewedMedicines,
            beneficiary: beneficiary,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5EABD6),
              Color(0xFF7BC4EA),
              Color(0xFF9BD8F0),
            ],
            stops: [0.1, 0.5, 0.9],
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // شريط اختيار المسافة
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Iconsax.location,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "المسافة: ${widget.selectedDistance.toStringAsFixed(0)} كم",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _tempDistance,
                                min: 1,
                                max: 20,
                                divisions: 19,
                                label: _tempDistance.toStringAsFixed(0),
                                activeColor: Colors.white,
                                inactiveColor: Colors.white38,
                                onChanged: (value) {
                                  setState(() {
                                    _tempDistance = value;
                                  });
                                },
                                onChangeEnd: (value) {
                                  widget.onDistanceChanged(value);
                                },
                              ),
                            ),
                            PopupMenuButton<double>(
                              icon: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Iconsax.arrow_down_1,
                                      color: Color(0xFF5EABD6),
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "اختر",
                                      style: TextStyle(
                                        color: Color(0xFF5EABD6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onSelected: (value) {
                                setState(() {
                                  _tempDistance = value;
                                });
                                widget.onDistanceChanged(value);
                              },
                              itemBuilder: (context) => _distanceOptions.map((distance) {
                                return PopupMenuItem(
                                  value: distance,
                                  child: Text("${distance.toStringAsFixed(0)} كم"),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // القسم العلوي (البطاقات)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            "الصيدليات القريبة (${widget.pharmacies.length})",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!widget.isLoading && widget.pharmacies.isNotEmpty)
                        ValueListenableBuilder<int>(
                          valueListenable: _currentIndexNotifier,
                          builder: (context, currentIndex, _) {
                            return Column(
                              children: [
                                SizedBox(
                                  height: isSmallScreen ? 180 : 200,
                                  child: PageView.builder(
                                    controller: _pageController,
                                    itemCount: widget.pharmacies.length,
                                    onPageChanged: (i) => _currentIndexNotifier.value = i,
                                    itemBuilder: (context, index) {
                                      return AnimatedScale(
                                        scale: currentIndex == index ? 1 : 0.88,
                                        duration: const Duration(milliseconds: 300),
                                        child: PharmacyGlassCard(
                                          pharmacy: widget.pharmacies[index],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    widget.pharmacies.length,
                                        (i) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: currentIndex == i ? 14 : 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: currentIndex == i
                                            ? Colors.white
                                            : Colors.white54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          },
                        )                      else if (!widget.isLoading && widget.pharmacies.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              "لا توجد صيدليات في هذا النطاق",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // الجزء السفلي (الخريطة)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      child: widget.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : MapTab(
                        currentPosition: widget.currentPosition,
                        pharmacies: widget.pharmacies,
                        allPharmacies: widget.allPharmacies,
                        onRefresh: widget.onRefresh,
                        selectedDistance: widget.selectedDistance,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // الأزرار العائمة الزجاجية
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassFAB(
                      icon: Iconsax.search_normal,
                      label: "بحث عن دواء",
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManualMedicineSearchPage(),
                          ),
                        );
                      },                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(width: 12),
                    _buildGlassFAB(
                      icon: Icons.add,
                      label: "رفع وصفة",
                      color: const Color(0xFF5EABD6),
                      onTap: () => showImageSourceDialog(
                        context: context,
                        onPickImage: (source) async {
                          setState(() => _isLoading = true);
                          try {
                            final imageFile = await FileUtils.pickImage(source);
                            if (imageFile != null) {
                              final confirmed = await _showPreviewDialog(imageFile, 'image');
                              if (confirmed) {
                                final extractedText = await FileUtils.extractTextFromImage(imageFile);
                                setState(() {
                                  _selectedFile = imageFile;
                                  _fileType = 'image';
                                  _extractedText = extractedText;
                                });
                                if (mounted) {
                                  await _processExtractedText(extractedText);                                }
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        onPickPDF: () async {
                          setState(() => _isLoading = true);
                          try {
                            final pdfFile = await FileUtils.pickPDF();
                            if (pdfFile != null) {
                              final confirmed = await _showPreviewDialog(pdfFile, 'pdf');
                              if (confirmed) {
                                final extractedText = await FileUtils.extractTextFromPDF(pdfFile);
                                setState(() {
                                  _selectedFile = pdfFile;
                                  _fileType = 'pdf';
                                  _extractedText = extractedText;
                                });
                                if (mounted) {
                                  await _processExtractedText(extractedText);                                }
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                      ),
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFAB({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20,
          vertical: isSmallScreen ? 10 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.9),
              color.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentIndexNotifier.dispose();

    super.dispose();
  }
}