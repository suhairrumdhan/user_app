// preview_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class PreviewScreen extends StatelessWidget {
  final File file;
  final String fileType;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PreviewScreen({
    super.key,
    required this.file,
    required this.fileType,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 400,
          child: fileType == 'image'
              ? Image.file(file, fit: BoxFit.contain)
              : SfPdfViewer.file(file),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(onPressed: onCancel, child: const Text("إلغاء")),
            ElevatedButton(onPressed: onConfirm, child: const Text("تأكيد")),
          ],
        ),
      ],
    );
  }
}