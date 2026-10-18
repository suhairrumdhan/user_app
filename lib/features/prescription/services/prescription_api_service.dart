import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../../../app/core/services/api_config.dart';

class PrescriptionApiService {
  static Future<Map<String, dynamic>> analyzePrescription(
    String text, {
    bool documentInput = false,
  }) async {
    // Keep the extracted text intact. Flask normalizes it for matching.
    if (text.trim().isEmpty) {
      throw Exception('النص المستخرج فارغ');
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/analyze-prescription');
    http.Response? response;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        response = await http
            .post(
              url,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': text,
                'inputMode': documentInput ? 'document' : 'manual',
              }),
            )
            .timeout(const Duration(seconds: 45));
        if (response.statusCode < 500) break;
      } on http.ClientException {
        if (attempt == 2)
          throw Exception(
            'تعذر الاتصال بخدمة تحليل الوصفة. تحقق من الإنترنت وحاول مرة أخرى.',
          );
      } on TimeoutException {
        if (attempt == 2)
          throw Exception(
            'خدمة تحليل الوصفة لا تستجيب حاليًا. حاول مرة أخرى أو أدخل الأدوية يدويًا.',
          );
      }
      if (attempt < 2)
        await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (response == null) throw Exception('تعذر الاتصال بخدمة تحليل الوصفة.');
    if (response.statusCode != 200) {
      throw Exception(
        'تعذر تحليل الوصفة حاليًا. حاول مرة أخرى أو أدخل الأدوية يدويًا.',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('تعذر قراءة نتيجة تحليل الوصفة. حاول مرة أخرى.');
    }

    return data;
  }
}
