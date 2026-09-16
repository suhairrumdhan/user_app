import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/text_preprocessor.dart';

void main() {
  test('does not insert literal capture groups or change a medicine name', () {
    expect(
      TextPreprocessor.normalize('Doliprane 1gm tab\nCiprobay500mg'),
      'Doliprane 1 g tab\nCiprobay 500 mg',
    );
    expect(TextPreprocessor.normalize('Trido\nTreto'), 'Trido\nTreto');
    expect(TextPreprocessor.normalize('Sandoz 40 mg'), 'Sandoz 40 mg');
  });

  test('preserves Arabic, lines, decimals, and fractions', () {
    expect(
      TextPreprocessor.normalize('دواء 0,4mg\r\nOmnic 0.4 mg/5 ml'),
      'دواء 0.4 mg\nOmnic 0.4 mg/5 ml',
    );
  });

  test('normalization is idempotent', () {
    const raw = 'Doliprane 1gm\r\nCiprobay500mg\nدواء 20mg';
    final first = TextPreprocessor.normalize(raw);
    expect(TextPreprocessor.normalize(first), first);
    expect(first, isNot(contains(r'$1 $2')));
  });

  test('joins only strength continuations from a PDF text layer', () {
    expect(
      TextPreprocessor.normalize(
        'Omeprazole\n"Sandoz"\n40mg cap\nTreto Cap\nOmnic\n0.4 mg cap',
      ),
      'Omeprazole 40 mg cap\nTreto Cap\nOmnic 0.4 mg cap',
    );
  });
}
