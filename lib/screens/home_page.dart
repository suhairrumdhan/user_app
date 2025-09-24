import 'package:flutter/material.dart';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'profile_page.dart';
import 'preview_screen.dart';
import 'map_tab.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../utils/image_source_dialog.dart';
import '../utils/file_utils.dart';
import '../utils/location_utils.dart'; // Add this import

const Color inActiveIconColor = Color(0xFFB6B6B6);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentSelectedIndex = 0;
  File? _selectedFile;
  String? _fileType; // 'image' أو 'pdf'
  String _extractedText = ''; // نص المستخرج

  bool _isLoading = false;
  bool _isLocationLoading = true; // Add loading state for location
  LatLng? _currentPosition;
  List<LatLng> _pharmacies = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _pharmacies = LocationUtils.generateNearbyPharmacies(position);
        _isLocationLoading = false; // Update loading state when done
      });
    } catch (e) {
      setState(() {
        _isLocationLoading = false; // Update loading state even on error
      });
      print('Location error: $e');
    }
  }

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

  void updateCurrentIndex(int index) {
    setState(() {
      currentSelectedIndex = index;
    });
  }

  // Update pages to pass the loading state and location data
  List<Widget> get pages => [
    _HomeTabContent(
      currentPosition: _currentPosition,
      pharmacies: _pharmacies,
      isLoading: _isLocationLoading,
    ),
    const Center(child: Text("My Recipes Tab Content")),
    const Center(child: Text("Favorites Tab Content")),
    const Center(child: ProfilePage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: Stack(children: [pages[currentSelectedIndex]]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showImageSourceDialog(
          context: context,
          onPickImage: (source) async {
            setState(() => _isLoading = true);
            try {
              final imageFile = await FileUtils.pickImage(source);
              if (imageFile != null) {
                final confirmed = await _showPreviewDialog(imageFile, 'image');
                if (confirmed) {
                  final extractedText = await FileUtils.extractTextFromImage(
                    imageFile,
                  );
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
                final confirmed = await _showPreviewDialog(pdfFile, 'pdf');
                if (confirmed) {
                  final extractedText = await FileUtils.extractTextFromPDF(
                    pdfFile,
                  );
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
        backgroundColor: Color(0xFFFF7643),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: currentSelectedIndex,
        onTap: updateCurrentIndex,
      ),
    );
  }
}

class _HomeTabContent extends StatelessWidget {
  final LatLng? currentPosition;
  final List<LatLng> pharmacies;
  final bool isLoading;

  const _HomeTabContent({
    required this.currentPosition,
    required this.pharmacies,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          SizedBox(
            height: 300,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  ) // Show loader while loading
                : MapTab(
                    currentPosition: currentPosition,
                    pharmacies: pharmacies,
                  ),
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
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Icon(icon, color: Colors.orange),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
