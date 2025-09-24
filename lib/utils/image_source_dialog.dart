// image_source_dialog.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void showImageSourceDialog({
  required BuildContext context,
  required Function(ImageSource) onPickImage,
  required Function() onPickPDF,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('إضافة وصفة طبية'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: const Text('التقاط صورة'),
            onTap: () {
              Navigator.pop(context);
              onPickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.green),
            title: const Text('اختيار من المعرض'),
            onTap: () {
              Navigator.pop(context);
              onPickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('رفع ملف PDF'),
            onTap: () {
              Navigator.pop(context);
              onPickPDF();
            },
          ),
        ],
      ),
    ),
  );
}