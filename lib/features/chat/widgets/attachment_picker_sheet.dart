import 'package:flutter/material.dart';

class AttachmentPickerSheet extends StatelessWidget {
  final VoidCallback onImageTap;
  final VoidCallback onFileTap;

  const AttachmentPickerSheet({
    super.key,
    required this.onImageTap,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'إرسال مرفق',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _item(
                      icon: Icons.image_outlined,
                      title: 'صورة',
                      onTap: onImageTap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _item(
                      icon: Icons.attach_file_rounded,
                      title: 'ملف',
                      onTap: onFileTap,
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

  Widget _item({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7EEF6)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF5EABD6)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
