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
import 'package:user_application/nlp/drug_parser.dart';
//import 'package:user_application/nlp/text_preprocessor.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

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
      return extractedText.trim().isNotEmpty ? extractedText : 'لم يتم العثور على نص في ملف PDF';
    } catch (e) {
      return 'فشل في استخراج النص من PDF: ${e.toString()}';
    }
  }

  static Future<List<dynamic>> analyzeTextWithAPI(String text) async {
    final url = Uri.parse("http://172.20.10.3:5000/analyze");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
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

  // Show extracted text dialog with loading indicator
  static Future<void> showExtractedTextDialog(BuildContext context, String text) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from dismissing while loading
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
      // Clean the text
      //final cleaned = TextPreprocessor.normalize(text);

      // Send text to Flask API
      final drugs = await analyzeTextWithAPI(text);

      // Close the loading dialog
      Navigator.of(context).pop();

      // Show the results dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('الأدوية المستخرجة'),
          content: drugs.isEmpty
              ? const Text("لم يتم العثور على أدوية")
              : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("اسم الدواء")),
                  DataColumn(label: Text("الجرعة")),
                  DataColumn(label: Text("التكرار")),
                  DataColumn(label: Text("المدة")),
                  DataColumn(label: Text("الطريقة")),
                ],
                rows: drugs
                    .map((drug) => DataRow(cells: [
                  DataCell(Text(drug['name']?.toString() ?? "-")),
                  DataCell(Text(drug['dosage']?.toString() ?? "-")),
                  DataCell(Text(drug['frequency']?.toString() ?? "-")),
                  DataCell(Text(drug['duration']?.toString() ?? "-")),
                  DataCell(Text(drug['route']?.toString() ?? "-")),
                ]))
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق'),
            ),
          ],
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

  // Alternative method with better loading handling
  static Future<void> showExtractedTextDialogWithLoading(BuildContext context, String text) async {
    bool isLoading = true;

    // Show the dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Start the analysis immediately
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
          // final cleaned = TextPreprocessor.normalize(text);
            final drugs = await analyzeTextWithAPI(text);

            // Close current dialog and show results
            Navigator.of(context).pop();

            _showResultsDialog(context, drugs);
          } catch (e) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("فشل استخراج الأدوية: $e")),
            );
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: isLoading
                  ? const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('جاري استخراج الأدوية...'),
                ],
              )
                  : const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  // Helper method to show results dialog
  static void _showResultsDialog(BuildContext context, List<dynamic> drugs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الأدوية المستخرجة'),
        content: drugs.isEmpty
            ? const Text("لم يتم العثور على أدوية")
            : SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("اسم الدواء")),
                DataColumn(label: Text("الجرعة")),
                DataColumn(label: Text("التكرار")),
                DataColumn(label: Text("المدة")),
                DataColumn(label: Text("الطريقة")),
              ],
              rows: drugs
                  .map((drug) => DataRow(cells: [
                DataCell(Text(drug['name']?.toString() ?? "-")),
                DataCell(Text(drug['dosage']?.toString() ?? "-")),
                DataCell(Text(drug['frequency']?.toString() ?? "-")),
                DataCell(Text(drug['duration']?.toString() ?? "-")),
                DataCell(Text(drug['route']?.toString() ?? "-")),
              ]))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
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