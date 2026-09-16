import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/medicine_search_request.dart';
import '../models/pharmacy_search_filters.dart';
import '../models/pharmacy_search_result.dart';
import '../models/matched_medicine_result.dart';
import 'medicine_matcher.dart';
import 'medicine_normalizer.dart';
import 'pharmacy_distance.dart';
import '../../../shared/availability_policy.dart';

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

    final indexDocs = await _fetchCandidateIndexDocuments(requests);
    debugPrint('📦 candidate index docs fetched: ${indexDocs.length}');
    if (indexDocs.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> groupedByPharmacy = {};

    for (final item in indexDocs) {
      final pharmacyId = (item['pharmacyId'] ?? '').toString().trim();
      if (pharmacyId.isEmpty) continue;
      groupedByPharmacy.putIfAbsent(pharmacyId, () => []).add(item);
    }

    debugPrint('🏥 grouped pharmacies: ${groupedByPharmacy.length}');

    final pharmacyMetadata = await _loadApprovedPharmacyMetadata(
      groupedByPharmacy.keys.toList(),
    );

    final List<PharmacySearchResult> results = [];

    for (final entry in groupedByPharmacy.entries) {
      final pharmacyId = entry.key;
      final pharmacyMedicines = entry.value;
      final pharmacyData = pharmacyMetadata[pharmacyId];
      if (pharmacyData == null) continue;

      final result = _evaluatePharmacyFromIndex(
        pharmacyId: pharmacyId,
        pharmacyMedicines: pharmacyMedicines,
        pharmacyData: pharmacyData,
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

  Future<List<Map<String, dynamic>>> _fetchCandidateIndexDocuments(
    List<MedicineSearchRequest> requests,
  ) async {
    final tokens = <String>{};
    for (final request in requests) {
      tokens.addAll(request.searchTokens);
      tokens.addAll(MedicineNormalizer.buildSearchTokens(request.rawText));
      final base =
          request.baseName ??
          MedicineNormalizer.extractBaseName(request.rawText);
      if (base.trim().isNotEmpty) tokens.add(base.trim());
    }

    final normalizedTokens = tokens
        .map(MedicineNormalizer.normalize)
        .where((token) => token.length >= 2)
        .toSet()
        .toList();
    if (normalizedTokens.isEmpty) return [];

    final candidates = <String, Map<String, dynamic>>{};
    const chunkSize = 30;
    for (var i = 0; i < normalizedTokens.length; i += chunkSize) {
      final chunk = normalizedTokens.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore
          .collection('medicine_search_index')
          .where('searchTokens', arrayContainsAny: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final data = <String, dynamic>{'id': doc.id, ...doc.data()};
        if (_isAvailableIndexItem(data)) candidates[doc.id] = data;
      }
    }
    return candidates.values.toList();
  }

  Future<Map<String, Map<String, dynamic>>> _loadApprovedPharmacyMetadata(
    List<String> pharmacyIds,
  ) async {
    final approved = <String, Map<String, dynamic>>{};
    const chunkSize = 10;
    for (var i = 0; i < pharmacyIds.length; i += chunkSize) {
      final chunk = pharmacyIds.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore
          .collection('pharmacies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      await Future.wait(
        snapshot.docs.map((doc) async {
          final data = doc.data();
          if (!pharmacyVisibleInSearch(data)) {
            return;
          }
          Map<String, dynamic>? hoursData;
          try {
            final hours = await doc.reference
                .collection('settings')
                .doc('businessHours')
                .get();
            hoursData = hours.data();
          } on FirebaseException catch (error) {
            debugPrint(
              'تعذر تحميل ساعات عمل ${doc.id}; سيتم استخدام بيانات الصيدلية: '
              '${error.code}',
            );
          }
          final location = data['location'];
          final locationMap = location is Map
              ? Map<String, dynamic>.from(location)
              : const <String, dynamic>{};
          approved[doc.id] = <String, dynamic>{
            ...data,
            'pharmacyId': doc.id,
            'latitude': locationMap['latitude'] ?? data['latitude'],
            'longitude': locationMap['longitude'] ?? data['longitude'],
            'workingHours': hoursData ?? data['workingHours'],
          };
        }),
      );
    }
    return approved;
  }

  bool _isAvailableIndexItem(Map<String, dynamic> data) {
    return medicineAvailableForSearch(data);
  }

  PharmacySearchResult? _evaluatePharmacyFromIndex({
    required String pharmacyId,
    required List<Map<String, dynamic>> pharmacyMedicines,
    required Map<String, dynamic> pharmacyData,
    required List<MedicineSearchRequest> requests,
    required PharmacySearchFilters filters,
    List<String> userInsuranceCodes = const [],
    double? userLat,
    double? userLng,
  }) {
    if (pharmacyMedicines.isEmpty) return null;

    final first = <String, dynamic>{
      ...pharmacyMedicines.first,
      ...pharmacyData,
    };

    final String pharmacyName = (first['pharmacyName'] ?? 'صيدلية')
        .toString()
        .trim();

    final String status = (first['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
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

    final double? calculatedDistanceKm = PharmacyDistance.betweenKm(
      pharmacyLat: _toNullableDouble(first['latitude']),
      pharmacyLng: _toNullableDouble(first['longitude']),
      userLat: userLat,
      userLng: userLng,
    );

    if (calculatedDistanceKm != null &&
        calculatedDistanceKm > filters.maxDistanceKm) {
      debugPrint(
        '⛔ pharmacy skipped بسبب distance: '
        '$pharmacyName -> $calculatedDistanceKm km',
      );
      return null;
    }

    // -1 means that distance is unknown. It must never be treated as 0 km.
    final double distanceKm = calculatedDistanceKm ?? -1;

    final bool isOpenNow = _resolveOpenNow(first);

    if (filters.availableNowOnly && !isOpenNow) {
      debugPrint('⛔ pharmacy skipped بسبب availableNowOnly: $pharmacyName');
      return null;
    }

    final double rating = _resolveRating(first);

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

        final alternativeMatches =
            (filters.alternativesAllowed
                    ? topMatches.skip(1)
                    : const Iterable<MatchedMedicineResult>.empty())
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
          bestMatch.copyWith(similarMatches: alternativeMatches),
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
            MedicineNormalizer.containsNormalized(
              scientific,
              request.rawText,
            )) {
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
          final reqParts = requestBase
              .split(' ')
              .where((e) => e.isNotEmpty)
              .toList();
          final nameParts = baseName
              .split(' ')
              .where((e) => e.isNotEmpty)
              .toList();
          final sciParts = baseScientific
              .split(' ')
              .where((e) => e.isNotEmpty)
              .toList();

          if (reqParts.isNotEmpty &&
              ((nameParts.isNotEmpty && reqParts.first == nameParts.first) ||
                  (sciParts.isNotEmpty && reqParts.first == sciParts.first))) {
            isContains = true;
          }
        }
      }

      if (!isExact && !isContains) {
        final fuzzyName = MedicineNormalizer.similarityScore(
          request.rawText,
          name,
        );
        final fuzzyScientific = MedicineNormalizer.similarityScore(
          request.rawText,
          scientific,
        );

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

    final combined = <Map<String, dynamic>>[...exact, ...contains, ...fuzzy];

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
        : matchedMedicines.map((e) => e.matchScore).reduce((a, b) => a + b) /
              matchedMedicines.length;

    double score = 0;

    score += matchedCount * 100;
    score -= missingCount * 120;
    score += averageMatchScore * 1.5;
    if (distanceKm >= 0) {
      score -= distanceKm * 5;
    }
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
        sorted.sort((a, b) {
          final aKnown = a.distanceKm >= 0;
          final bKnown = b.distanceKm >= 0;

          if (aKnown && !bKnown) return -1;
          if (!aKnown && bKnown) return 1;
          if (!aKnown && !bKnown) return 0;
          return a.distanceKm.compareTo(b.distanceKm);
        });
        break;
    }

    return sorted;
  }

  bool _resolveOpenNow(Map<String, dynamic> pharmacyData) {
    final is24Hours = pharmacyData['is24Hours'] == true;
    if (is24Hours) return true;

    final hours = pharmacyData['workingHours'];
    if (hours is! Map) return false;
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    final now = DateTime.now();
    final raw = hours[days[now.weekday % 7]];
    final range = _parseBusinessHours(raw);
    if (range == null) return false;
    final current = now.hour * 60 + now.minute;
    if (range.$1 <= range.$2) {
      return current >= range.$1 && current <= range.$2;
    }
    return current >= range.$1 || current <= range.$2;
  }

  (int, int)? _parseBusinessHours(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    final lower = text.toLowerCase();
    if (text.isEmpty ||
        lower == 'closed' ||
        lower == 'close' ||
        lower == 'مغلق' ||
        lower == 'مغلق اليوم') {
      return null;
    }
    if (lower == '24 hours' || lower == '24 ساعة') return (0, 1439);
    final parts = text.split(RegExp(r'\s*-\s*'));
    if (parts.length != 2) return null;
    final open = _parseMinutes(parts[0]);
    final close = _parseMinutes(parts[1]);
    if (open == null || close == null) return null;
    return (open, close);
  }

  int? _parseMinutes(String value) {
    var text = value.trim();
    final lower = text.toLowerCase();
    final isPm = text.contains('م') || lower.contains('pm');
    final isAm = text.contains('ص') || lower.contains('am');
    text = text.replaceAll(RegExp(r'(AM|PM|am|pm|ص|م)'), '').trim();
    final parts = text.split(':');
    var hour = int.tryParse(parts.first.trim());
    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    if (hour == null || hour < 0 || hour > 23 || minute > 59) return null;
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  double _resolveRating(Map<String, dynamic> pharmacyData) {
    for (final key in const ['rating', 'averageRating', 'ratingAverage']) {
      final value = pharmacyData[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
