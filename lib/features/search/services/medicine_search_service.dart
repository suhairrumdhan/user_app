import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/medicine_search_request.dart';
import '../models/pharmacy_search_filters.dart';
import '../models/pharmacy_search_result.dart';
import '../models/matched_medicine_result.dart';
import 'medicine_matcher.dart';
import 'medicine_normalizer.dart';

class MedicineSearchService {
  final FirebaseFirestore _firestore;

  MedicineSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<PharmacySearchResult>> searchPharmacies({
    required List<MedicineSearchRequest> requests,
    required PharmacySearchFilters filters,
    List<String> userInsuranceCodes = const [],
    double? userLat,
    double? userLng,
  }) async {
    if (requests.isEmpty) {
      debugPrint('❌ searchPharmacies: requests is empty');
      return [];
    }

    debugPrint('🔎 searchPharmacies started');
    debugPrint('🔎 requests count: ${requests.length}');
    for (final r in requests) {
      debugPrint(
        '   - key="${r.requestKey}" raw="${r.rawText}" normalized="${r.normalizedText}" strength="${r.strength}" form="${r.dosageForm}"',
      );
    }

    final indexSnapshot = await _firestore
        .collection('medicine_search_index')
        .where('available', isEqualTo: true)
        .get();

    debugPrint('📦 index docs fetched: ${indexSnapshot.docs.length}');

    if (indexSnapshot.docs.isEmpty) return [];

    final List<Map<String, dynamic>> indexDocs = indexSnapshot.docs
        .map((doc) => {
      'id': doc.id,
      ...doc.data(),
    })
        .toList();

    final Map<String, List<Map<String, dynamic>>> groupedByPharmacy = {};

    for (final item in indexDocs) {
      final pharmacyId = (item['pharmacyId'] ?? '').toString().trim();
      if (pharmacyId.isEmpty) continue;
      groupedByPharmacy.putIfAbsent(pharmacyId, () => []).add(item);
    }

    debugPrint('🏥 grouped pharmacies: ${groupedByPharmacy.length}');

    final List<PharmacySearchResult> results = [];

    for (final entry in groupedByPharmacy.entries) {
      final pharmacyId = entry.key;
      final pharmacyMedicines = entry.value;

      final result = _evaluatePharmacyFromIndex(
        pharmacyId: pharmacyId,
        pharmacyMedicines: pharmacyMedicines,
        requests: requests,
        filters: filters,
        userInsuranceCodes: userInsuranceCodes,
        userLat: userLat,
        userLng: userLng,
      );

      if (result != null) {
        results.add(result);
      }
    }

    debugPrint('✅ final pharmacy results: ${results.length}');
    return _sortResults(results, filters.sortBy);
  }

