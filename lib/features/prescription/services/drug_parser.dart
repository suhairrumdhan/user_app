import '../../search/models/medicine_search_request.dart';
import '../models/medicine_model.dart';

class DrugParser {
  /// Text without medication evidence is never inserted into the medicine list.
  static List<String> parseUncertainText(Map<String, dynamic> response) {
    final entries = response['uncertainText'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map>()
        .map((entry) => (entry['text'] ?? '').toString().trim())
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList();
  }

  /// New responses carry source ordering; old responses remain readable.
  static List<MedicineModel> parseReviewResponse(
    Map<String, dynamic> response,
  ) {
    final ordered = response['items'];
    if (ordered is List) return _parse(ordered);
    return [
      ...parseMedicineModels(response['medicines'] as List? ?? const []),
      ...parseUnmatchedMedicineModels(
        response['unmatchedLines'] as List? ?? const [],
      ),
    ];
  }

  static List<MedicineModel> parseUnmatchedMedicineModels(
    List<dynamic> items,
  ) => _parse(items, forceReview: true);

  static List<MedicineModel> parseMedicineModels(List<dynamic> items) =>
      _parse(items);

  static List<MedicineModel> _parse(
    List<dynamic> items, {
    bool forceReview = false,
  }) {
    return items
        .whereType<Map>()
        .map((item) {
          final review = forceReview || item['needsReview'] == true;
          final sourceName =
              _nullableString(item['sourceName']) ??
              _nullableString(item['name']);
          // Discard catalog-derived details in an uncertain legacy response.
          final legacyUncertain = sourceName == null && item['rawText'] != null;
          final name =
              sourceName ??
              (legacyUncertain ? _nullableString(item['rawText']) : null) ??
              _nullableString(item['parsedBrandName']) ??
              _nullableString(item['matchedDisplayName']) ??
              '';
          final suggestions = item['suggestions'] ?? item['alternatives'];
          return MedicineModel(
            name: name,
            dosage: legacyUncertain ? null : _nullableString(item['strength']),
            route: legacyUncertain ? null : _nullableString(item['dosageForm']),
            originalText: _nullableString(item['rawText']),
            sourceText: _nullableString(item['sourceText']),
            needsReview: review || legacyUncertain,
            suggestions: suggestions is List
                ? suggestions
                      .whereType<Map>()
                      .map((s) => (s['name'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toList()
                : const [],
          );
        })
        .where((medicine) => medicine.name.isNotEmpty)
        .toList();
  }

  static List<MedicineSearchRequest> parseSearchRequests(List<dynamic> items) {
    return items
        .whereType<Map>()
        .where((item) => item['needsReview'] != true)
        .map(
          (item) => MedicineSearchRequest(
            rawText: (item['sourceText'] ?? item['rawText'] ?? '')
                .toString()
                .trim(),
            normalizedText: (item['normalizedText'] ?? '').toString().trim(),
            parsedBrandName: _nullableString(item['parsedBrandName']),
            parsedScientificName: _nullableString(item['parsedScientificName']),
            strength: _nullableString(item['strength']),
            dosageForm: _nullableString(item['dosageForm']),
            quantity: int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
          ),
        )
        .where((request) => request.rawText.isNotEmpty)
        .toList();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
