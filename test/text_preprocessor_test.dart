import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/text_preprocessor.dart';

void main() {
  test('does not semantically alter medicine text', () {
    expect(
      TextPreprocessor.normalize('Doliprane 1gm tab\nCiprobay500mg'),
      'Doliprane 1gm tab\nCiprobay500mg',
    );
    expect(TextPreprocessor.normalize('Trido\nTreto'), 'Trido\nTreto');
    expect(TextPreprocessor.normalize('Sandoz 40 mg'), 'Sandoz 40 mg');
  });

  test('removes Arabic while preserving strengths and line structure', () {
    expect(
      TextPreprocessor.normalize('دواء 0,4mg\r\nOmnic 0.4 mg/5 ml'),
      '0,4mg\nOmnic 0.4 mg/5 ml',
    );
  });

  test('normalization is idempotent', () {
    const raw = 'Doliprane 1gm\r\nCiprobay500mg\n20mg';
    final first = TextPreprocessor.normalize(raw);
    expect(TextPreprocessor.normalize(first), first);
    expect(first, isNot(contains(r'$1 $2')));
  });

  test('leaves strength and dosage-form interpretation to Flask', () {
    expect(
      TextPreprocessor.normalize(
        'Omeprazole\n"Sandoz"\n40mg cap\nTreto Cap\nOmnic\n0.4 mg cap',
      ),
      'Omeprazole\n"Sandoz"\n40mg cap\nTreto Cap\nOmnic\n0.4 mg cap',
    );
  });

  test('keeps name digits, ambiguous comma and region/page boundaries', () {
    expect(
      TextPreprocessor.normalize(
        'Vitamin B12\nExample 50,000 IU\n\nRx:\n\f\nTest',
      ),
      'Vitamin B12\nExample 50,000 IU\n\nRx:\n\f\nTest',
    );
  });

  test('removes control noise and only compacts horizontal whitespace', () {
    expect(
      TextPreprocessor.normalize('  Omnic\u0007   0.4 mg cap  \n'),
      'Omnic 0.4 mg cap',
    );
  });
}
