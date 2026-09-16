import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Console-only diagnostics for development. Prescription text can be private;
/// no content is logged in profile/release builds.
class PrescriptionDiagnostics {
  const PrescriptionDiagnostics._();

  static String newRunId() =>
      'rx-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static void text(String runId, String stage, String value) {
    if (!kDebugMode) return;
    debugPrint('[ROSHITA_DIAG $runId $stage BEGIN]');
    final lines = value.replaceAll('\r\n', '\n').split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        debugPrint('[ROSHITA_DIAG $runId $stage]');
        continue;
      }
      for (var offset = 0; offset < line.length; offset += 500) {
        final end = offset + 500 < line.length ? offset + 500 : line.length;
        debugPrint(
          '[ROSHITA_DIAG $runId $stage] ${line.substring(offset, end)}',
        );
      }
    }
    debugPrint('[ROSHITA_DIAG $runId $stage END]');
  }

  static void flaskResponse(String runId, Map<String, dynamic> response) {
    if (!kDebugMode) return;
    text(
      runId,
      'FLASK_RESPONSE',
      const JsonEncoder.withIndent('  ').convert(response),
    );
  }
}
