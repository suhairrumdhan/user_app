class MedicineSearchRequest {
  final String rawText;
  final String normalizedText;

  final String? parsedBrandName;
  final String? parsedScientificName;
  final String? strength;
  final String? dosageForm;
  final int quantity;

  const MedicineSearchRequest({
    required this.rawText,
    required this.normalizedText,
    this.parsedBrandName,
    this.parsedScientificName,
    this.strength,
    this.dosageForm,
    this.quantity = 1,
  });

  MedicineSearchRequest copyWith({
    String? rawText,
    String? normalizedText,
    String? parsedBrandName,
    String? parsedScientificName,
    String? strength,
    String? dosageForm,
    int? quantity,
  }) {
    return MedicineSearchRequest(
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      parsedBrandName: parsedBrandName ?? this.parsedBrandName,
      parsedScientificName:
      parsedScientificName ?? this.parsedScientificName,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      quantity: quantity ?? this.quantity,
    );
  }

  bool get hasScientificHint =>
      parsedScientificName != null && parsedScientificName!.trim().isNotEmpty;

  bool get hasBrandHint =>
      parsedBrandName != null && parsedBrandName!.trim().isNotEmpty;

  bool get hasStrength =>
      strength != null && strength!.trim().isNotEmpty;

  bool get hasDosageForm =>
      dosageForm != null && dosageForm!.trim().isNotEmpty;

  @override
  String toString() {
    return 'MedicineSearchRequest('
        'rawText: $rawText, '
        'normalizedText: $normalizedText, '
        'parsedBrandName: $parsedBrandName, '
        'parsedScientificName: $parsedScientificName, '
        'strength: $strength, '
        'dosageForm: $dosageForm, '
        'quantity: $quantity'
        ')';
  }
}