class TextPreprocessor {
  /// Normalize prescription text extracted from OCR
  static String normalize(String text) {
    String output = text;

    // 1) Convert to lowercase
    output = output.toLowerCase();

    // 2) Common OCR mistakes corrections
    output = output.replaceAll('rn', 'm');  // e.g. "0rnox" -> "omox"
    output = output.replaceAll('l0', '10'); // "l0mg" -> "10mg"
    output = output.replaceAll('o0', '00'); // "5o0mg" -> "500mg"

    // 3) Normalize units
    output = output.replaceAll(RegExp(r'\bmilligrams?\b'), 'mg');
    output = output.replaceAll(RegExp(r'\bmilliliters?\b'), 'ml');
    output = output.replaceAll(RegExp(r'\btablet(s)?\b'), 'tab');
    output = output.replaceAll(RegExp(r'\bcapsule(s)?\b'), 'cap');
    output = output.replaceAll(RegExp(r'\bdrops?\b'), 'drop');

    // 4) Remove extra spaces
    output = output.replaceAll(RegExp(r'\s+'), ' ').trim();

    return output;
  }
}
