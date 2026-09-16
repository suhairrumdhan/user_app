class MedicineModel {
  final String name;
  final String? dosage;
  final String? route;
  final String? originalText;
  final String? sourceText;
  final bool needsReview;
  final List<String> suggestions;

  const MedicineModel({
    required this.name,
    this.dosage,
    this.route,
    this.originalText,
    this.sourceText,
    this.needsReview = false,
    this.suggestions = const [],
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    String? cleaned(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return MedicineModel(
      name: cleaned('name') ?? '',
      dosage: cleaned('dosage'),
      route: cleaned('route'),
      originalText: cleaned('originalText'),
      sourceText: cleaned('sourceText'),
      needsReview: json['needsReview'] == true,
      suggestions: (json['suggestions'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'route': route,
      'originalText': originalText,
      'sourceText': sourceText,
      'needsReview': needsReview,
      'suggestions': suggestions,
    };
  }

  MedicineModel copyWith({
    String? name,
    String? dosage,
    String? route,
    bool? needsReview,
  }) {
    return MedicineModel(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      route: route ?? this.route,
      originalText: originalText,
      sourceText: name == null && dosage == null && route == null
          ? sourceText
          : null,
      needsReview: needsReview ?? this.needsReview,
      suggestions: suggestions,
    );
  }

  bool get hasDosage => dosage != null && dosage!.trim().isNotEmpty;
  bool get hasRoute => route != null && route!.trim().isNotEmpty;

  String get displayName {
    if (sourceText != null && sourceText!.trim().isNotEmpty) return sourceText!;
    final parts = <String>[name];
    if (hasDosage) parts.add(dosage!);
    if (hasRoute) parts.add(route!);
    return parts.join(' - ');
  }
}
