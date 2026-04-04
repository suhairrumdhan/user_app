import 'dart:ui';
import 'package:flutter/material.dart';
import '../../pharmacy/widgets/pharmacy_glass_card.dart';

class MedicineResultsPage extends StatefulWidget {
  final List<dynamic> medicines;

  const MedicineResultsPage({Key? key, required this.medicines}) : super(key: key);

  @override
  State<MedicineResultsPage> createState() => _MedicineResultsPageState();
}

class _MedicineResultsPageState extends State<MedicineResultsPage> {
  List<dynamic> filteredPharmacies = [];
  List<String> selectedMedicines = [];
  bool _isLoading = true;
  int _currentTabIndex = 0;

  // Elegant color palette
  final Color primaryColor = const Color(0xFF5EABD6);
  final Color primaryLight = const Color(0xFF8BC7EA);
  final Color primaryDark = const Color(0xFF4A8BB3);
  final Color accentColor = const Color(0xFFFF6B6B);
  final Color successColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFFAFBFE);
  final Color cardColor = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
    selectedMedicines = widget.medicines
        .map((m) => m['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  void _loadPharmacies() async {
    final pharmacies = await _fetchNearbyPharmacies();
    setState(() {
      filteredPharmacies = pharmacies;
      _isLoading = false;
    });
  }

  Future<List<dynamic>> _fetchNearbyPharmacies() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      {
        'name': 'صيدلية النور',
        'address': 'شارع الملك فهد - الرياض',
        'distance': 500,
        'is24Hours': true,
        'phone': '0112345678',
        'rating': 4.5,
        'imageUrl': '',
      },
      {
        'name': 'صيدلية الدواء',
        'address': 'حي العليا - الرياض',
        'distance': 1200,
        'is24Hours': false,
        'workingHours': {
          'sunday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
          'monday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
          'tuesday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
          'wednesday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
          'thursday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
          'friday': {'isOpen': false, 'open': '16:00', 'close': '23:00'},
          'saturday': {'isOpen': true, 'open': '08:00', 'close': '23:00'},
        },
        'phone': '0112345679',
        'rating': 4.2,
        'imageUrl': '',
      },
    ];
  }

  void _toggleMedicineSelection(String medicineName) {
    setState(() {
      if (selectedMedicines.contains(medicineName)) {
        selectedMedicines.remove(medicineName);
      } else {
        selectedMedicines.add(medicineName);
      }
    });
  }

  void _selectAllMedicines() {
    setState(() {
      selectedMedicines = widget.medicines
          .map((m) => m['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    });
  }

  void _deselectAllMedicines() {
    setState(() {
      selectedMedicines.clear();
    });
  }

  void _removeMedicine(String medicineName) {
    setState(() {
      selectedMedicines.remove(medicineName);
    });
  }

  void _searchPharmacies() {
    setState(() {
      _isLoading = true;
      _currentTabIndex = 1;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _sendOrderToPharmacy(Map<String, dynamic> pharmacy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOrderBottomSheet(pharmacy),
    );
  }

  Widget _buildOrderBottomSheet(Map<String, dynamic> pharmacy) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_pharmacy, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacy['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pharmacy['address'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Medicines List
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأدوية المطلوبة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                ...selectedMedicines.take(3).map((medicine) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.medical_services, size: 18, color: primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          medicine,
                          style: const TextStyle(
                            color: Color(0xFF2D3748),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                if (selectedMedicines.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'و ${selectedMedicines.length - 3} أدوية أخرى',
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF718096),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
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
                    onPressed: () {
                      Navigator.pop(context);
                      _showOrderConfirmation(pharmacy);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.3),
                    ),
                    child: const Text(
                      'تأكيد الطلب',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmation(Map<String, dynamic> pharmacy) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.check, color: successColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم إرسال الطلب إلى ${pharmacy['name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${selectedMedicines.length} دواء - سيتم التواصل معك قريباً',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: successColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medical_services, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'نتائج الأدوية',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (selectedMedicines.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${selectedMedicines.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.medical_services, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'اختر الأدوية التي تريد البحث عنها في الصيدليات',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(0, 'الأدوية', Icons.medical_services_outlined),
          ),
          Expanded(
            child: _buildTabItem(1, 'الصيدليات', Icons.local_pharmacy_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    bool isSelected = _currentTabIndex == index;
    return Material(
      color: isSelected ? cardColor : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: primaryLight, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? primaryColor : const Color(0xFF718096),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? primaryColor : const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicinesTab() {
    return Column(
      children: [
        // Quick Actions
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'اختيار الكل',
                  Icons.check_circle_outline,
                  successColor,
                  _selectAllMedicines,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'إلغاء الكل',
                  Icons.highlight_off_outlined,
                  accentColor,
                  _deselectAllMedicines,
                ),
              ),
            ],
          ),
        ),

        // Medicines List
        Expanded(
          child: widget.medicines.isEmpty
              ? _buildEmptyState(
            Icons.medical_services_outlined,
            'لا توجد أدوية',
            'لم يتم استخراج أي أدوية من الوصفة',
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: widget.medicines.length,
            itemBuilder: (context, index) {
              final medicine = widget.medicines[index];
              return _buildMedicineItem(medicine, index);
            },
          ),
        ),

        // Search Button
        if (selectedMedicines.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.search, size: 20),
              ),
              label: Text(
                'ابحث في الصيدليات (${selectedMedicines.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _searchPharmacies,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(text),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: color.withOpacity(0.05),
      ),
    );
  }

  Widget _buildMedicineItem(Map<String, dynamic> medicine, int index) {
    bool isSelected = selectedMedicines.contains(medicine['name']);
    String medicineName = medicine['name']?.toString() ?? 'غير معروف';

    // FIXED: Safe handling of medicine details
    String dosage = medicine['dosage']?.toString() ?? "-";
    String route = medicine['route']?.toString() ?? "-";
    String frequency = medicine['frequency']?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleMedicineSelection(medicineName),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              gradient: isSelected
                  ? LinearGradient(
                colors: [primaryColor.withOpacity(0.05), primaryLight.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
            ),
            child: Row(
              children: [
                // Elegant Selection Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : const Icon(Icons.add, color: Colors.grey, size: 20),
                  ),
                ),

                const SizedBox(width: 16),

                // Medicine Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryDark : const Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$dosage • $route',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF718096),
                        ),
                      ),
                      if (frequency.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          frequency,
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Delete Icon for selected medicines
                if (isSelected)
                  IconButton(
                    onPressed: () => _removeMedicine(medicineName),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: accentColor,
                        size: 20,
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

  Widget _buildPharmaciesTab() {
    return Column(
      children: [
        // Search Info
        if (selectedMedicines.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [successColor.withOpacity(0.1), successColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: successColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.search, color: successColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'جاري البحث عن الأدوية',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'سيتم عرض الصيدليات التي تتوفر فيها هذه الأدوية',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Pharmacies List
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : filteredPharmacies.isEmpty
              ? _buildEmptyState(
            Icons.local_pharmacy_outlined,
            'لا توجد صيدليات',
            'لم يتم العثور على صيدليات قريبة',
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              ...filteredPharmacies.map((pharmacy) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPharmacyCard(pharmacy),
              )),
            ],
          ),
        ),
      ],
    );
  }

  // FIXED: New pharmacy card with similar design to PharmacyGlassCard
  Widget _buildPharmacyCard(Map<String, dynamic> pharmacy) {
    // FIXED: Safe distance calculation
    double distance = 0.0;
    if (pharmacy['distance'] != null) {
      if (pharmacy['distance'] is int) {
        distance = (pharmacy['distance'] as int) / 1000.0;
      } else if (pharmacy['distance'] is double) {
        distance = pharmacy['distance'] / 1000.0;
      } else if (pharmacy['distance'] is String) {
        distance = double.tryParse(pharmacy['distance']) ?? 0.0;
      }
    }
    String distanceText = distance.toStringAsFixed(1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryLight.withOpacity(0.15),
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryDark.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Row(
                children: [
                  // Pharmacy Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5EABD6), Color(0xFF7FCFEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryDark.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Pharmacy Name and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pharmacy["name"] ?? "صيدلية",
                          style: const TextStyle(
                            color: Color(0xFF2D3748),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: successColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: successColor,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pharmacy['is24Hours'] == true ? 'مفتوح 24 ساعة' : 'مفتوح الآن',
                                style: TextStyle(
                                  color: successColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pharmacy["address"] ?? "العنوان غير متوفر",
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rating
              Row(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pharmacy['rating'] ?? '0.0'}',
                    style: const TextStyle(
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'تقييم',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Footer with distance and action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Distance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$distanceText كم",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Order Button
                  ElevatedButton(
                    onPressed: () => _sendOrderToPharmacy(pharmacy),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('طلب'),
                      ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'جاري البحث في الصيدليات...',
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedMedicines.length} دواء قيد البحث',
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(icon, size: 64, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _currentTabIndex == 0 ? _buildMedicinesTab() : _buildPharmaciesTab(),
          ),
        ],
      ),
    );
  }
}