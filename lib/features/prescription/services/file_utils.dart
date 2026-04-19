import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'text_preprocessor.dart';

class FileUtils {
  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('يجب منح صلاحيات الوصول للملفات');
    }
  }

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

      return null;
    } catch (e) {
      throw Exception('Error picking image: ${e.toString()}');
    }
  }

  static Future<File?> pickPDF() async {
    try {
      await requestPermissions();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.path != null) {
          return File(file.path!);
        }

        if (file.bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final pdfFile = File('${tempDir.path}/${file.name}');
          await pdfFile.writeAsBytes(file.bytes!);
          return pdfFile;
        }
      }

      return null;
    } catch (e) {
      throw Exception('حدث خطأ في اختيار الملف: ${e.toString()}');
    }
  }

  static Future<String> extractTextFromImage(File imageFile) async {
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final rawText = recognizedText.text.trim();
      if (rawText.isEmpty) {
        return 'لم يتم العثور على نص في الصورة';
      }

      return TextPreprocessor.normalize(rawText);
    } catch (e) {
      return 'فشل في استخراج النص من الصورة: ${e.toString()}';
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<String> extractTextFromPDF(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final buffer = StringBuffer();

      for (int i = 0; i < document.pages.count; i++) {
        final pageText = PdfTextExtractor(document).extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        buffer.writeln(pageText);
      }

      document.dispose();

      final rawText = buffer.toString().trim();
      if (rawText.isEmpty) {
        return 'لم يتم العثور على نص في ملف PDF';
      }

      return TextPreprocessor.normalize(rawText);
    } catch (e) {
      return 'فشل في استخراج النص من PDF: ${e.toString()}';
    }
  }
}