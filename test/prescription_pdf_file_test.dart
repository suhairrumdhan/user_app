import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/file_utils.dart';
import 'package:user_application/features/prescription/services/text_preprocessor.dart';

void main() {
  final path = Platform.environment['PRESCRIPTION_PDF_PATH'];
  test(
    'supplied two-medication PDF through the production extractor',
    () async {
      final raw = await FileUtils.extractTextFromPDF(File(path!));
      final normalized = TextPreprocessor.normalize(raw);
      final lines = normalized.split('\n');
      final omnic = lines.singleWhere((line) => line.contains('Omnic'));
      final ciprobay = lines.singleWhere((line) => line.contains('Ciprobay'));
      expect(omnic, contains('Omnic 0.4 mg cap'));
      expect(omnic, contains('then 1x1x30days at Bed time'));
      expect(ciprobay, contains('Ciprobay tab 500 mg'));
      expect(lines.indexOf(omnic), lessThan(lines.indexOf(ciprobay)));
      expect(
        lines.where((l) => ['then', 'at Bed time', 'x30days'].contains(l)),
        isEmpty,
      );
      expect(RegExp(r'[\u0600-\u06ff]').hasMatch(normalized), isFalse);
      // Optional ephemeral hand-off to the local Flask test. No PDF/patient
      // data is committed to fixtures, printed, or sent to a hosted service.
      final output = Platform.environment['PRESCRIPTION_EXTRACTED_TEXT'];
      if (output != null) {
        File(output).writeAsStringSync(normalized);
      }
    },
    skip: path == null
        ? 'Set PRESCRIPTION_PDF_PATH for local verification'
        : false,
  );
}
