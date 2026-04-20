import 'matched_medicine_result.dart';

class PharmacySearchResult {
  final String pharmacyId;
  final String pharmacyName;

  final double distanceKm;
  final double rating;

  final bool supportsInsurance;
  final bool isOpenNow;

  final double totalEstimatedPrice;
  final double pharmacyScore;

  final List<MatchedMedicineResult> matchedMedicines;
  final List<String> missingMedicines;
  final List<String> matchedInsuranceCodes;

  const PharmacySearchResult({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.distanceKm,
    required this.rating,
    required this.supportsInsurance,
    required this.isOpenNow,
    required this.totalEstimatedPrice,
    required this.pharmacyScore,
    required this.matchedMedicines,
    required this.missingMedicines,
    this.matchedInsuranceCodes = const [],
  });
  PharmacySearchResult copyWith({
    String? pharmacyId,
    String? pharmacyName,
    double? distanceKm,
    double? rating,
    bool? supportsInsurance,
    bool? isOpenNow,
    double? totalEstimatedPrice,
    double? pharmacyScore,
    List<MatchedMedicineResult>? matchedMedicines,
    List<String>? missingMedicines,
    List<String>? matchedInsuranceCodes,
  }) {
    return PharmacySearchResult(
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating ?? this.rating,
      supportsInsurance: supportsInsurance ?? this.supportsInsurance,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      totalEstimatedPrice: totalEstimatedPrice ?? this.totalEstimatedPrice,
      pharmacyScore: pharmacyScore ?? this.pharmacyScore,
      matchedMedicines: matchedMedicines ?? this.matchedMedicines,
      missingMedicines: missingMedicines ?? this.missingMedicines,
      matchedInsuranceCodes: matchedInsuranceCodes ?? this.matchedInsuranceCodes,
    );
  }
  int get matchedCount => matchedMedicines.length;

  int get missingCount => missingMedicines.length;

  bool get hasFullMatch => missingMedicines.isEmpty;

  bool get hasPartialMatch =>
      matchedMedicines.isNotEmpty && missingMedicines.isNotEmpty;

  double get matchCoverage {
    final total = matchedMedicines.length + missingMedicines.length;
    if (total == 0) return 0;
    return matchedMedicines.length / total;
  }

  double get averageMatchScore {
    if (matchedMedicines.isEmpty) return 0;
    final total = matchedMedicines.fold<double>(
      0,
          (sum, item) => sum + item.matchScore,
    );
    return total / matchedMedicines.length;
  }

  @override
  String toString() {
    return 'PharmacySearchResult('
        'pharmacyId: $pharmacyId, '
        'pharmacyName: $pharmacyName, '
        'distanceKm: $distanceKm, '
        'rating: $rating, '
        'supportsInsurance: $supportsInsurance, '
        'isOpenNow: $isOpenNow, '
        'totalEstimatedPrice: $totalEstimatedPrice, '
        'pharmacyScore: $pharmacyScore, '
        'matchedCount: ${matchedMedicines.length}, '
        'missingCount: ${missingMedicines.length}'
        'matchedInsuranceCodes: ${matchedInsuranceCodes}'
        ')';
  }
}