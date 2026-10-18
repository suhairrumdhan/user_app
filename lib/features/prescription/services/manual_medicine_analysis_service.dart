import 'dart:async';

import 'prescription_api_service.dart';

typedef MedicineTextAnalyzer = Future<Map<String, dynamic>> Function(String);

enum ManualMedicineAnalysisStatus { matched, noMatch, failed, manual, accepted }

class ManualMedicineAnalysis {
  const ManualMedicineAnalysis({
    required this.originalName,
    required this.status,
    this.suggestedName,
    this.suggestions = const [],
    this.failureMessage,
  });

  final String originalName;
  final ManualMedicineAnalysisStatus status;
  final String? suggestedName;
  final List<String> suggestions;
  final String? failureMessage;

  List<String> get suggestionOptions => suggestions.isNotEmpty
      ? suggestions
      : suggestedName == null
      ? const []
      : [suggestedName!];

  factory ManualMedicineAnalysis.manual(String name) => ManualMedicineAnalysis(
    originalName: name,
    status: ManualMedicineAnalysisStatus.manual,
  );

  ManualMedicineAnalysis acceptSuggestion([String? suggestion]) {
    final selected = suggestion ?? suggestedName;
    return ManualMedicineAnalysis(
      originalName: originalName,
      status: ManualMedicineAnalysisStatus.accepted,
      suggestedName: selected,
      suggestions: suggestions,
    );
  }
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
          failureMessage: 'تعذر قراءة نتيجة التحليل؛ يمكنك إعادة المحاولة',
        );
      }

      final suggestions = _readSuggestions(response, medicines);
      if (suggestions.isNotEmpty) {
        return ManualMedicineAnalysis(
          originalName: originalName,
          status: ManualMedicineAnalysisStatus.matched,
          suggestedName: suggestions.first,
          suggestions: suggestions,
        );
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
        failureMessage: 'انتهت مهلة التحليل؛ أعد المحاولة أو ابحث بالاسم اليدوي',
      );
    } catch (_) {
      return ManualMedicineAnalysis(
        originalName: originalName,
        status: ManualMedicineAnalysisStatus.failed,
        failureMessage:
            'تعذر الاتصال بخدمة التحليل؛ أعد المحاولة أو ابحث بالاسم اليدوي',
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

  static List<String> _readSuggestions(
    Map<String, dynamic> response,
    List<dynamic> medicines,
  ) {
    final values = <String>[];

    void add(dynamic value) {
      final text = switch (value) {
        String value => value.trim(),
        Map value =>
          (value['displayName'] ??
                  value['name'] ??
                  value['matchedDisplayName'] ??
                  value['suggestedName'])
              ?.toString()
              .trim(),
        _ => null,
      };
      if (text == null || text.isEmpty) return;
      final normalized = text.toLowerCase();
      if (values.any((item) => item.toLowerCase() == normalized)) return;
      values.add(text);
    }

    void addList(dynamic list) {
      if (list is! List) return;
      for (final value in list) {
        add(value);
      }
    }

    addList(response['suggestions']);
    addList(response['alternatives']);
    for (final item in medicines) {
      if (item is! Map || item['needsReview'] == true) continue;
      addList(item['suggestions']);
      addList(item['alternatives']);
      add(
        item['suggestedDisplayName'] ??
            item['matchedDisplayName'] ??
            item['displayName'] ??
            item['parsedBrandName'],
      );
    }
    return values.take(3).toList(growable: false);
  }
}
