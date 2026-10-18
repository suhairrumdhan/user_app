import 'dart:io';
import '../services/prescription_image_editor.dart';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PreviewScreen extends StatefulWidget {
  final File file;
  final String fileType;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<File>? onImageConfirmed;

  const PreviewScreen({
    super.key,
    required this.file,
    required this.fileType,
    required this.onConfirm,
    required this.onCancel,
    this.onImageConfirmed,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int? _width;
  int? _height;
  ImageStream? _imageStream;
  late final ImageStreamListener _imageListener;
  bool get _portrait =>
      _width != null &&
      (_turns.isEven ? _height! >= _width! : _width! >= _height!);

  @override
  void initState() {
    super.initState();
    if (widget.fileType != 'image') return;
    _imageListener = ImageStreamListener((info, synchronousCall) {
      if (!mounted) return;
      setState(() {
        _width = info.image.width;
        _height = info.image.height;
      });
      info.dispose();
    }, onError: (error, stack) {});
    _imageStream = ResizeImage(
      FileImage(widget.file),
      width: 1440,
    ).resolve(ImageConfiguration.empty);
    _imageStream!.addListener(_imageListener);
  }

  @override
  void dispose() {
    if (_imageStream != null) _imageStream!.removeListener(_imageListener);
    super.dispose();
  }

  int _turns = 0;
  bool _saving = false;
  File get file => widget.file;
  String get fileType => widget.fileType;
  VoidCallback get onCancel => widget.onCancel;

  Future<void> _confirm() async {
    if (fileType != 'image') {
      widget.onConfirm();
      return;
    }
    setState(() => _saving = true);
    try {
      final image = await preparePrescriptionImage(file, _turns);
      if (!mounted) return;
      if (widget.onImageConfirmed != null) {
        widget.onImageConfirmed!(image);
      } else {
        widget.onConfirm();
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : 'تعذر تجهيز الصورة. حاول مرة أخرى.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // الألوان الثابتة
  static const _primaryColor = Color(0xFF5EABD6);
  static const _secondaryColor = Color(0xFF7BC4EA);
  static const _darkTextColor = Color(0xFF1F2937);
  static const _grayTextColor = Color(0xFF6B7280);
  static const _backgroundColor = Color(0xFFF8FBFF);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: _buildDialogDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 14),
              _buildPreviewContent(),
              const SizedBox(height: 18),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // تزيين الحوار
  BoxDecoration _buildDialogDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // مقبض السحب (للمنصات المحمولة)
  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 50,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  // رأس المعاينة
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildIconContainer(),
          const SizedBox(width: 14),
          Expanded(
            child: const Text(
              'معاينة الوصفة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _darkTextColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // حاوية الأيقونة مع تدرج لوني
  Widget _buildIconContainer() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        fileType == 'image'
            ? Icons.image_outlined
            : Icons.picture_as_pdf_outlined,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // محتوى المعاينة (الصورة أو PDF)
  Widget _buildPreviewContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 420,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _backgroundColor,
          border: Border.all(
            color: fileType == 'image' && _portrait
                ? const Color(0xFF2EAD65)
                : Colors.grey.shade100,
            width: fileType == 'image' && _portrait ? 3 : 1,
          ),
        ),
        child: fileType == 'image' ? _buildImageViewer() : _buildPdfViewer(),
      ),
    );
  }

  // عارض الصور مع تفاعل التكبير
  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: RotatedBox(
        quarterTurns: _turns,
        child: Image.file(
          file,
          cacheWidth: 1440,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'تعذر تحميل الصورة',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // عارض PDF مع إعدادات محسنة
  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      file,
      enableTextSelection: true,
      pageSpacing: 8,
      canShowScrollHead: true,
      canShowPageLoadingIndicator: true,
      onDocumentLoaded: (details) {},
      onPageChanged: (details) {
        debugPrint('Page changed to: ${details.newPageNumber}');
      },
    );
  }

  // أزرار الإجراءات
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (fileType == 'image')
            IconButton(
              tooltip: 'تدوير الصورة',
              onPressed: _saving
                  ? null
                  : () => setState(() => _turns = (_turns + 1) % 4),
              icon: const Icon(Icons.rotate_right, color: _primaryColor),
            ),
          Expanded(child: _buildCancelButton()),
          const SizedBox(width: 14),
          Expanded(child: _buildConfirmButton()),
        ],
      ),
    );
  }

  // زر الإلغاء
  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _saving ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: _grayTextColor,
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: const Text('إلغاء'),
    );
  }

  // زر التأكيد
  Widget _buildConfirmButton() {
    return ElevatedButton(
      onPressed: _saving ? null : _confirm,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(_saving ? 'جارٍ التجهيز' : 'متابعة'),
    );
  }
}
