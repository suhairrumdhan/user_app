import 'package:flutter/material.dart';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'map_tab.dart';
import 'preview_screen.dart';
import '../utils/file_utils.dart';
import '../utils/image_source_dialog.dart';
import '../widgets/pharmacy_card.dart';

class HomeTabContent extends StatefulWidget {
  final LatLng? currentPosition;
  final List<Map<String, dynamic>> pharmacies;
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final mapHeight = isLandscape
        ? screenHeight * 0.6
        : screenHeight * 0.42;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenHeight * 0.1),

            // 🔹 خريطة الصيدليات
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

            const SizedBox(height: 16),

            // 🔹 بطاقات الصيدليات القريبة
            if (!widget.isLoading && widget.pharmacies.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.local_pharmacy, color: Color(0xFF5EABD6), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "الصيدليات القريبة",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...widget.pharmacies.asMap().entries.map((entry) {
                final index = entry.key;
                final pharmacy = entry.value;
                return PharmacyCard(
                  pharmacy: pharmacy,
                  index: index,
                );
              }),
              const SizedBox(height: 80), // مساحة إضافية لتجنب تغطية الزر العائم
            ],
          ],
        ),
      ),

      // 🔹 الأزرار العائمة
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "familyBtn",
            backgroundColor: const Color(0xFFE14434),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('زر العائلة تم الضغط عليه!')),
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
                    final confirmed = await _showPreviewDialog(imageFile, 'image');
                    if (confirmed) {
                      final extractedText = await FileUtils.extractTextFromImage(imageFile);
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
                      SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
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
                    final confirmed = await _showPreviewDialog(pdfFile, 'pdf');
                    if (confirmed) {
                      final extractedText = await FileUtils.extractTextFromPDF(pdfFile);
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

}

