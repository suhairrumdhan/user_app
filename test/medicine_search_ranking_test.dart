import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/search/services/medicine_matcher.dart';
import 'package:user_application/features/search/services/medicine_search_query.dart';
import 'package:user_application/features/search/models/medicine_search_request.dart';
import 'package:user_application/features/orders/builders/order_snapshot_builder.dart';

Map<String, dynamic> stock(String name) => {
  'medicineName': name,
  'medicineId': name,
  'pharmacyId': 'p',
  'quantity': 100,
  'sellingPrice': 10,
  'isActive': true,
  'expiryDate': '2029-12-31',
  'unit': 'Tablet',
};
MedicineSearchRequest request(String text) =>
    MedicineSearchRequest(rawText: text, normalizedText: text);
void main() {
  test('generic Panadol ranks the plain name ahead of its family products', () {
    final results = MedicineMatcher.findTopMatches(
      request: request('panadol'),
      pharmacyMedicines: [
        stock('PANADOL EXTRA 500mg TAB'),
        stock('PANADOL 500mg TAB'),
        stock('PANADOL ADVANCE'),
        stock('AUGMENTIN 1g TAB'),
      ],
    );
    expect(results.map((m) => m.matchedMedicineName), [
      'PANADOL 500mg TAB',
      'PANADOL EXTRA 500mg TAB',
      'PANADOL ADVANCE',
    ]);
    expect(results.first.matchScore, 100);
    expect(results.skip(1).every((m) => m.matchScore < 100), true);
    final items = OrderSnapshotBuilder.buildMedicineItemsFromMatches(
      selectedMatches: [results[1]],
      quantitiesByMatchedMedicineId: {},
    );
    expect(items.single.requestedName, 'PANADOL EXTRA 500mg TAB');
  });
  test(
    'dose instructions and polite search prefix do not hide the medicine',
    () {
      final results = MedicineMatcher.findTopMatches(
        request: request('Please find Panadol tab 500mg 1x2x5days after meals'),
        pharmacyMedicines: [
          stock('PANADOL 500mg TAB'),
          stock('PANADOL 1000mg TAB'),
          stock('PANADOL EXTRA 500mg TAB'),
        ],
      );
      expect(results.map((m) => m.matchedMedicineName), ['PANADOL 500mg TAB']);
    },
  );
  test('specific strength and product names remain strict', () {
    expect(
      MedicineMatcher.findTopMatches(
        request: request('PANADOL EXTRA 500mg TAB'),
        pharmacyMedicines: [stock('PANADOL 500mg TAB')],
      ),
      isEmpty,
    );
    expect(
      MedicineMatcher.findTopMatches(
        request: request('PANADOL 1000mg TAB'),
        pharmacyMedicines: [stock('PANADOL 500mg TAB')],
      ),
      isEmpty,
    );
  });
  test('database tokens contain names, not dosage units or generic forms', () {
    expect(MedicineSearchQuery.tokens('Panadol tab 500mg 1x2x5days'), [
      'PANADOL',
    ]);
    expect(MedicineSearchQuery.tokens('Omnic 0.4mg cap'), ['OMNIC']);
    expect(MedicineSearchQuery.tokens('Panadol Extra 500mg Tab'), [
      'PANADOL EXTRA',
      'PANADOL',
    ]);
  });
  test('English product matches stock with Arabic original annotation', () {
    final found = MedicineMatcher.findTopMatches(
      request: request('PANADOL 5-12YEARS 100ML'),
      pharmacyMedicines: [stock('PANADOL 5-12YEARS 100ML اصلي')],
    );
    expect(found, hasLength(1));
    expect(found.single.matchScore, 100);
    final items = OrderSnapshotBuilder.buildMedicineItemsFromMatches(
      selectedMatches: found,
      quantitiesByMatchedMedicineId: {},
    );
    expect(items.single.requestedName, 'PANADOL 5-12YEARS 100ML اصلي');
  });
}
