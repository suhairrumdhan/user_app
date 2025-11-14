import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ لجلب البيانات من فايربيز
import 'PharmacyHistoryPage.dart';
import 'chats_screen.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../utils/location_utils.dart';
import 'home_tab_content.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentSelectedIndex = 0;
  bool _isLocationLoading = true;
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _pharmacies = [];

  List<PharmacyHistory> _searchedPharmacies = [];
  List<PharmacyHistory> _orderedPharmacies = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchPharmacyHistories(); // ✅ جلب البيانات من الفايربيز
  }

  // 🔹 جلب موقع المستخدم والصيدليات القريبة
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final position = await LocationUtils.getCurrentPosition();
      final nearbyPharmacies = await LocationUtils.getNearbyPharmacies(
        currentPosition: position,
        radiusInKm: 5,
      );

      setState(() {
        _currentPosition = position;
        _pharmacies = nearbyPharmacies;
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() => _isLocationLoading = false);
      print('⚠️ خطأ في تحديد الموقع أو تحميل الصيدليات: $e');
    }
  }

  // 🔹 جلب بيانات السجلات من Firebase Firestore
  Future<void> _fetchPharmacyHistories() async {
    try {
      final searchedSnapshot =
      await FirebaseFirestore.instance.collection('searched_pharmacies').get();
      final orderedSnapshot =
      await FirebaseFirestore.instance.collection('ordered_pharmacies').get();

      setState(() {
        _searchedPharmacies = searchedSnapshot.docs.map((doc) {
          final data = doc.data();
          return PharmacyHistory(
            name: data['name'] ?? 'غير معروف',
            address: data['address'] ?? 'غير معروف',
            date: data['date'] ?? '',
            searchCount: data['searchCount'] ?? 0,
          );
        }).toList();

        _orderedPharmacies = orderedSnapshot.docs.map((doc) {
          final data = doc.data();
          return PharmacyHistory(
            name: data['name'] ?? 'غير معروف',
            address: data['address'] ?? 'غير معروف',
            date: data['date'] ?? '',
            searchCount: data['searchCount'] ?? 0,
          );
        }).toList();
      });
    } catch (e) {
      print('⚠️ خطأ في جلب بيانات الصيدليات من Firebase: $e');
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
    PharmacyHistoryPage(
      orderedPharmacies: _orderedPharmacies,
      searchedPharmacies: _searchedPharmacies,
    ),
    const NotificationsPage(),
    const ProfilePage(),
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
