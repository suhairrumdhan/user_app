import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<dynamic>> analyzePrescription(String prescriptionText) async {
    final url = Uri.parse("http://10.0.2.2:5000/analyze"); // لو Emulator

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
