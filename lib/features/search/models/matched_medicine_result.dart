class MatchedMedicineResult {
  final String requestedName;
  final String? imageUrl;
  final List<MatchedMedicineResult> similarMatches;
  final String pharmacyId;
  final String matchedMedicineId;
  final String matchedMedicineName;
  final String? matchedScientificName;

  final double price;
  final bool isAlternative;
  final bool soldByPiece;
  final String? unit;

  final int availableQuantity;
  final int availablePieceQuantity;
  final bool isAvailable;

  final double matchScore;
  final String matchType;

  const MatchedMedicineResult({
    required this.requestedName,
    this.imageUrl,
    this.similarMatches = const [],
    required this.pharmacyId,
    required this.matchedMedicineId,
    required this.matchedMedicineName,
    this.matchedScientificName,
    required this.price,
    this.isAlternative = false,
    this.soldByPiece = false,
    this.unit,
    this.availableQuantity = 0,
    this.availablePieceQuantity = 0,
    this.isAvailable = false,
    required this.matchScore,
    required this.matchType,
  });

  bool get isStrongMatch => matchScore >= 80;


  Map<String, dynamic> toMap() {
    return {
      'requestedName': requestedName,
      'imageUrl': imageUrl,
      'similarMatches': similarMatches.map((e) => e.toMap()).toList(),
      'pharmacyId': pharmacyId,
      'matchedMedicineId': matchedMedicineId,
      'matchedMedicineName': matchedMedicineName,
      'matchedScientificName': matchedScientificName,
      'price': price,
      'isAlternative': isAlternative,
      'soldByPiece': soldByPiece,
      'unit': unit,
      'availableQuantity': availableQuantity,
      'availablePieceQuantity': availablePieceQuantity,
      'isAvailable': isAvailable,
      'matchScore': matchScore,
      'matchType': matchType,
    };
  }


  MatchedMedicineResult copyWith({
    String? requestedName,
    String? pharmacyId,
    String? matchedMedicineId,
    String? matchedMedicineName,
    String? matchedScientificName,
    double? price,
    bool? isAlternative,
    bool? soldByPiece,
    String? unit,
    int? availableQuantity,
    int? availablePieceQuantity,
    bool? isAvailable,
    double? matchScore,
    String? matchType,
    String? imageUrl,
    List<MatchedMedicineResult>? similarMatches,
  }) {
    return MatchedMedicineResult(
      requestedName: requestedName ?? this.requestedName,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      matchedMedicineId: matchedMedicineId ?? this.matchedMedicineId,
      matchedMedicineName: matchedMedicineName ?? this.matchedMedicineName,
      matchedScientificName:
      matchedScientificName ?? this.matchedScientificName,
      price: price ?? this.price,
      isAlternative: isAlternative ?? this.isAlternative,
      soldByPiece: soldByPiece ?? this.soldByPiece,
      unit: unit ?? this.unit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      availablePieceQuantity:
      availablePieceQuantity ?? this.availablePieceQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
      matchScore: matchScore ?? this.matchScore,
      matchType: matchType ?? this.matchType,
      imageUrl: imageUrl ?? this.imageUrl,
      similarMatches: similarMatches ?? this.similarMatches,
    );
  }
  factory MatchedMedicineResult.fromMap(Map<String, dynamic> map) {
    return MatchedMedicineResult(
      requestedName: map['requestedName']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      similarMatches: (map['similarMatches'] as List<dynamic>? ?? [])
          .map((e) => MatchedMedicineResult.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      pharmacyId: map['pharmacyId']?.toString() ?? '',
      matchedMedicineId: map['matchedMedicineId']?.toString() ?? '',
      matchedMedicineName: map['matchedMedicineName']?.toString() ?? '',
      matchedScientificName: map['matchedScientificName']?.toString(),
      price: (map['price'] ?? 0.0).toDouble(),
      isAlternative: map['isAlternative'] ?? false,
      soldByPiece: map['soldByPiece'] ?? false,
      unit: map['unit']?.toString(),
      availableQuantity: map['availableQuantity'] ?? 0,
      availablePieceQuantity: map['availablePieceQuantity'] ?? 0,
      isAvailable: map['isAvailable'] ?? false,
      matchScore: (map['matchScore'] ?? 0.0).toDouble(),
      matchType: map['matchType']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'MatchedMedicineResult('
        'requestedName: $requestedName, '
        'pharmacyId: $pharmacyId, '
        'matchedMedicineId: $matchedMedicineId, '
        'matchedMedicineName: $matchedMedicineName, '
        'matchedScientificName: $matchedScientificName, '
        'price: $price, '
        'isAlternative: $isAlternative, '
        'soldByPiece: $soldByPiece, '
        'unit: $unit, '
        'availableQuantity: $availableQuantity, '
        'availablePieceQuantity: $availablePieceQuantity, '
        'isAvailable: $isAvailable, '
        'matchScore: $matchScore, '
        'matchType: $matchType'
        ')';
  }
}

class MedicineMatchType {
  static const String exactName = 'exact_name';
  static const String exactScientific = 'exact_scientific';
  static const String containsName = 'contains_name';
  static const String containsScientific = 'contains_scientific';
  static const String fuzzyName = 'fuzzy_name';
  static const String fuzzyScientific = 'fuzzy_scientific';
  static const String alternative = 'alternative';
}