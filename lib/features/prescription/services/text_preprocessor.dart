class TextPreprocessor {
  static String normalize(String text) {
    if (text.trim().isEmpty) return '';

    String output = text.trim();

    output = output.replaceAll('×', 'x');
    output = output.replaceAll('_', ' ');
    output = output.replaceAll('-', ' ');

    // common OCR fixes
    output = output.replaceAll('rn', 'm');
    output = output.replaceAll('l0', '10');
    output = output.replaceAll('o0', '00');
    output = output.replaceAll('Omg', '0mg');

    // normalize units/forms
    output = output.replaceAll(
      RegExp(r'\bmilligrams?\b', caseSensitive: false),
      'mg',
    );
    output = output.replaceAll(
      RegExp(r'\bmilliliters?\b', caseSensitive: false),
      'ml',
    );
    output = output.replaceAll(
      RegExp(r'\btablet(s)?\b', caseSensitive: false),
      'tab',
    );
    output = output.replaceAll(
      RegExp(r'\bcapsule(s)?\b', caseSensitive: false),
      'cap',
    );
    output = output.replaceAll(
      RegExp(r'\bdrops?\b', caseSensitive: false),
      'drop',
    );
    output = output.replaceAll(
      RegExp(r'\bsyp\b', caseSensitive: false),
      'syrup',
    );
    output = output.replaceAll(
      RegExp(r'\bsuspension\b', caseSensitive: false),
      'susp',
    );

    // 500mg -> 500 mg
    output = output.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)(mg|ml|mcg|g|kg|iu)\b', caseSensitive: false),
          (m) => '${m.group(1)} ${m.group(2)}',
    );

    // ampiclox500 -> ampiclox 500
    output = output.replaceAll(RegExp(r'([a-zA-Z])(\d)'), r'$1 $2');
    output = output.replaceAll(RegExp(r'(\d)([a-zA-Z])'), r'$1 $2');

    // remove useless punctuation
    output = output.replaceAll(RegExp(r'[^\w\s/+.%]'), ' ');

    // normalize slash spacing
    output = output.replaceAll(RegExp(r'\s*/\s*'), '/');

    // normalize repeated spaces
    output = output.replaceAll(RegExp(r'\s+'), ' ').trim();

    return output;
  }
}