import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/drug_parser.dart';

void main() {
  test('keeps an unknown OCR medicine and its stated strength for review', () {
    final items = DrugParser.parseUnmatchedMedicineModels([
      {
        'name': 'Omeprazole',
        'rawText': 'Omeprazole 40mg cap',
        'strength': '40 mg',
        'dosageForm': 'cap',
      },
      {'name': '', 'strength': '20 mg'},
    ]);
    expect(items, hasLength(1));
    expect(items.single.name, 'Omeprazole');
    expect(items.single.dosage, '40 mg');
    expect(items.single.route, 'cap');
  });
}
