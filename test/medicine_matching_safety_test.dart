import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/search/services/medicine_identity.dart';
import 'package:user_application/features/search/services/medicine_matcher.dart';
import 'package:user_application/features/search/models/medicine_search_request.dart';
import 'package:user_application/features/prescription/models/medicine_model.dart';
import 'package:user_application/features/prescription/services/drug_parser.dart';
import 'package:user_application/features/prescription/services/manual_medicine_analysis_service.dart';

bool matches(String source, String available) =>
    MedicineIdentity.matches(requestedName: source, availableName: available);

void main() {
  test('Trido is never Tricox and Panadol is not Panadol Extra', () {
    expect(matches('Trido tab', 'Tricox Tablet 20*20*20'), isFalse);
    expect(matches('Panadol 500mg tab', 'Panadol Extra 500mg tab'), isFalse);
    expect(matches('Panadoll 500mg tab', 'Panadol 500mg tab'), isFalse);
  });

  test('specified strength must be present and equal, not a score penalty', () {
    expect(matches('Panadol 500mg tab', 'Panadol 1000mg tab'), isFalse);
    expect(matches('Panadol 500mg tab', 'Panadol tab'), isFalse);
    expect(matches('Dostinex 0.5mg tab', 'Dostinex 5mg tab'), isFalse);
    expect(MedicineIdentity.strength('Example 0,500mg'), '0.5 MG');
    expect(MedicineIdentity.strength('Example 50,000 IU'), isNull);
    expect(matches('Example 50,000 IU tab', 'Example 50 IU tab'), isFalse);
    expect(matches('Example 5 tab', 'Example 50mg tab'), isFalse);
    expect(matches('Example 1g tablet', 'Example 1000mg 12tab'), isTrue);
    expect(matches('Dostinex 0.5mg tab', 'Dostinex 0.5 mg/8tab'), isTrue);
  });

  test('all combination components and concentrations are compared', () {
    expect(
      matches('Example 500mg + 125mg tab', 'Example 500mg + 250mg tab'),
      isFalse,
    );
    expect(MedicineIdentity.strength('Example 500/125mg'), '500 MG + 125 MG');
    expect(MedicineIdentity.strength('Example 250mg/5ml'), '50 MG/ML');
    expect(matches('Example 250mg/5ml syrup', 'Example 50mg/ml syrup'), isTrue);
    expect(
      matches('Example 250mg/5ml syrup', 'Example 250mg/ml syrup'),
      isFalse,
    );
  });

  test('dosage forms and significant qualifiers cannot be dropped', () {
    expect(matches('Example 20mg tablet', 'Example 20mg capsule'), isFalse);
    expect(matches('Example XR 20mg tab', 'Example 20mg tab'), isFalse);
    expect(matches('Example Plus 20mg tab', 'Example 20mg tab'), isFalse);
    expect(matches('Example eye drops', 'Example ear drops'), isFalse);
    expect(MedicineIdentity.form('Tabex'), isNull);
    expect(matches('Vitamin B12', 'Vitamin B6'), isFalse);
  });

  test('structured details are usable but conflicts fail closed', () {
    expect(
      MedicineIdentity.matches(
        requestedName: 'Example 20mg tab',
        availableName: 'Example',
        availableStrength: '20mg',
        availableForm: 'tablet',
      ),
      isTrue,
    );
    expect(
      MedicineIdentity.matches(
        requestedName: 'Example 20mg tab',
        availableName: 'Example 20mg tab',
        availableStrength: '40mg',
        availableForm: 'tablet',
      ),
      isFalse,
    );
    expect(
      MedicineIdentity.matches(
        requestedName: 'Example 20mg tab',
        availableName: 'Example 20mg tab',
        availableForm: 'capsule',
      ),
      isFalse,
    );
  });

  test(
    'unknown cosmetic exact names can still search without a drug catalog',
    () {
      expect(
        matches('Unknown Cosmetic Serum', 'Unknown Cosmetic Serum'),
        isTrue,
      );
      expect(
        matches('Unknown Cosmetic Serum', 'Unknown Cosmetic Cream'),
        isFalse,
      );
    },
  );

  test('real inventory matcher rejects different brands and strengths', () {
    final request = MedicineSearchRequest(
      rawText: 'Panadol 500mg tab',
      normalizedText: 'PANADOL 500 MG TAB',
    );
    Map<String, dynamic> stock(String name) => {
      'pharmacyId': 'p',
      'medicineId': name,
      'medicineName': name,
      'quantity': 5,
      'pieceQuantity': 0,
      'unitsPerPackage': 10,
      'reservedQuantity': 0,
      'reservedPieceQuantity': 0,
      'sellingPrice': 20,
      'expiryDate': '2099-01-01T00:00:00Z',
    };
    final result = MedicineMatcher.findTopMatches(
      request: request,
      pharmacyMedicines: [
        stock('Panadol Extra 500mg tab'),
        stock('Panadol 1000mg tab'),
        stock('Panadol 500mg 12tab'),
        stock('Panadol tab'),
      ],
    );
    expect(result, hasLength(1));
    expect(result.single.matchedMedicineName, 'Panadol 500mg 12tab');
  });

  test(
    'source ordered response keeps uncertain original and avoids duplicate dosage',
    () {
      final parsed = DrugParser.parseReviewResponse({
        'items': [
          {
            'sourceName': 'panadol',
            'sourceText': 'Panadol Tab 500mg',
            'strength': '500 mg',
            'dosageForm': 'tab',
            'matchedDisplayName': 'PANADOL 500MG 12TAB',
            'needsReview': false,
          },
          {
            'sourceName': 'trido',
            'sourceText': 'Trido tab',
            'needsReview': true,
            'rawText': 'Trido tab 1X2X3months',
            'suggestions': [
              {'name': 'Tricox Tablet'},
            ],
          },
          {
            'sourceName': 'dostinex',
            'sourceText': 'Dostinex 0.5mg tab',
            'strength': '0.5 mg',
            'dosageForm': 'tab',
          },
        ],
      });
      expect(parsed.map((m) => m.displayName), [
        'Panadol Tab 500mg',
        'Trido tab',
        'Dostinex 0.5mg tab',
      ]);
      expect(parsed[1].needsReview, isTrue);
      expect(parsed[1].suggestions, ['Tricox Tablet']);
      final kept = parsed[1].copyWith(needsReview: false);
      expect(kept.displayName, 'Trido tab');
      expect(kept.needsReview, isFalse);
      expect(MedicineModel.fromJson(kept.toJson()).displayName, 'Trido tab');
    },
  );

  test('legacy guessed name cannot replace the original OCR text', () {
    for (final review in [true, false]) {
      final parsed = DrugParser.parseMedicineModels([
        {
          'rawText': 'Trido tab',
          'matchedDisplayName': 'Tricox Tablet 20*20*20',
          'parsedBrandName': 'tricox',
          'strength': '20mg',
          'dosageForm': 'tab',
          'needsReview': review,
        },
      ]);
      expect(parsed.single.name, 'Trido tab');
      expect(parsed.single.dosage, isNull);
      expect(parsed.single.needsReview, isTrue);
    }
  });

  test(
    'uncertain legacy manual response is not offered as a confirmed name',
    () async {
      final result = await ManualMedicineAnalysisService(
        analyzer: (_) async => {
          'medicines': [
            {'matchedDisplayName': 'Tricox', 'needsReview': true},
          ],
        },
      ).analyzeOne('Trido');
      expect(result.suggestedName, isNull);
      expect(result.originalName, 'Trido');
      expect(result.status, isNot(ManualMedicineAnalysisStatus.matched));
    },
  );
}
