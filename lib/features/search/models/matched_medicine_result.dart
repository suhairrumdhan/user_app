class MatchedMedicineResult {
  final String? _requestKey;
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

  MatchedMedicineResult({
    String? requestKey,
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
  }) : _requestKey = requestKey;

  String get requestKey {
    final value = _requestKey?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }

    final requested = requestedName.trim();
    if (requested.isNotEmpty) {
      return requested.toUpperCase();
    }

    final matched = matchedMedicineName.trim();
    if (matched.isNotEmpty) {
      return matched.toUpperCase();
    }

    return '${pharmacyId}_${matchedMedicineId}'.toUpperCase();
  }

  bool get isStrongMatch => matchScore >= 80;

  String get saleUnitLabel => soldByPiece ? 'قطعة' : 'عبوة';

  Map<String, dynamic> toMap() {
    return {
      'requestKey': requestKey,
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
    String? requestKey,
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
      requestKey: requestKey ?? this.requestKey,
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
      requestKey: map['requestKey']?.toString(),
      requestedName: map['requestedName']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      similarMatches: (map['similarMatches'] as List<dynamic>? ?? [])
          .map(
            (e) => MatchedMedicineResult.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList(),
      pharmacyId: map['pharmacyId']?.toString() ?? '',
      matchedMedicineId: map['matchedMedicineId']?.toString() ?? '',
      matchedMedicineName: map['matchedMedicineName']?.toString() ?? '',
      matchedScientificName: map['matchedScientificName']?.toString(),
      price: ((map['price'] ?? 0.0) as num).toDouble(),
      isAlternative: map['isAlternative'] == true,
      soldByPiece: map['soldByPiece'] == true,
      unit: map['unit']?.toString(),
      availableQuantity: _toInt(map['availableQuantity']),
      availablePieceQuantity: _toInt(map['availablePieceQuantity']),
      isAvailable: map['isAvailable'] == true,
      matchScore: ((map['matchScore'] ?? 0.0) as num).toDouble(),
      matchType: map['matchType']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  String toString() {
    return 'MatchedMedicineResult('
        'requestKey: $requestKey, '
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
