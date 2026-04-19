import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
    const primary = Color(0xFF5EABD6);
    const secondary = Color(0xFF7BC4EA);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primary, secondary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      fileType == 'image'
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fileType == 'image'
                          ? 'معاينة الصورة'
                          : 'معاينة ملف PDF',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 420,
                  width: double.infinity,
                  color: const Color(0xFFF8FBFF),
                  child: fileType == 'image'
                      ? InteractiveViewer(
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                    ),
                  )
                      : SfPdfViewer.file(file),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'تأكيد ومتابعة',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}