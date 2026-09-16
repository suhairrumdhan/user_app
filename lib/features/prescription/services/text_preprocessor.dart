/// Conservative cleanup for OCR and PDF text. Ambiguous spelling corrections
/// belong in the review step, not in a blanket replacement over medicine names.
class TextPreprocessor {
  static String normalize(String text) {
    if (text.trim().isEmpty) return '';

    var output = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    output = output.replaceAll('×', 'x').replaceAll('_', ' ');
    output = output.replaceAllMapped(
      RegExp(r'(\d),(\d)'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );

    // Expand only unambiguous whole-word units and dosage forms.
    const aliases = <String, String>{
      'milligram': 'mg',
      'milligrams': 'mg',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'millilitre': 'ml',
      'millilitres': 'ml',
      'tablets': 'tab',
      'tablet': 'tab',
      'capsules': 'cap',
      'capsule': 'cap',
    };
    for (final alias in aliases.entries) {
      output = output.replaceAll(
        RegExp('\\b${alias.key}\\b', caseSensitive: false),
        alias.value,
      );
    }

    // Dart replaceAll does not interpolate capture groups in the replacement.
    output = output.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(mg|ml|mcg|gm|g|kg|iu)\b',
        caseSensitive: false,
      ),
      (match) =>
          '${match.group(1)} ${match.group(2)!.toLowerCase() == 'gm' ? 'g' : match.group(2)}',
    );
    output = output.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // Preserve Unicode letters, decimal points, fractions, and line boundaries.
    output = output.replaceAll(RegExp(r'[\[\]{}(),;:!?]'), ' ');
    final lines = output
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t\f\v]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // PDF text layers sometimes put an item name and its strength on separate
    // lines. Join only a unit-led continuation; never join two medicine names.
    final merged = <String>[];
    final unitAtStart = RegExp(
      r'^\d+(?:\.\d+)?\s*(?:mg|ml|mcg|g|kg|iu)\b',
      caseSensitive: false,
    );
    final strengthAnywhere = RegExp(
      r'\d+(?:\.\d+)?\s*(?:mg|ml|mcg|g|kg|iu)\b',
      caseSensitive: false,
    );
    final nameOnly = RegExp(r'^[A-Za-z][A-Za-z .\-]*$');
    final quotedMaker = RegExp(r'^["“][A-Za-z][^"”]*["”]$');
    for (final line in lines) {
      if (unitAtStart.hasMatch(line) && merged.isNotEmpty) {
        var previous = merged.last;
        if (quotedMaker.hasMatch(previous) && merged.length > 1) {
          previous = merged[merged.length - 2];
          if (nameOnly.hasMatch(previous) &&
              !strengthAnywhere.hasMatch(previous)) {
            merged.removeLast(); // Manufacturer is not the medicine name.
          }
        }
        if (nameOnly.hasMatch(merged.last) &&
            !strengthAnywhere.hasMatch(merged.last) &&
            !const {
              'name',
              'age',
              'rx',
              'dr',
              'doctor',
            }.contains(merged.last.toLowerCase())) {
          merged[merged.length - 1] = '${merged.last} $line';
          continue;
        }
      }
      merged.add(line);
    }
    return merged.join('\n');
  }
}
