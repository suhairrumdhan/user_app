import 'package:flutter/material.dart';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'map_tab.dart';
import 'preview_screen.dart';
import '../utils/file_utils.dart';
import '../utils/image_source_dialog.dart';
import '../widgets/pharmacy_glass_card.dart';
import 'dart:ui';

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

  final PageController _pageController = PageController(viewportFraction: 0.78);
  int currentIndex = 0;

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
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5EABD6),
              Color(0xFF7BC4EA),
              Color(0xFF9BD8F0),
            ],
            stops: [0.1, 0.5, 0.9],
          ),
        ),
        child: Stack(
          children: [
            // ------------------ المحتوى الرئيسي ------------------
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),

                // ------------------ القسم العلوي (البطاقات) ------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          SizedBox(width: 8),
                          Text(
                            "الصيدليات القريبة",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!widget.isLoading && widget.pharmacies.isNotEmpty)
                        Column(
                          children: [
                            SizedBox(
                              height: isSmallScreen ? 180 : 200,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: widget.pharmacies.length,
                                onPageChanged: (i) => setState(() => currentIndex = i),
                                itemBuilder: (context, index) {
                                  return AnimatedScale(
                                    scale: currentIndex == index ? 1 : 0.88,
                                    duration: const Duration(milliseconds: 300),
                                    child: PharmacyGlassCard(
                                      pharmacy: widget.pharmacies[index],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.pharmacies.length,
                                    (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: currentIndex == i ? 14 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: currentIndex == i
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                    ],
                  ),
                ),

                // ------------------ الجزء السفلي (الخريطة) ------------------
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      child: widget.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : MapTab(
                        currentPosition: widget.currentPosition,
                        pharmacies: widget.pharmacies,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ------------------ الأزرار العائمة الزجاجية ------------------
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: screenWidth * 0.65, // تم تقليل العرض بعد إزالة زر الإعدادات
                  height: isSmallScreen ? 70 : 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // زر العائلة
                            _buildGlassFAB(
                              icon: Icons.family_restroom,
                              label: "العائلة",
                              color: const Color(0xFFE14434),
                              onTap: () {},
                              isSmallScreen: isSmallScreen,
                            ),

                            // الخط الفاصل
                            Container(
                              width: 1,
                              height: isSmallScreen ? 30 : 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            // زر الإضافة الرئيسي (بنفس حجم الأزرار الأخرى)
                            _buildGlassFAB(
                              icon: Icons.add,
                              label: "رفع وصفة",
                              color: const Color(0xFF5EABD6),
                              onTap: () => showImageSourceDialog(
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
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                onPickPDF: () {},
                              ),
                              isSmallScreen: isSmallScreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFAB({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallScreen ? 44 : 48, // نفس الحجم لجميع الأزرار
            height: isSmallScreen ? 44 : 48, // نفس الحجم لجميع الأزرار
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSmallScreen ? 20 : 22, // نفس الحجم لجميع الأيقونات
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}