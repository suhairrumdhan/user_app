import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/file_utils.dart';
import 'package:user_application/features/prescription/services/text_preprocessor.dart';

void main() {
  final corpusDirectory = Platform.environment['PRESCRIPTION_PDF_DIRECTORY'];
  final outputPath = Platform.environment['PRESCRIPTION_CORPUS_OUTPUT'];

  test(
    'extract supplied digital prescriptions with production PDF path',
    () async {
      final files =
          Directory(corpusDirectory!)
              .listSync()
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.pdf'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      expect(files.length, 31);

      final extracted = <Map<String, Object>>[];
      for (final file in files) {
        final text = TextPreprocessor.normalize(
          await FileUtils.extractTextFromPDF(file),
        );
        expect(text, isNotEmpty);
        extracted.add({'file': file.path, 'text': text});
      }
      if (outputPath != null) {
        File(outputPath).writeAsStringSync(jsonEncode(extracted));
      }
    },
    skip: corpusDirectory == null
        ? 'Set PRESCRIPTION_PDF_DIRECTORY for local verification'
        : false,
  );
}
