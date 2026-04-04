import 'medicine_model.dart';

class MedicineAnalysisResponse {
  final List<MedicineModel> medicines;

  const MedicineAnalysisResponse({
    required this.medicines,
  });

  factory MedicineAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final list = json['medicines'] as List? ?? [];

    return MedicineAnalysisResponse(
      medicines: list
          .map((item) => MedicineModel.fromJson(item as Map<String, dynamic>))
          .where((medicine) => medicine.name.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicines': medicines.map((e) => e.toJson()).toList(),
    };
  }
}