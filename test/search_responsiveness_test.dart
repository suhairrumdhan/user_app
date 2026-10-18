import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/search/models/medicine_search_request.dart';
import 'package:user_application/features/search/models/pharmacy_search_filters.dart';
import 'package:user_application/features/search/services/medicine_normalizer.dart';
import 'package:user_application/features/search/services/medicine_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('dosage aliases retain lexical strength and base names', () {
    expect(
      MedicineNormalizer.normalize('Augmentin 1g Tab'),
      'AUGMENTIN 1 G TABLET',
    );
    expect(MedicineNormalizer.extractBaseName('Augmentin 1g Tab'), 'AUGMENTIN');
    expect(
      MedicineNormalizer.extractStrength('Panadol tablets 500mg'),
      '500MG',
    );
    expect(MedicineNormalizer.extractDosageForm('Drug caps'), 'CAPSULE');
    expect(MedicineNormalizer.extractDosageForm('Drug soln'), 'SOLUTION');
    expect(
      MedicineNormalizer.extractDosageForm('Drug suppositories'),
      'SUPPOSITORY',
    );
    expect(MedicineNormalizer.extractDosageForm('Drug xyz'), isNull);
    for (final entry in MedicineNormalizer.dosageForms.entries) {
      for (final alias in entry.value) {
        expect(
          MedicineNormalizer.normalize('Drug $alias'),
          'DRUG ${entry.key}',
        );
      }
    }
  });
  test(
    'large search matches on a worker while UI timers keep running',
    () async {
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final items = List.generate(
        600,
        (i) => <String, dynamic>{
          'pharmacyId': 'pharmacy',
          'medicineId': 'drug-$i',
          'medicineName': 'AUGMENTIN 1g TAB',
          'scientificName': '',
          'quantity': 10,
          'reservedQuantity': 0,
          'unitsPerPackage': 0,
          'sellingPrice': 20,
          'expiryDate': Timestamp.fromDate(DateTime(2099)),
        },
      );
      try {
        final results = await MedicineSearchService.evaluateCandidates(
          groupedByPharmacy: {'pharmacy': items},
          pharmacyMetadata: {
            'pharmacy': {
              'pharmacyName': 'Test pharmacy',
              'status': 'approved',
              'location': const GeoPoint(32.88, 13.19),
              'latitude': 32.88,
              'longitude': 13.19,
            },
          },
          requests: [
            MedicineSearchRequest(
              rawText: 'Augmentin 1g Tab',
              normalizedText: MedicineNormalizer.normalize('Augmentin 1g Tab'),
            ),
          ],
          filters: const PharmacySearchFilters(),
        );
        expect(results, hasLength(1));
        expect(
          results.single.matchedMedicines.single.matchedMedicineName,
          'AUGMENTIN 1g TAB',
        );
        expect(results.single.totalEstimatedPrice, 20);
        expect(
          ticks,
          greaterThan(0),
          reason: 'matching must not block the UI event loop',
        );
      } finally {
        timer.cancel();
      }
    },
  );
}
