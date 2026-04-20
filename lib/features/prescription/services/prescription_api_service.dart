import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../app/core/services/api_config.dart';
import 'text_preprocessor.dart';

class PrescriptionApiService {
  static Future<Map<String, dynamic>> analyzePrescription(String text) async {
    final cleaned = TextPreprocessor.normalize(text);
    if (cleaned.trim().isEmpty) {
      throw Exception('النص المستخرج فارغ');
    }
    final url = Uri.parse('${ApiConfig.baseUrl}/analyze-prescription');
    final response = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'text': cleaned}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Backend error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('صيغة الرد من الباك إند غير صحيحة');
    }

    return data;
  }
}