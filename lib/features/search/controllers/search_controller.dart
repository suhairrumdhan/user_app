import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';

import '../models/matched_medicine_result.dart';
import '../models/medicine_search_request.dart';
import '../models/pharmacy_search_filters.dart';
import '../models/pharmacy_search_result.dart';
import '../services/medicine_normalizer.dart';
import '../services/medicine_search_service.dart';

class SearchController extends GetxController {
  final MedicineSearchService _searchService;

  SearchController({MedicineSearchService? searchService})
      : _searchService = searchService ?? MedicineSearchService();

  final RxList<MedicineSearchRequest> requestedMedicines =
      <MedicineSearchRequest>[].obs;

  final Rxn<BeneficiaryModel> selectedBeneficiary = Rxn<BeneficiaryModel>();

  final RxMap<String, PharmacyModel> pharmaciesById = <String, PharmacyModel>{}.obs;

  final Rx<PharmacySearchFilters> filters =
      const PharmacySearchFilters().obs;

  final RxList<PharmacySearchResult> results =
      <PharmacySearchResult>[].obs;

  final RxBool isLoading = false.obs;
  final RxString searchSource = 'manual'.obs; // manual / prescription
  final RxString extractedText = ''.obs;
  final RxString errorMessage = ''.obs;

  Future<void> _loadPharmaciesByIds(List<String> pharmacyIds) async {
    pharmaciesById.clear();

    if (pharmacyIds.isEmpty) return;

    final ids = pharmacyIds.toSet().toList();

    const chunkSize = 10;
    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize).toList();

      final snapshot = await FirebaseFirestore.instance
          .collection('pharmacies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final pharmacy = PharmacyModel.fromFirestore(doc);
        pharmaciesById[pharmacy.id] = pharmacy;
      }
    }
  }

  List<PharmacyModel> get displayResults {
    return results
        .where((result) => pharmaciesById.containsKey(result.pharmacyId))
        .map(
          (result) => PharmacyModel.fromSearchResult(
        result,
        pharmacy: pharmaciesById[result.pharmacyId]!,
      ),
    )
        .toList();
  }

  void replaceMatchedMedicine({
    required String pharmacyId,
    required String requestedName,
    required MatchedMedicineResult newSelection,
  }) {
    final index = results.indexWhere((r) => r.pharmacyId == pharmacyId);
    if (index == -1) return;

    final oldResult = results[index];

    final updatedMatches = oldResult.matchedMedicines.map((item) {
      if (item.requestedName == requestedName) {
        final oldSelected = item;

        final mergedAlternatives = <MatchedMedicineResult>[
          oldSelected.copyWith(similarMatches: const []),
          ...item.similarMatches.where(
                (e) => e.matchedMedicineId != newSelection.matchedMedicineId,
          ),
        ];

        return newSelection.copyWith(
          similarMatches: mergedAlternatives,
        );
      }
      return item;
    }).toList();

    final newTotalPrice = updatedMatches.fold<double>(
      0,
          (sum, item) => sum + item.price,
    );

    final updatedResult = oldResult.copyWith(
      matchedMedicines: updatedMatches,
      totalEstimatedPrice: newTotalPrice,
    );

    results[index] = updatedResult;

    if (pharmaciesById.containsKey(pharmacyId)) {
      final oldPharmacy = pharmaciesById[pharmacyId]!;
      pharmaciesById[pharmacyId] = oldPharmacy.copyWith(
        matchedMedicines: updatedMatches,
        totalEstimatedPrice: newTotalPrice,
      );
    }
  }

  void setSearchSource(String source) {
    searchSource.value = source;
  }

  void setExtractedText(String text) {
    extractedText.value = text;
  }

  void setBeneficiary(BeneficiaryModel beneficiary) {
    selectedBeneficiary.value = beneficiary;
  }

  void setRequests(List<MedicineSearchRequest> requests) {
    requestedMedicines.assignAll(requests);
  }

  void addManualMedicine(String rawText) {
    final cleaned = rawText.trim();
    if (cleaned.isEmpty) return;

    final normalized = MedicineNormalizer.normalize(cleaned);

    final exists = requestedMedicines.any(
          (item) => item.normalizedText == normalized,
    );

    if (exists) return;

    requestedMedicines.add(
      MedicineSearchRequest(
        rawText: cleaned,
        normalizedText: normalized,
        strength: MedicineNormalizer.extractStrength(cleaned),
        dosageForm: MedicineNormalizer.extractDosageForm(cleaned),
      ),
    );
  }

  void removeMedicineAt(int index) {
    if (index < 0 || index >= requestedMedicines.length) return;
    requestedMedicines.removeAt(index);
  }

  void updateFilters(PharmacySearchFilters newFilters) {
    filters.value = newFilters;
  }

  void updateMaxDistance(double value) {
    filters.value = filters.value.copyWith(maxDistanceKm: value);
  }

  void updateInsuranceOnly(bool value) {
    filters.value = filters.value.copyWith(insuranceOnly: value);
  }

  void updateAvailableNowOnly(bool value) {
    filters.value = filters.value.copyWith(availableNowOnly: value);
  }

  void updateFullMatchOnly(bool value) {
    filters.value = filters.value.copyWith(fullMatchOnly: value);
  }

  void updateAlternativesAllowed(bool value) {
    filters.value = filters.value.copyWith(alternativesAllowed: value);
  }

  void updateSortBy(String value) {
    filters.value = filters.value.copyWith(sortBy: value);
  }

  Future<void> runSearch({
    List<String> userInsuranceCodes = const [],
    double? userLat,
    double? userLng,
  }) async {
    if (requestedMedicines.isEmpty) {
      errorMessage.value = 'لا توجد أدوية للبحث';
      results.clear();
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final searchResults = await _searchService.searchPharmacies(
        requests: requestedMedicines,
        filters: filters.value,
        userInsuranceCodes: userInsuranceCodes,
        userLat: userLat,
        userLng: userLng,
      );

      results.assignAll(searchResults);

      final pharmacyIds = searchResults
          .map((e) => e.pharmacyId)
          .where((e) => e.trim().isNotEmpty)
          .toList();

      await _loadPharmaciesByIds(pharmacyIds);
      if (searchResults.isEmpty) {
        errorMessage.value = 'لم يتم العثور على نتائج مناسبة';
      }
    } catch (e) {
      errorMessage.value = 'حدث خطأ أثناء البحث';
      results.clear();
    } finally {
      isLoading.value = false;
    }
  }

  void clearResults() {
    results.clear();
    errorMessage.value = '';
  }

  void clearAll() {
    requestedMedicines.clear();
    selectedBeneficiary.value = null;
    filters.value = const PharmacySearchFilters();
    results.clear();
    extractedText.value = '';
    searchSource.value = 'manual';
    errorMessage.value = '';
  }
}