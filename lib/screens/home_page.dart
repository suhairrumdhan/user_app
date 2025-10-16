import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'PharmacyHistoryPage.dart';
import 'chats_screen.dart';
import 'profile_page.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../utils/location_utils.dart';
import 'home_tab_content.dart'; // ✅ الاستيراد الجديد

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentSelectedIndex = 0;
  bool _isLocationLoading = true;
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
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() => _isLocationLoading = false);
    }
  }

  void updateCurrentIndex(int index) {
    setState(() {
      currentSelectedIndex = index;
    });
  }
  List<Widget> get pages => [
    HomeTabContent(
      currentPosition: _currentPosition,
      pharmacies: _pharmacies,
      isLoading: _isLocationLoading,
    ),
    const ChatsScreen(),
    PharmacyHistoryPage( // ✅ الصفحة الجديدة
      orderedPharmacies: _orderedPharmacies,
      searchedPharmacies: _searchedPharmacies,
    ),
    const Center(child: Text("Notifications Tab Content")),
    const ProfilePage(),
  ];
  // Example data for testing
  final List<PharmacyHistory> _orderedPharmacies = [
    PharmacyHistory(
      name: "السناء",
      address: "ابوسليم",
      date: "2 hours ago",
      orderCount: 3,
    ),
    PharmacyHistory(
      name: "دوام الصحة",
      address: "قرقارش",
      date: "1 day ago",
      orderCount: 1,
    ),
  ];

  final List<PharmacyHistory> _searchedPharmacies = [
    PharmacyHistory(
      name: "القلب",
      address: "طرابلس",
      date: " 15 times",
      searchCount: 15,
    ),
    PharmacyHistory(
      name: "النور",
      address: "الهضبة",
      date: " 8 times",
      searchCount: 8,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentSelectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: currentSelectedIndex,
        onTap: updateCurrentIndex,
      ),
    );
  }
}
