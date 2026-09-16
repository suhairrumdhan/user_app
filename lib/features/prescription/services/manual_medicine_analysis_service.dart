import 'dart:async';

import 'prescription_api_service.dart';

typedef MedicineTextAnalyzer = Future<Map<String, dynamic>> Function(String);

enum ManualMedicineAnalysisStatus { matched, noMatch, failed, manual, accepted }

class ManualMedicineAnalysis {
  const ManualMedicineAnalysis({
    required this.originalName,
    required this.status,
    this.suggestedName,
    this.failureMessage,
  });

  final String originalName;
  final ManualMedicineAnalysisStatus status;
  final String? suggestedName;
  final String? failureMessage;

  factory ManualMedicineAnalysis.manual(String name) => ManualMedicineAnalysis(
    originalName: name,
    status: ManualMedicineAnalysisStatus.manual,
  );

  ManualMedicineAnalysis acceptSuggestion() => ManualMedicineAnalysis(
    originalName: originalName,
    status: ManualMedicineAnalysisStatus.accepted,
    suggestedName: suggestedName,
  );
}

class ManualMedicineAnalysisService {
  ManualMedicineAnalysisService({
    MedicineTextAnalyzer? analyzer,
    this.timeout = const Duration(seconds: 20),
  }) : _analyzer = analyzer ?? PrescriptionApiService.analyzePrescription;

  final MedicineTextAnalyzer _analyzer;
  final Duration timeout;

  Future<ManualMedicineAnalysis> analyzeOne(String name) async {
    final originalName = name.trim();
    if (originalName.isEmpty) return ManualMedicineAnalysis.manual(name);

    try {
      final response = await _analyzer(originalName).timeout(timeout);
      final medicines = response['medicines'];
      if (medicines is! List) {
        return ManualMedicineAnalysis(
          originalName: originalName,
          status: ManualMedicineAnalysisStatus.failed,
          failureMessage: 'رد خدمة Flask غير صالح؛ يمكنك إعادة المحاولة',
        );
      }

      for (final item in medicines) {
        if (item is! Map) continue;
        // Legacy servers included uncertain products among accepted medicines.
        if (item['needsReview'] == true) continue;
        final suggestion =
            (item['matchedDisplayName'] ?? item['parsedBrandName'])
                ?.toString()
                .trim();
        if (suggestion != null && suggestion.isNotEmpty) {
          return ManualMedicineAnalysis(
            originalName: originalName,
            status: ManualMedicineAnalysisStatus.matched,
            suggestedName: suggestion,
          );
        }
      }

      return ManualMedicineAnalysis(
        originalName: originalName,
        status: medicines.isEmpty
            ? ManualMedicineAnalysisStatus.noMatch
            : ManualMedicineAnalysisStatus.failed,
        failureMessage: medicines.isEmpty
            ? null
            : 'تعذر قراءة اقتراح الخدمة؛ يمكنك إعادة المحاولة',
      );
    } on TimeoutException {
      return ManualMedicineAnalysis(
        originalName: originalName,
        status: ManualMedicineAnalysisStatus.failed,
        failureMessage: 'انتهت مهلة Flask؛ أعد المحاولة أو ابحث بالاسم اليدوي',
      );
    } catch (_) {
      return ManualMedicineAnalysis(
        originalName: originalName,
        status: ManualMedicineAnalysisStatus.failed,
        failureMessage:
            'تعذر الاتصال بـFlask؛ أعد المحاولة أو ابحث بالاسم اليدوي',
      );
    }
  }

  Future<List<ManualMedicineAnalysis>> analyzeAll(List<String> names) async {
    final results = <ManualMedicineAnalysis>[];
    // Limit concurrent requests so a cold-starting Flask instance stays usable.
    for (var start = 0; start < names.length; start += 3) {
      results.addAll(
        await Future.wait(names.skip(start).take(3).map(analyzeOne)),
      );
    }
    return results;
  }
}
