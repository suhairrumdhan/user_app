import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';

import 'prescription_diagnostics.dart';
import 'prescription_text_layout.dart';

class FileUtils {
  static const _pdfPageRenderer = MethodChannel('roshita/pdf_ocr_pages');

  static Future<File?> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        // Use Android's document picker so vendor gallery activities are optional.
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: false,
          allowCompression: false,
        );
        if (result == null || result.files.isEmpty) return null;
        final path = result.files.single.path;
        if (path == null) throw const FormatException('تعذر فتح الصورة');
        final image = File(path);
        if (!await image.exists() || await image.length() == 0) {
          throw const FormatException('تعذر فتح الصورة');
        }
        return image;
      }
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;

        if (status.isDenied) {
          status = await Permission.camera.request();
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          throw Exception(
            'إذن الكاميرا مرفوض بشكل دائم. افتح الإعدادات يدويًا',
          );
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
      throw const FormatException('تعذر فتح الصورة. حاول اختيارها مرة أخرى.');
    }
  }

  static Future<File?> pickPDF() async {
    try {
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

  static Future<String> extractTextFromImage(
    File imageFile, {
    String? diagnosticId,
  }) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final rawText = _ocrPageText(recognizedText);
      if (diagnosticId != null) {
        PrescriptionDiagnostics.text(
          diagnosticId,
          'OCR_RAW',
          recognizedText.text,
        );
        PrescriptionDiagnostics.text(diagnosticId, 'OCR_LAYOUT', rawText);
      }
      if (rawText.isEmpty) {
        throw const FormatException('لم يتم العثور على نص في الصورة');
      }

      return rawText;
    } catch (e) {
      if (diagnosticId != null) {
        PrescriptionDiagnostics.text(diagnosticId, 'OCR_ERROR', e.toString());
      }
      rethrow;
    } finally {
      await textRecognizer.close();
    }
  }

  static Future<String> extractTextFromPDF(
    File pdfFile, {
    String? diagnosticId,
  }) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageTexts = <String>[];
      final scannedPageIndices = <int>[];
      try {
        final extractor = PdfTextExtractor(document);
        for (var i = 0; i < document.pages.count; i++) {
          final pageText = extractor
              .extractText(startPageIndex: i, endPageIndex: i, layoutText: true)
              .trim();
          pageTexts.add(pageText);
          // An Arabic-only digital page is not an empty/scanned page.
          if (pageText.isEmpty) {
            scannedPageIndices.add(i);
          }
        }
      } finally {
        document.dispose();
      }

      final digitalText = pageTexts.join('\n\f\n').trim();
      if (diagnosticId != null) {
        PrescriptionDiagnostics.text(diagnosticId, 'PDF_LAYOUT', digitalText);
      }
      if (scannedPageIndices.isNotEmpty) {
        if (!Platform.isAndroid) {
          throw UnsupportedError(
            'استخراج نص PDF المصوّر متاح حاليًا على Android فقط',
          );
        }
        final pageImages = await _pdfPageRenderer.invokeListMethod<String>(
          'renderPages',
          {'path': pdfFile.path, 'pages': scannedPageIndices},
        );
        if (pageImages == null ||
            pageImages.length != scannedPageIndices.length) {
          throw const FormatException('تعذر قراءة صفحات PDF المصوّر');
        }
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          for (var j = 0; j < pageImages.length; j++) {
            final image = File(pageImages[j]);
            final recognized = await recognizer.processImage(
              InputImage.fromFile(image),
            );
            final pageText = _ocrPageText(recognized);
            pageTexts[scannedPageIndices[j]] = pageText;
            if (diagnosticId != null) {
              PrescriptionDiagnostics.text(
                diagnosticId,
                'PDF_OCR_PAGE_${scannedPageIndices[j] + 1}',
                pageText,
              );
            }
          }
        } finally {
          await recognizer.close();
          for (final path in pageImages) {
            final image = File(path);
            if (await image.exists()) await image.delete();
          }
        }
      }

      final rawText = pageTexts.join('\n\f\n').trim();
      if (rawText.isEmpty) {
        throw const FormatException('لم يتم العثور على نص في ملف PDF');
      }
      return rawText;
    } catch (e) {
      if (diagnosticId != null) {
        PrescriptionDiagnostics.text(diagnosticId, 'PDF_ERROR', e.toString());
      }
      rethrow;
    }
  }

  static String _ocrPageText(RecognizedText recognized) {
    // ML Kit already groups words on a slanted baseline. Keep those native
    // lines intact, and reunite fragments only when their bounds agree.
    return PrescriptionTextLayout.pageText([
      for (final block in recognized.blocks)
        for (final line in block.lines)
          PrescriptionTextFragment(line.text, line.boundingBox),
    ]);
  }
}
