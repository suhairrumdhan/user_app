// file_utils.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:user_application/features/prescription/services/drug_parser.dart';
//import 'package:user_application/nlp/text_preprocessor.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../../../features/prescription/views/extracted_drugs.dart';

class FileUtils {
  // Request storage permissions with platform-specific handling
  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      // No permissions needed on web
      return;
    }
    // Request storage permission
    final status = await Permission.storage.request();

    if (!status.isGranted) {
      throw Exception('يجب منح صلاحيات الوصول للملفات');
    }
  }

  // Pick an image from camera or gallery
  static Future<File?> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;

        if (status.isDenied) {
          status = await Permission.camera.request();
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          throw Exception('إذن الكاميرا مرفوض بشكل دائم. افتح الإعدادات يدويًا');
        }

        if (!status.isGranted) {
          throw Exception('لم يتم منح إذن الكاميرا');
        }
      }

      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      throw Exception('Error picking image: ${e.toString()}');
    }
    return null;
  }

  // Pick a PDF file
  static Future<File?> pickPDF() async {
    try {
      await requestPermissions();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.path != null) {
          return File(file.path!);
        } else if (file.bytes != null) {
          final tempDir = await getTemporaryDirectory();
          File pdfFile = File('${tempDir.path}/${file.name}');
          await pdfFile.writeAsBytes(file.bytes!);
          return pdfFile;
        }
      }
    } catch (e) {
      throw Exception('حدث خطأ في اختيار الملف: ${e.toString()}');
    }
    return null;
  }

  // Extract text from image
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

///////////////////////////////
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String rawText = recognizedText.text;
      return cleanExtractedText(rawText);
//////////////////////////////
      return recognizedText.text;
    } catch (e) {
      return 'فشل في استخراج النص من الصورة: ${e.toString()}';
    }
  }

  // Extract text from PDF
  static Future<String> extractTextFromPDF(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      String extractedText = '';
      for (int i = 0; i < document.pages.count; i++) {
        final pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        extractedText += pageText + '\n';
      }
      document.dispose();

      String rawText = extractedText.trim();
      return rawText.isNotEmpty ? cleanExtractedText(rawText) : 'لم يتم العثور على نص في ملف PDF';

    } catch (e) {
      return 'فشل في استخراج النص من PDF: ${e.toString()}';
    }
  }

  static String cleanExtractedText(String text) {
    String t = text;

    // إزالة الرموز غير الضرورية
    t = t.replaceAll(RegExp(r'[^\w\s./xX-]'), ' ');

    // توحيد x و X و × إلى "x"
    t = t.replaceAll(RegExp(r'[×X]'), 'x');

    // 1x2x5days → 1x2x5 days
    t = t.replaceAllMapped(RegExp(r'(\d+x\d+x\d+)\s*days', caseSensitive: false), (m) {
      return "${m.group(1)} days";
    });

    // إضافة مسافة بين الأرقام والوحدة: 500mg → 500 mg
    t = t.replaceAllMapped(RegExp(r'(\d+)(mg|ml|mcg|g)\b', caseSensitive: false), (m) {
      return "${m.group(1)} ${m.group(2)}";
    });

    // توحيد tab و cap
    t = t.replaceAll(RegExp(r'\btab\.?\b', caseSensitive: false), 'tab');
    t = t.replaceAll(RegExp(r'\bcap\.?\b', caseSensitive: false), 'cap');

    // فصل الرقم عن الحرف: Omnic0.4mg → Omnic 0.4 mg
    t = t.replaceAll(RegExp(r'([a-zA-Z])(\d)'), r'$1 $2');
    t = t.replaceAll(RegExp(r'(\d)([a-zA-Z])'), r'$1 $2');

    // توحيد الفراغات داخل 1 x 2 x 5 → 1x2x5
    t = t.replaceAll(RegExp(r'\s*x\s*'), 'x');

    // إزالة مسافات مكررة
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    return t;
  }


  static Future<List<dynamic>> analyzeTextWithAPI(String text) async {
    // هنا يا بعد قلبي يا سهير غيريه كل ما تغيري الشبكة اللي عالقة عليها وخوذي الip من امر التيرمنال ipconfig
    //final url = Uri.parse("http://172.20.10.3:5000/analyze");
    // final url = Uri.parse("http://192.168.42.131:5000/analyze");
    final url = Uri.parse("http://172.20.10.4:5000/analyze");
    print("=== النص قبل الت ===\n$text");

    final cleaned = cleanExtractedText(text);

    print("=== النص قبل الإرسال ===\n$cleaned");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": cleaned}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // اطبع النص بعد التحليل
        print("=== النص يعد الإرسال ===\n$data");

        return data['medicines'];
      } else {
        throw Exception("المشكلة هناااااااااا ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("$e");
    }
  }

  static Future<void> showExtractedTextScreen(BuildContext context, String text) async {

  }

// Show extracted text dialog with loading indicator
//   static Future<void> showExtractedTextDialog(BuildContext context, String text) async {
//     // Show loading dialog immediately
//     showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent user from dismissing while loading
//       builder: (context) => const AlertDialog(
//         content: Row(
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(width: 16),
//             Text('جاري استخراج الأدوية...'),
//           ],
//         ),
//       ),
//     );
//
//     try {
//       // Send text to Flask API
//       final drugs = await analyzeTextWithAPI(text);
//
//       // Close the loading dialog
//       Navigator.of(context).pop();
//
//       // Show the results dialog
//       showDialog(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('الأدوية المستخرجة'),
//           content: drugs.isEmpty
//               ? const Text("لم يتم العثور على أدوية")
//               : SingleChildScrollView(
//             scrollDirection: Axis.vertical,
//             child: SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: DataTable(
//                 columns: const [
//                   DataColumn(label: Text("اسم الدواء")),
//                   DataColumn(label: Text("الجرعة")),
//                   DataColumn(label: Text("الطريقة")),
//                 ],
//                 rows: drugs
//                     .map(
//                       (drug) => DataRow(
//                     cells: [
//                       DataCell(Text(drug['name']?.toString() ?? "-")),
//                       DataCell(Text(drug['dosage']?.toString() ?? "-")),
//                       DataCell(Text(drug['route']?.toString() ?? "-")),
//                     ],
//                   ),
//                 )
//                     .toList(),
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('موافق'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       // Close the loading dialog in case of error
//       Navigator.of(context).pop();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("فشل استخراج الأدوية: $e")),
//       );
//     }
//   }
  static Future<void> showExtractedTextDialog(BuildContext context, String text) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري استخراج الأدوية...'),
          ],
        ),
      ),
    );

    try {
      // Send text to Flask API
      final drugs = await analyzeTextWithAPI(text);

      // Close the loading dialog
      Navigator.of(context).pop();

      // Navigate to new results page instead of showing dialog
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MedicineResultsPage(medicines: drugs),
        ),
      );

    } catch (e) {
      // Close the loading dialog in case of error
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل استخراج الأدوية: $e")),
      );
    }
  }
  // Helper method to show permission error snackbar
  static void showPermissionError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'الإعدادات',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }
}