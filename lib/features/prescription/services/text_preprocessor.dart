/// Technical cleanup only. Medicine names, strengths, dosage forms and all
/// semantic interpretation are intentionally left to the Flask service.
class TextPreprocessor {
  static String normalize(String text) {
    if (text.trim().isEmpty) return '';

    var output = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Remove invisible/control noise while preserving line and page boundaries.
    output = output.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000E-\u001F\u007F]'),
      ' ',
    );
    output = output.replaceAll(
      RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+',
      ),
      ' ',
    );
    output = output.replaceAll(
      RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFFFD]'),
      ' ',
    );
    final lines = output
        .split('\n')
        .map(
          (line) => line == '\f'
              ? '\f'
              : line.replaceAll(RegExp(r'[ \t\v]+'), ' ').trim(),
        )
        .toList();

    return lines.join('\n').trim();
  }
}
