import 'dart:math' as math;
import 'dart:ui';

/// A PDF word or an OCR line, in page coordinates (not content-stream order).
class PrescriptionTextFragment {
  const PrescriptionTextFragment(this.text, this.bounds);

  final String text;
  final Rect bounds;
}

/// Reconstructs reading rows without depending on a hospital template, page
/// size, or fixed crop. Large horizontal gaps remain separate text regions.
class PrescriptionTextLayout {
  static final _arabic = RegExp(
    r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+',
  );

  static String pageText(Iterable<PrescriptionTextFragment> fragments) {
    final words = fragments
        .map(
          (f) => PrescriptionTextFragment(
            f.text
                .replaceAll(_arabic, ' ')
                .replaceAll(
                  RegExp(r'[\u200e\u200f\u202a-\u202e\u2066-\u2069]'),
                  '',
                )
                .trim(),
            f.bounds,
          ),
        )
        .where((f) => f.text.isNotEmpty)
        .toList();
    final located =
        words.where((f) => f.bounds.isFinite && !f.bounds.isEmpty).toList()
          ..sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));
    final rows = <List<PrescriptionTextFragment>>[];
    for (final word in located) {
      // Compare with the first fragment, not a growing union bounding box:
      // a large glyph must not bridge two different medication rows.
      if (rows.isNotEmpty && _sameRow(rows.last.first.bounds, word.bounds)) {
        rows.last.add(word);
      } else {
        rows.add([word]);
      }
    }

    final output = <String>[];
    Rect? previousRow;
    for (final row in rows) {
      row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      final bounds = row
          .map((f) => f.bounds)
          .reduce((a, b) => a.expandToInclude(b));
      if (previousRow != null &&
          bounds.top - previousRow.bottom > 1.5 * previousRow.height) {
        output.add('');
      }
      var text = '';
      PrescriptionTextFragment? previous;
      for (final word in row) {
        if (previous != null) {
          final gap = word.bounds.left - previous.bounds.right;
          final height = math.min(word.bounds.height, previous.bounds.height);
          // Ignore a duplicate text layer, not repeated instructions elsewhere.
          if (word.text == previous.text &&
              (word.bounds.left - previous.bounds.left).abs() < height * .1) {
            continue;
          }
          if (gap > height * 2.5) {
            output.add(text);
            output.add(''); // A column boundary is not a wrapped strength.
            text = '';
          } else if (gap > height * .06) {
            text += ' ';
          }
        }
        text += word.text;
        previous = word;
      }
      if (text.isNotEmpty) output.add(text);
      previousRow = bounds;
    }
    // Do not silently lose text with unavailable coordinates. Isolate it so
    // it cannot become the strength of a spatially unrelated medication.
    for (final word in words.where(
      (f) => !f.bounds.isFinite || f.bounds.isEmpty,
    )) {
      output.addAll(['', word.text, '']);
    }
    return output.join('\n').trim();
  }

  static bool _sameRow(Rect a, Rect b) {
    final smallerHeight = math.min(a.height, b.height);
    final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    return overlap >= smallerHeight * .55 &&
        (a.center.dy - b.center.dy).abs() <= smallerHeight * .4;
  }
}