  PharmacySearchResult? _evaluatePharmacyFromIndex({
    required String pharmacyId,
    required List<Map<String, dynamic>> pharmacyMedicines,
    required List<MedicineSearchRequest> requests,
    required PharmacySearchFilters filters,
    List<String> userInsuranceCodes = const [],
    double? userLat,
    double? userLng,
  }) {
    if (pharmacyMedicines.isEmpty) return null;

    final first = pharmacyMedicines.first;

    final String pharmacyName =
    (first['pharmacyName'] ?? 'صيدلية').toString().trim();

    final String status =
    (first['status'] ?? '').toString().trim().toLowerCase();
    if (status.isNotEmpty && status != 'approved') {
      debugPrint('⛔ pharmacy skipped بسبب status: $pharmacyName ($status)');
      return null;
    }

    final List<String> acceptedInsuranceCodes = List<String>.from(
      first['acceptedInsuranceCodes'] ?? const [],
    ).map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();

    final List<String> normalizedUserInsuranceCodes = userInsuranceCodes
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final List<String> matchedInsuranceCodes = acceptedInsuranceCodes
        .where((code) => normalizedUserInsuranceCodes.contains(code))
        .toList();

    final bool supportsInsurance = matchedInsuranceCodes.isNotEmpty;

    if (filters.insuranceOnly && !supportsInsurance) {
      debugPrint('⛔ pharmacy skipped بسبب insuranceOnly: $pharmacyName');
      return null;
    }

    final double distanceKm = _calculateDistanceKm(
      pharmacyLat: _toDouble(first['latitude']),
      pharmacyLng: _toDouble(first['longitude']),
      userLat: userLat,
      userLng: userLng,
    );

    if (distanceKm > filters.maxDistanceKm) {
      debugPrint(
        '⛔ pharmacy skipped بسبب distance: $pharmacyName -> $distanceKm km',
      );
      return null;
    }

    final bool isOpenNow = _resolveOpenNow(first);

    if (filters.availableNowOnly && !isOpenNow) {
      debugPrint('⛔ pharmacy skipped بسبب availableNowOnly: $pharmacyName');
      return null;
    }

    final double rating = 0.0;

    final List<MatchedMedicineResult> matchedMedicines = [];
    final List<String> missingMedicines = [];

    for (final request in requests) {
      final candidates = _filterCandidatesForRequest(
        pharmacyMedicines: pharmacyMedicines,
        request: request,
      );

      debugPrint(
        '🧪 pharmacy="$pharmacyName" requestKey="${request.requestKey}" request="${request.rawText}" candidates=${candidates.length}',
      );

      final topMatches = MedicineMatcher.findTopMatches(
        request: request,
        pharmacyMedicines: candidates,
        limit: 5,
      );

      if (topMatches.isEmpty) {
        debugPrint('   ❌ no match for "${request.rawText}" in "$pharmacyName"');
        missingMedicines.add(request.rawText);
      } else {
        final bestMatch = topMatches.first.copyWith(
          requestKey: request.requestKey,
          requestedName: request.rawText,
          isAlternative: false,
        );

        final alternativeMatches = topMatches
            .skip(1)
            .map(
              (item) => item.copyWith(
            requestKey: request.requestKey,
            requestedName: request.rawText,
            isAlternative: true,
            similarMatches: const [],
          ),
        )
            .toList();

        debugPrint(
          '   ✅ matched "${request.rawText}" -> "${bestMatch.matchedMedicineName}" '
              'score=${bestMatch.matchScore} '
              'alternatives=${alternativeMatches.length}',
        );

        matchedMedicines.add(
          bestMatch.copyWith(
            similarMatches: alternativeMatches,
          ),
        );
      }
    }

    if (matchedMedicines.isEmpty) {
      debugPrint(
        '⛔ pharmacy="$pharmacyName" dropped because matchedMedicines is empty',
      );
      return null;
    }

    if (filters.fullMatchOnly && missingMedicines.isNotEmpty) {
      debugPrint(
        '⛔ pharmacy="$pharmacyName" dropped because fullMatchOnly=true',
      );
      return null;
    }

    final double totalEstimatedPrice = _calculateTotalEstimatedPrice(
      matchedMedicines,
    );

    if (filters.minPrice != null && totalEstimatedPrice < filters.minPrice!) {
      return null;
    }

    if (filters.maxPrice != null && totalEstimatedPrice > filters.maxPrice!) {
      return null;
    }

    final double pharmacyScore = _calculatePharmacyScore(
      matchedMedicines: matchedMedicines,
      missingMedicines: missingMedicines,
      distanceKm: distanceKm,
      totalEstimatedPrice: totalEstimatedPrice,
      supportsInsurance: supportsInsurance,
      isOpenNow: isOpenNow,
      rating: rating,
    );

    return PharmacySearchResult(
      pharmacyId: pharmacyId,
      pharmacyName: pharmacyName,
      distanceKm: distanceKm,
      rating: rating,
      supportsInsurance: supportsInsurance,
      isOpenNow: isOpenNow,
      totalEstimatedPrice: totalEstimatedPrice,
      pharmacyScore: pharmacyScore,
      matchedMedicines: matchedMedicines,
      missingMedicines: missingMedicines,
      matchedInsuranceCodes: matchedInsuranceCodes,
    );
  }

