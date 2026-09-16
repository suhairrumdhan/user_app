import '../../search/models/medicine_search_request.dart';
import '../models/medicine_model.dart';

class DrugParser {
  static List<MedicineModel> parseUnmatchedMedicineModels(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map(
          (item) => MedicineModel(
            name: (item['name'] ?? '').toString().trim(),
            dosage: _nullableString(item['strength']),
            route: _nullableString(item['dosageForm']),
          ),
        )
        .where((medicine) => medicine.name.isNotEmpty)
        .toList();
  }

  static List<MedicineModel> parseMedicineModels(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map(
          (item) => MedicineModel(
        name: (item['matchedDisplayName'] ?? item['parsedBrandName'] ?? '')
            .toString()
            .trim(),
        dosage: item['strength']?.toString().trim(),
        route: item['dosageForm']?.toString().trim(),
      ),
    )
        .where((medicine) => medicine.name.isNotEmpty)
        .toList();
  }

  static List<MedicineSearchRequest> parseSearchRequests(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map(
          (item) => MedicineSearchRequest(
        rawText: (item['rawText'] ?? '').toString().trim(),
        normalizedText: (item['normalizedText'] ?? '').toString().trim(),
        parsedBrandName: _nullableString(item['parsedBrandName']),
        parsedScientificName: _nullableString(item['parsedScientificName']),
        strength: _nullableString(item['strength']),
        dosageForm: _nullableString(item['dosageForm']),
        quantity: _parseQuantity(item['quantity']),
      ),
    )
        .where((request) => request.rawText.isNotEmpty)
        .toList();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int _parseQuantity(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 1;
  }
}
