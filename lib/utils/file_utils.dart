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
import 'package:user_application/nlp/text_preprocessor.dart';

class FileUtils {
  // Request storage permissions with platform-specific handling
  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      // No permissions needed on web
      return;
    }
    // Request storage permission
    final status = await Permission.storage.request();

    // For Android 10 and below, storage permission is sufficient
    // For Android 11+ (API 30+), we may need to request manage external storage
    // but this is a dangerous permission and might be rejected by Google Play
    if (!status.isGranted) {
      throw Exception('يجب منح صلاحيات الوصول للملفات');
    }

    // Optional: Check if we need manage external storage (for Android 11+)
    // This is a dangerous permission and should be used sparingly

    // if (await Permission.manageExternalStorage.isRestricted) {
    //   // The manageExternalStorage permission is restricted on this device
    //   return;
    // }
    //
    // final manageExternalStatus = await Permission.manageExternalStorage.request();
    // if (!manageExternalStatus.isGranted) {
    //   // Fall back to using the storage permission only
    //   // You might want to handle this case differently
    // }

  }

  // Pick an image from camera or gallery
  static Future<File?> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;

        if (status.isDenied) {
          // يفتح نافذة الطلب
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

//   // Show extracted text dialog
//   static void showExtractedTextDialog(BuildContext context, String text) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('النص المستخرج'),
//         content: SingleChildScrollView(
//           child: Text(text.isNotEmpty ? text : 'لم يتم العثور على نص'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('موافق'),
//           ),
//         ],
//       ),
//     );
//   }

  // Show extracted text dialog
  static void showExtractedTextDialog(BuildContext context, String text) {
    // تنظيف النص
    final cleaned = TextPreprocessor.normalize(text);

    // استخراج الأدوية
    final drugs = DrugParser.parse(cleaned);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الأدوية المستخرجة'),
        content: drugs.isEmpty
            ? const Text("لم يتم العثور على أدوية")
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("اسم الدواء")),
              DataColumn(label: Text("الجرعة")),
              DataColumn(label: Text("التكرار")),
            ],
            rows: drugs
                .map(
                  (drug) => DataRow(cells: [
                DataCell(Text(drug.name)),
                DataCell(Text(drug.dosage)),
                DataCell(Text(drug.frequency ?? "-")),
              ]),
            )
                .toList(),
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