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
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF1976D2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'إضافة وصفة طبية',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'اختر طريقة إضافة الوصفة المناسبة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _SourceOptionTile(
                icon: Icons.camera_alt_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'التقاط صورة',
                subtitle: 'استخدام كاميرا الهاتف لتصوير الوصفة',
                onTap: () {
                  Navigator.pop(context);
                  onPickImage(ImageSource.camera);
                },
              ),

              const SizedBox(height: 10),

              _SourceOptionTile(
                icon: Icons.photo_library_rounded,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFECFDF3),
                title: 'اختيار من المعرض',
                subtitle: 'رفع صورة محفوظة مسبقًا من الجهاز',
                onTap: () {
                  Navigator.pop(context);
                  onPickImage(ImageSource.gallery);
                },
              ),

              const SizedBox(height: 10),

              _SourceOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                title: 'رفع ملف PDF',
                subtitle: 'إرفاق ملف الوصفة بصيغة PDF ',
                onTap: () {
                  Navigator.pop(context);
                  onPickPDF();
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}