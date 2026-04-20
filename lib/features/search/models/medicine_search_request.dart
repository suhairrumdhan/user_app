class MedicineSearchRequest {
  final String requestKey;
  final String rawText;
  final String normalizedText;

  final String? parsedBrandName;
  final String? parsedScientificName;
  final String? strength;
  final String? dosageForm;
  final int quantity;

  final String? baseName;
  final List<String> searchTokens;
  final String? resolvedDisplayName;

  MedicineSearchRequest({
    String? requestKey,
    required this.rawText,
    required this.normalizedText,
    this.parsedBrandName,
    this.parsedScientificName,
    this.strength,
    this.dosageForm,
    this.quantity = 1,
    this.baseName,
    this.searchTokens = const [],
    this.resolvedDisplayName,
  }) : requestKey = _resolveRequestKey(
    requestKey: requestKey,
    rawText: rawText,
    normalizedText: normalizedText,
  );

  static String _resolveRequestKey({
    String? requestKey,
    required String rawText,
    required String normalizedText,
  }) {
    final cleaned = requestKey?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }

    final base = normalizedText.trim().isNotEmpty
        ? normalizedText.trim().toUpperCase()
        : rawText.trim().toUpperCase();

    return '${base}_${DateTime.now().microsecondsSinceEpoch}';
  }

  MedicineSearchRequest copyWith({
    String? requestKey,
    String? rawText,
    String? normalizedText,
    String? parsedBrandName,
    String? parsedScientificName,
    String? strength,
    String? dosageForm,
    int? quantity,
    String? baseName,
    List<String>? searchTokens,
    String? resolvedDisplayName,
  }) {
    return MedicineSearchRequest(
      requestKey: requestKey ?? this.requestKey,
      rawText: rawText ?? this.rawText,
      normalizedText: normalizedText ?? this.normalizedText,
      parsedBrandName: parsedBrandName ?? this.parsedBrandName,
      parsedScientificName:
      parsedScientificName ?? this.parsedScientificName,
      strength: strength ?? this.strength,
      dosageForm: dosageForm ?? this.dosageForm,
      quantity: quantity ?? this.quantity,
      baseName: baseName ?? this.baseName,
      searchTokens: searchTokens ?? this.searchTokens,
      resolvedDisplayName: resolvedDisplayName ?? this.resolvedDisplayName,
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

  bool get hasBaseName =>
      baseName != null && baseName!.trim().isNotEmpty;

  bool get hasResolvedDisplayName =>
      resolvedDisplayName != null &&
          resolvedDisplayName!.trim().isNotEmpty;

  @override
  String toString() {
    return 'MedicineSearchRequest('
        'requestKey: $requestKey, '
        'rawText: $rawText, '
        'normalizedText: $normalizedText, '
        'parsedBrandName: $parsedBrandName, '
        'parsedScientificName: $parsedScientificName, '
        'strength: $strength, '
        'dosageForm: $dosageForm, '
        'quantity: $quantity, '
        'baseName: $baseName, '
        'searchTokens: $searchTokens, '
        'resolvedDisplayName: $resolvedDisplayName'
        ')';
  }
}