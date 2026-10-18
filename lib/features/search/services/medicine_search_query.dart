import 'medicine_identity.dart';

class MedicineSearchQuery {
  static String clean(String text) {
    var result = text
        .replaceAll(RegExp(r'[\u0600-\u06ff]'), ' ')
        .replaceAll(RegExp(r'["\[\]]'), ' ');
    result = result.replaceAll(
      RegExp(
        r'^\s*(?:rx\s*:?|please\s+(?:find|show|search\s+for)|search\s+for|i\s+need|take)\s*',
        caseSensitive: false,
      ),
      '',
    );
    final instruction = RegExp(
      r'\b\d+\s*[x×]\s*\d+|\b(?:daily|once|twice|three\s+times|after\s+meals|before\s+meals|at\s+bed|for\s+\d+|for\s+(?:pain|headache)|every\s+\d+)\b',
      caseSensitive: false,
    ).firstMatch(result);
    if (instruction != null) result = result.substring(0, instruction.start);
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokens(String text) {
    final base = MedicineIdentity.name(clean(text));
    final words = base
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((w) => w.length >= 3 && RegExp(r'[A-Z]').hasMatch(w))
        .toList();
    if (words.isEmpty) return const [];
    return <String>{base, words.first}.toList();
  }
}
