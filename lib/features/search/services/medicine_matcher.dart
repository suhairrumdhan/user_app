import '../models/medicine_search_request.dart';
import '../models/matched_medicine_result.dart';
import 'medicine_normalizer.dart';
import '../models/medicine_sale_quote.dart';

class MedicineMatcher {
  const MedicineMatcher._();

  /// يطابق request مع document من medicine_search_index
  static MatchedMedicineResult? matchMedicine({
    required MedicineSearchRequest request,
    required Map<String, dynamic> medicineData,
  }) {
    final String pharmacyId = (medicineData['pharmacyId'] ?? '').toString();

    final String medicineId =
        (medicineData['medicineId'] ?? medicineData['id'] ?? '').toString();

    final String name = (medicineData['medicineName'] ?? '').toString().trim();
    final String scientificName = (medicineData['scientificName'] ?? '')
        .toString()
        .trim();

    if (name.isEmpty) return null;

    final quote = MedicineSaleQuote.fromIndex(medicineData);
    if (quote == null) return null;
    final String normalizedRequest = request.normalizedText;
    final String normalizedName = MedicineNormalizer.normalize(name);
    final String normalizedScientific = MedicineNormalizer.normalize(
      scientificName,
    );

    // ✅ الجديد
    final String requestBase =
        request.baseName ??
        MedicineNormalizer.extractBaseName(normalizedRequest);

    final String nameBase = MedicineNormalizer.extractBaseName(normalizedName);

    final List<String> requestTokens = request.searchTokens.isNotEmpty
        ? request.searchTokens
        : MedicineNormalizer.buildSearchTokens(normalizedRequest);

    final String? medicineStrength = _extractMedicineStrength(
      medicineData,
      name,
    );
    final String? medicineDosageForm = _extractMedicineDosageForm(
      medicineData,
      name,
    );

    double score = 0;
    String matchType = '';
    bool matched = false;

    /// 1) BASE NAME MATCH (الأهم)
    if (requestBase.isNotEmpty && nameBase.isNotEmpty) {
      if (requestBase == nameBase) {
        score = 98;
        matchType = 'base_exact';
        matched = true;
      }
    }

    /// 2) FIRST WORD MATCH (PANADOL → PANADOL EXTRA)
    if (!matched && requestBase.isNotEmpty && nameBase.isNotEmpty) {
      final reqParts = requestBase.split(' ');
      final nameParts = nameBase.split(' ');

      if (reqParts.isNotEmpty &&
          nameParts.isNotEmpty &&
          reqParts.first == nameParts.first) {
        score = 92;
        matchType = 'base_family';
        matched = true;
      }
    }

    /// 3) TOKENS MATCH
    if (!matched && requestTokens.isNotEmpty) {
      int hits = 0;

      for (final token in requestTokens) {
        if (token.length < 3) continue;

        if (normalizedName.contains(token) ||
            normalizedScientific.contains(token)) {
          hits++;
        }
      }

      if (hits > 0) {
        score = 80 + (hits * 3);
        matchType = 'token_match';
        matched = true;
      }
    }

    /// 4) CONTAINS (fallback)
    if (!matched &&
        MedicineNormalizer.containsNormalized(
          normalizedName,
          normalizedRequest,
        )) {
      score = 78;
      matchType = 'contains';
      matched = true;
    }

    /// 5) FUZZY (آخر حل)
    if (!matched) {
      final fuzzyNameScore = MedicineNormalizer.similarityScore(
        normalizedRequest,
        normalizedName,
      );

      if (fuzzyNameScore >= 0.85) {
        score = 60 + (fuzzyNameScore * 30);
        matchType = 'fuzzy';
        matched = true;
      }
    }

    if (!matched) return null;

    // تحسين/خصم حسب التركيز والشكل الدوائي
    score = _applyStrengthAdjustment(
      score: score,
      requestStrength: request.strength,
      medicineStrength: medicineStrength,
    );

    score = _applyDosageFormAdjustment(
      score: score,
      requestDosageForm: request.dosageForm,
      medicineDosageForm: medicineDosageForm,
    );

    score = score.clamp(0, 100).toDouble();

    final String? unit = medicineData['unit']?.toString();
    final String? imageUrl = medicineData['imageUrl']?.toString();
    return MatchedMedicineResult(
      requestedName: request.rawText,
      pharmacyId: pharmacyId,
      matchedMedicineId: medicineId.isNotEmpty ? medicineId : name,
      matchedMedicineName: name,
      matchedScientificName: scientificName.isNotEmpty ? scientificName : null,
      price: quote.price,
      soldByPiece: quote.soldByPiece,
      unit: unit,
      availableQuantity: quote.stock.availablePackages,
      availablePieceQuantity: quote.stock.availablePieces,
      isAvailable: true,
      matchScore: score,
      matchType: matchType,
      imageUrl: imageUrl,
      similarMatches: const [],
      isAlternative: false,
    );
  }

