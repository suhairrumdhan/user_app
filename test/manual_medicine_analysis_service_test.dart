import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/manual_medicine_analysis_service.dart';

void main() {
  test(
    'preserves one result per name and successful results during partial failure',
    () async {
      final received = <String>[];
      final service = ManualMedicineAnalysisService(
        analyzer: (name) async {
          received.add(name);
          if (name == 'Drug B') throw TimeoutException('offline');
          if (name == 'Drug C') return {'medicines': <dynamic>[]};
          return {
            'medicines': [
              {'matchedDisplayName': 'Matched Drug A'},
            ],
          };
        },
      );

      final results = await service.analyzeAll(['Drug A', 'Drug B', 'Drug C']);

      expect(received, containsAll(['Drug A', 'Drug B', 'Drug C']));
      expect(results.map((item) => item.originalName), [
        'Drug A',
        'Drug B',
        'Drug C',
      ]);
      expect(results.map((item) => item.status), [
        ManualMedicineAnalysisStatus.matched,
        ManualMedicineAnalysisStatus.failed,
        ManualMedicineAnalysisStatus.noMatch,
      ]);
      expect(results.first.suggestedName, 'Matched Drug A');
      expect(results[1].suggestedName, isNull);
      expect(results[1].failureMessage, contains('مهلة'));
    },
  );

  test('analyzed suggestion is not accepted automatically', () async {
    final result = await ManualMedicineAnalysisService(
      analyzer: (_) async => {
        'medicines': [
          {'matchedDisplayName': 'Suggested Name'},
        ],
      },
    ).analyzeOne('Original Name');

    expect(result.status, ManualMedicineAnalysisStatus.matched);
    expect(result.originalName, 'Original Name');
    expect(
      result.acceptSuggestion().status,
      ManualMedicineAnalysisStatus.accepted,
    );
  });

  test('keeps up to three distinct Flask suggestions in order', () async {
    final result = await ManualMedicineAnalysisService(
      analyzer: (_) async => {
        'suggestions': [
          {'displayName': 'PANADOL 500 mg TAB'},
          {'displayName': 'PANADOL EXTRA TAB'},
          {'displayName': 'PANADOL ADVANCE 500 mg TAB'},
          {'displayName': 'PANADOL COLD TAB'},
        ],
        'medicines': <dynamic>[],
      },
    ).analyzeOne('panadol');

    expect(result.status, ManualMedicineAnalysisStatus.matched);
    expect(result.suggestionOptions, [
      'PANADOL 500 mg TAB',
      'PANADOL EXTRA TAB',
      'PANADOL ADVANCE 500 mg TAB',
    ]);
    expect(
      result.acceptSuggestion('PANADOL EXTRA TAB').suggestedName,
      'PANADOL EXTRA TAB',
    );
  });

  test(
    'malformed response is a service failure, not a successful empty list',
    () async {
      final result = await ManualMedicineAnalysisService(
        analyzer: (_) async => {'unexpected': true},
      ).analyzeOne('Original Name');

      expect(result.status, ManualMedicineAnalysisStatus.failed);
      expect(result.originalName, 'Original Name');
      expect(result.failureMessage, contains('تعذر قراءة'));
    },
  );

  test('timeout keeps the original input', () async {
    final result = await ManualMedicineAnalysisService(
      analyzer: (_) => Completer<Map<String, dynamic>>().future,
      timeout: const Duration(milliseconds: 1),
    ).analyzeOne('Original Name');

    expect(result.status, ManualMedicineAnalysisStatus.failed);
    expect(result.originalName, 'Original Name');
    expect(result.failureMessage, contains('مهلة'));
  });
}
