import '../models/medicine_search_request.dart';
import '../models/matched_medicine_result.dart';
import 'medicine_normalizer.dart';

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
    final String scientificName =
    (medicineData['scientificName'] ?? '').toString().trim();

    if (name.isEmpty) return null;

    final bool isAvailable = _isAvailable(medicineData);
    if (!isAvailable) return null;

    final String normalizedRequest = request.normalizedText;
    final String normalizedName = MedicineNormalizer.normalize(name);
    final String normalizedScientific =
    MedicineNormalizer.normalize(scientificName);

    final String? medicineStrength = _extractMedicineStrength(medicineData, name);
    final String? medicineDosageForm =
    _extractMedicineDosageForm(medicineData, name);

    double score = 0;
    String matchType = '';
    bool matched = false;

    // 1) exact name
    if (normalizedRequest.isNotEmpty && normalizedRequest == normalizedName) {
      score = 100;
      matchType = MedicineMatchType.exactName;
      matched = true;
    }

    // 2) exact scientific
    else if (normalizedScientific.isNotEmpty &&
        normalizedRequest == normalizedScientific) {
      score = 95;
      matchType = MedicineMatchType.exactScientific;
      matched = true;
    }

    // 3) contains name
    else if (_safeContains(normalizedName, normalizedRequest)) {
      score = 85;
      matchType = MedicineMatchType.containsName;
      matched = true;
    }

    // 4) contains scientific
    else if (normalizedScientific.isNotEmpty &&
        _safeContains(normalizedScientific, normalizedRequest)) {
      score = 82;
      matchType = MedicineMatchType.containsScientific;
      matched = true;
    }

    // 5) brand hint
    else if (request.hasBrandHint) {
      final brandNorm =
      MedicineNormalizer.normalize(request.parsedBrandName!.trim());

      if (brandNorm.isNotEmpty && brandNorm == normalizedName) {
        score = 92;
        matchType = MedicineMatchType.exactName;
        matched = true;
      } else if (brandNorm.isNotEmpty &&
          _safeContains(normalizedName, brandNorm)) {
        score = 84;
        matchType = MedicineMatchType.containsName;
        matched = true;
      }
    }

    // 6) scientific hint
    if (!matched && request.hasScientificHint) {
      final scientificHint =
      MedicineNormalizer.normalize(request.parsedScientificName!.trim());

      if (scientificHint.isNotEmpty && scientificHint == normalizedScientific) {
        score = 93;
        matchType = MedicineMatchType.exactScientific;
        matched = true;
      } else if (scientificHint.isNotEmpty &&
          _safeContains(normalizedScientific, scientificHint)) {
        score = 83;
        matchType = MedicineMatchType.containsScientific;
        matched = true;
      }
    }

    // 7) fuzzy on name
    if (!matched) {
      final fuzzyNameScore =
      MedicineNormalizer.similarityScore(normalizedRequest, normalizedName);

      if (fuzzyNameScore >= 0.86) {
        score = 70 + (fuzzyNameScore * 20);
        matchType = MedicineMatchType.fuzzyName;
        matched = true;
      }
    }

    // 8) fuzzy on scientific
    if (!matched && normalizedScientific.isNotEmpty) {
      final fuzzyScientificScore = MedicineNormalizer.similarityScore(
        normalizedRequest,
        normalizedScientific,
      );

      if (fuzzyScientificScore >= 0.86) {
        score = 68 + (fuzzyScientificScore * 20);
        matchType = MedicineMatchType.fuzzyScientific;
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

    final double price = _resolvePrice(medicineData);
    final bool soldByPiece = medicineData['sellByPiece'] == true;
    final String? unit = medicineData['unit']?.toString();

    return MatchedMedicineResult(
      requestedName: request.rawText,
      pharmacyId: pharmacyId,
      matchedMedicineId: medicineId.isNotEmpty ? medicineId : name,
      matchedMedicineName: name,
      matchedScientificName:
      scientificName.isNotEmpty ? scientificName : null,
      price: price,
      soldByPiece: soldByPiece,
      unit: unit,
      availableQuantity: _toInt(medicineData['quantity']),
      availablePieceQuantity: _toInt(medicineData['pieceQuantity']),
      isAvailable: isAvailable,
      matchScore: score,
      matchType: matchType,
      isAlternative: false,
    );
  }

  static MatchedMedicineResult? findBestMatch({
    required MedicineSearchRequest request,
    required List<Map<String, dynamic>> pharmacyMedicines,
  }) {
    MatchedMedicineResult? best;

    for (final med in pharmacyMedicines) {
      final result = matchMedicine(
        request: request,
        medicineData: med,
      );

      if (result == null) continue;

      if (best == null) {
        best = result;
        continue;
      }

      if (result.matchScore > best.matchScore) {
        best = result;
        continue;
      }

      if (result.matchScore == best.matchScore &&
          result.price < best.price) {
        best = result;
      }
    }

    return best;
  }

  static bool _isAvailable(Map<String, dynamic> medicineData) {
    final dynamic availableField = medicineData['available'];
    if (availableField is bool) return availableField;

    final int quantity = _toInt(medicineData['quantity']);
    final int pieceQuantity = _toInt(medicineData['pieceQuantity']);

    return quantity > 0 || pieceQuantity > 0;
  }

  static double _resolvePrice(Map<String, dynamic> medicineData) {
    final bool sellByPiece = medicineData['sellByPiece'] == true;
    final double piecePrice = _toDouble(medicineData['piecePrice']);
    final double sellingPrice = _toDouble(medicineData['sellingPrice']);

    if (sellByPiece && piecePrice > 0) {
      return piecePrice;
    }

    return sellingPrice;
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

  static bool _safeContains(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (b.length < 3) return false;
    return a.contains(b) || b.contains(a);
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}