  static MatchedMedicineResult? findBestMatch({
    required MedicineSearchRequest request,
    required List<Map<String, dynamic>> pharmacyMedicines,
  }) {
    final topMatches = findTopMatches(
      request: request,
      pharmacyMedicines: pharmacyMedicines,
      limit: 1,
    );

    if (topMatches.isEmpty) return null;
    return topMatches.first;
  }

  static List<MatchedMedicineResult> findTopMatches({
    required MedicineSearchRequest request,
    required List<Map<String, dynamic>> pharmacyMedicines,
    int limit = 5,
  }) {
    final List<MatchedMedicineResult> matches = [];

    for (final med in pharmacyMedicines) {
      final result = matchMedicine(request: request, medicineData: med);

      if (result == null) continue;
      matches.add(result);
    }

    if (matches.isEmpty) return [];

    matches.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;

      final availabilityCompare = b.isAvailable.toString().compareTo(
        a.isAvailable.toString(),
      );
      if (availabilityCompare != 0) return availabilityCompare;

      // Different selling units have no meaningful count ordering.
      final quantityCompare = a.soldByPiece != b.soldByPiece
          ? 0
          : (a.soldByPiece ? b.availablePieceQuantity : b.availableQuantity)
                .compareTo(
                  a.soldByPiece
                      ? a.availablePieceQuantity
                      : a.availableQuantity,
                );
      if (quantityCompare != 0) return quantityCompare;

      return a.price.compareTo(b.price);
    });

    // إزالة التكرار على نفس الاسم المطبع
    final Map<String, MatchedMedicineResult> unique = {};

    for (final item in matches) {
      final key = MedicineNormalizer.normalize(item.matchedMedicineName);

      if (!unique.containsKey(key)) {
        unique[key] = item;
        continue;
      }

      final current = unique[key]!;

      if (item.matchScore > current.matchScore) {
        unique[key] = item;
        continue;
      }

      if (item.matchScore == current.matchScore && item.price < current.price) {
        unique[key] = item;
      }
    }

    final result = unique.values.toList()
      ..sort((a, b) {
        final scoreCompare = b.matchScore.compareTo(a.matchScore);
        if (scoreCompare != 0) return scoreCompare;
        return a.price.compareTo(b.price);
      });

    return result.take(limit).toList();
  }

  static double _applyStrengthAdjustment({
    required double score,
    required String? requestStrength,
    required String? medicineStrength,
  }) {
    if (requestStrength == null || requestStrength.trim().isEmpty) {
      return score;
    }

    if (medicineStrength == null || medicineStrength.trim().isEmpty) {
      return score - 4;
    }

    final a = MedicineNormalizer.normalize(requestStrength);
    final b = MedicineNormalizer.normalize(medicineStrength);

    if (a == b) return score + 8;

    return score - 10;
  }

  static double _applyDosageFormAdjustment({
    required double score,
    required String? requestDosageForm,
    required String? medicineDosageForm,
  }) {
    if (requestDosageForm == null || requestDosageForm.trim().isEmpty) {
      return score;
    }

    if (medicineDosageForm == null || medicineDosageForm.trim().isEmpty) {
      return score - 3;
    }

    final a = MedicineNormalizer.normalize(requestDosageForm);
    final b = MedicineNormalizer.normalize(medicineDosageForm);

    if (a == b) return score + 6;

    return score - 8;
  }

  static String? _extractMedicineStrength(
    Map<String, dynamic> medicineData,
    String fallbackName,
  ) {
    final fromField = medicineData['strength']?.toString();
    if (fromField != null && fromField.trim().isNotEmpty) {
      return MedicineNormalizer.extractStrength(fromField);
    }

    final fromName = MedicineNormalizer.extractStrength(fallbackName);
    if (fromName != null && fromName.trim().isNotEmpty) {
      return fromName;
    }

    final scientificName = medicineData['scientificName']?.toString() ?? '';
    return MedicineNormalizer.extractStrength(scientificName);
  }

  static String? _extractMedicineDosageForm(
    Map<String, dynamic> medicineData,
    String fallbackName,
  ) {
    final unit = medicineData['unit']?.toString();
    if (unit != null && unit.trim().isNotEmpty) {
      final normalizedUnit = MedicineNormalizer.extractDosageForm(unit);
      if (normalizedUnit != null) return normalizedUnit;
    }

    final fromName = MedicineNormalizer.extractDosageForm(fallbackName);
    if (fromName != null) return fromName;

    final scientificName = medicineData['scientificName']?.toString() ?? '';
    return MedicineNormalizer.extractDosageForm(scientificName);
  }
}
