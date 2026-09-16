import '../models/medicine_search_request.dart';
import '../models/matched_medicine_result.dart';
import 'medicine_normalizer.dart';
import 'medicine_identity.dart';
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
    if (!MedicineIdentity.matches(
      requestedName: request.rawText,
      availableName: name,
      requestedStrength: request.strength,
      availableStrength: medicineData['strength']?.toString(),
      requestedForm: request.dosageForm,
      availableForm:
          medicineData['dosageForm']?.toString() ??
          medicineData['unit']?.toString(),
    )) {
      return null;
    }
    const double score = 100;
    const String matchType = 'exact_name_and_requested_details';

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
}
