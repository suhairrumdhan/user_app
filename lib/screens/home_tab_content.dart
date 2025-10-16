import 'package:flutter/material.dart';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'map_tab.dart';
import 'preview_screen.dart';
import '../utils/file_utils.dart';
import '../utils/image_source_dialog.dart';

class HomeTabContent extends StatefulWidget {
  final LatLng? currentPosition;
  final List<LatLng> pharmacies;
  final bool isLoading;

  const HomeTabContent({
    super.key,
    required this.currentPosition,
    required this.pharmacies,
    required this.isLoading,
  });

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  File? _selectedFile;
  String? _fileType;
  String _extractedText = '';
  bool _isLoading = false;

  Future<bool> _showPreviewDialog(File file, String type) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: PreviewScreen(
          file: file,
          fileType: type,
          onConfirm: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // 📱 استخدم MediaQuery مرة واحدة لتسهيل الحساب
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 🎯 اجعل ارتفاع الخريطة يتغير حسب الاتجاه وحجم الشاشة
    final mapHeight = isLandscape
        ? screenHeight * 0.6 // لو الجهاز أفقي — مساحة أكبر
        : screenHeight * 0.42; // لو عمودي — 42%

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenHeight * 0.1), // تباعد مرن بدل رقم ثابت

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'إجراءات سريعة',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(Icons.upload, 'رفع وصفة'),
                        _buildActionButton(Icons.search, 'بحث'),
                        _buildActionButton(Icons.history, 'السجل'),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ✅ استخدام الميديا كويري للارتفاع
            SizedBox(
              height: mapHeight,
              width: screenWidth,
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : MapTab(
                currentPosition: widget.currentPosition,
                pharmacies: widget.pharmacies,
              ),
            ),
          ],
        ),
      ),

      // ✅ أزرار عائمة كما هي
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "familyBtn",
            backgroundColor: const Color(0xFFE14434),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Family Button Pressed!')),
              );
            },
            child: const Icon(Icons.family_restroom, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "addBtn",
            backgroundColor: const Color(0xFF5EABD6),
            onPressed: () => showImageSourceDialog(
              context: context,
              onPickImage: (source) async {
                setState(() => _isLoading = true);
                try {
                  final imageFile = await FileUtils.pickImage(source);
                  if (imageFile != null) {
                    final confirmed =
                    await _showPreviewDialog(imageFile, 'image');
                    if (confirmed) {
                      final extractedText =
                      await FileUtils.extractTextFromImage(imageFile);
                      setState(() {
                        _selectedFile = imageFile;
                        _fileType = 'image';
                        _extractedText = extractedText;
                      });
                      FileUtils.showExtractedTextDialog(context, extractedText);
                    }
                  }
                } catch (e) {
                  if (e.toString().contains('صلاحيات')) {
                    FileUtils.showPermissionError(context, e.toString());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              onPickPDF: () async {
                setState(() => _isLoading = true);
                try {
                  final pdfFile = await FileUtils.pickPDF();
                  if (pdfFile != null) {
                    final confirmed =
                    await _showPreviewDialog(pdfFile, 'pdf');
                    if (confirmed) {
                      final extractedText =
                      await FileUtils.extractTextFromPDF(pdfFile);
                      setState(() {
                        _selectedFile = pdfFile;
                        _fileType = 'pdf';
                        _extractedText = extractedText;
                      });
                      FileUtils.showExtractedTextDialog(context, extractedText);
                    }
                  }
                } catch (e) {
                  if (e.toString().contains('صلاحيات')) {
                    FileUtils.showPermissionError(context, e.toString());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF5EABD6).withOpacity(0.2),
          child: Icon(icon, color: const Color(0xFF5EABD6)),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
