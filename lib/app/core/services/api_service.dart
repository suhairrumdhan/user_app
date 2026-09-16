import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiService {
  static Future<List<dynamic>> analyzePrescription(
    String prescriptionText,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/analyze-prescription');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": prescriptionText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['medicines'];
      } else {
        throw Exception("خطأ في الاتصال: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("فشل الاتصال بالـ API: $e");
    }
  }
}