  List<Map<String, dynamic>> _filterCandidatesForRequest({
    required List<Map<String, dynamic>> pharmacyMedicines,
    required MedicineSearchRequest request,
  }) {
    final normalizedRequest = MedicineNormalizer.normalize(request.rawText);
    final requestBase =
        request.baseName ?? MedicineNormalizer.extractBaseName(request.rawText);
    final requestTokens = request.searchTokens.isNotEmpty
        ? request.searchTokens
        : MedicineNormalizer.buildSearchTokens(request.rawText);

    final List<Map<String, dynamic>> exact = [];
    final List<Map<String, dynamic>> contains = [];
    final List<Map<String, dynamic>> fuzzy = [];

    for (final med in pharmacyMedicines) {
      final name = (med['medicineName'] ?? '').toString().trim();
      final scientific = (med['scientificName'] ?? '').toString().trim();

      if (name.isEmpty && scientific.isEmpty) continue;

      final normalizedName = MedicineNormalizer.normalize(name);
      final normalizedScientific = MedicineNormalizer.normalize(scientific);

      final baseName = MedicineNormalizer.extractBaseName(name);
      final baseScientific = MedicineNormalizer.extractBaseName(scientific);

      bool isExact = false;
      bool isContains = false;
      bool isFuzzy = false;

      if (normalizedRequest == normalizedName ||
          normalizedRequest == normalizedScientific ||
          (requestBase.isNotEmpty &&
              (requestBase == baseName || requestBase == baseScientific))) {
        isExact = true;
      }

      if (!isExact) {
        if (MedicineNormalizer.containsNormalized(name, request.rawText) ||
            MedicineNormalizer.containsNormalized(scientific, request.rawText)) {
          isContains = true;
        }

        if (!isContains && requestTokens.isNotEmpty) {
          for (final token in requestTokens) {
            if (token.trim().length < 3) continue;

            if (normalizedName.contains(token) ||
                normalizedScientific.contains(token)) {
              isContains = true;
              break;
            }
          }
        }

        if (!isContains && requestBase.isNotEmpty) {
          final reqParts =
          requestBase.split(' ').where((e) => e.isNotEmpty).toList();
          final nameParts =
          baseName.split(' ').where((e) => e.isNotEmpty).toList();
          final sciParts =
          baseScientific.split(' ').where((e) => e.isNotEmpty).toList();

          if (reqParts.isNotEmpty &&
              ((nameParts.isNotEmpty && reqParts.first == nameParts.first) ||
                  (sciParts.isNotEmpty && reqParts.first == sciParts.first))) {
            isContains = true;
          }
        }
      }

      if (!isExact && !isContains) {
        final fuzzyName =
        MedicineNormalizer.similarityScore(request.rawText, name);
        final fuzzyScientific =
        MedicineNormalizer.similarityScore(request.rawText, scientific);

        if (fuzzyName >= 0.60 || fuzzyScientific >= 0.60) {
          isFuzzy = true;
        }
      }

      if (isExact) {
        exact.add(med);
      } else if (isContains) {
        contains.add(med);
      } else if (isFuzzy) {
        fuzzy.add(med);
      }
    }

    final combined = <Map<String, dynamic>>[
      ...exact,
      ...contains,
      ...fuzzy,
    ];

    if (combined.isEmpty) return [];

    final Map<String, Map<String, dynamic>> unique = {};

    for (final med in combined) {
      final key = (med['medicineId'] ?? med['id'] ?? med['medicineName'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      if (key.isEmpty) continue;
      unique.putIfAbsent(key, () => med);
    }

    return unique.values.toList();
  }

  double _calculateTotalEstimatedPrice(List<MatchedMedicineResult> matches) {
    double total = 0;
    for (final item in matches) {
      total += item.price;
    }
    return total;
  }

  double _calculatePharmacyScore({
    required List<MatchedMedicineResult> matchedMedicines,
    required List<String> missingMedicines,
    required double distanceKm,
    required double totalEstimatedPrice,
    required bool supportsInsurance,
    required bool isOpenNow,
    required double rating,
  }) {
    final int matchedCount = matchedMedicines.length;
    final int missingCount = missingMedicines.length;

    final double averageMatchScore = matchedMedicines.isEmpty
        ? 0
        : matchedMedicines
        .map((e) => e.matchScore)
        .reduce((a, b) => a + b) /
        matchedMedicines.length;

    double score = 0;

    score += matchedCount * 100;
    score -= missingCount * 120;
    score += averageMatchScore * 1.5;
    score -= distanceKm * 5;
    score -= totalEstimatedPrice * 0.15;

    if (supportsInsurance) score += 40;
    if (isOpenNow) score += 20;

    score += rating * 8;

    return score;
  }

  List<PharmacySearchResult> _sortResults(
      List<PharmacySearchResult> results,
      String sortBy,
      ) {
    final sorted = [...results];

    switch (sortBy) {
      case PharmacySearchSort.cheapest:
        sorted.sort(
              (a, b) => a.totalEstimatedPrice.compareTo(b.totalEstimatedPrice),
        );
        break;

      case PharmacySearchSort.bestRated:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;

      case PharmacySearchSort.bestMatch:
        sorted.sort((a, b) => b.pharmacyScore.compareTo(a.pharmacyScore));
        break;

      case PharmacySearchSort.nearest:
      default:
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
    }

    return sorted;
  }

  bool _resolveOpenNow(Map<String, dynamic> pharmacyData) {
    final is24Hours = pharmacyData['is24Hours'] == true;
    final isOnline = pharmacyData['isOnline'] == true;

    if (is24Hours) return true;
    return isOnline;
  }

  double _calculateDistanceKm({
    required double pharmacyLat,
    required double pharmacyLng,
    double? userLat,
    double? userLng,
  }) {
    if (userLat == null || userLng == null) {
      return 0;
    }

    if (pharmacyLat == 0 && pharmacyLng == 0) {
      return 0;
    }

    return _haversineDistanceKm(
      userLat,
      userLng,
      pharmacyLat,
      pharmacyLng,
    );
  }

  double _haversineDistanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2).toDouble();

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}