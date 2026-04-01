import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

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
  List<Map<String, dynamic>> _pharmacies = []; // الصيدليات القريبة
  List<Map<String, dynamic>> _allPharmacies = []; // 🔥 جميع الصيدليات

  List<PharmacyHistory> _searchedPharmacies = [];
  List<PharmacyHistory> _orderedPharmacies = [];

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startLiveLocation(); // 🔥 تشغيل التحديث المباشر
    _fetchAllPharmacies(); // 🔥 جلب جميع الصيدليات
    _fetchPharmacyHistories();
  }

  // ===============================
  // 🔥 جلب جميع الصيدليات من Firebase
  // ===============================
  Future<void> _fetchAllPharmacies() async {
    try {
      final allPharmacies = await LocationUtils.fetchAllPharmacies();
      setState(() {
        _allPharmacies = allPharmacies;
      });
      debugPrint('📦 Total pharmacies loaded: ${allPharmacies.length}');
    } catch (e) {
      debugPrint('Error fetching all pharmacies: $e');
    }
  }

  // ===============================
  // 🔴 التحديث المباشر (كل 30 متر)
  // ===============================
  Future<void> _startLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await LocationDialog.showServiceDisabledDialog(context);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        await LocationDialog.showPermissionDialog(context);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await LocationDialog.showPermissionDialog(context);
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // 🔥 كل 30 متر
      ),
    ).listen((Position position) async {
      final current = LatLng(position.latitude, position.longitude);

      final nearbyPharmacies = await LocationUtils.getNearbyPharmacies(
        currentPosition: current,
        radiusInKm: 4,
      );

      setState(() {
        _currentPosition = current;
        _pharmacies = nearbyPharmacies;
        _isLocationLoading = false;
      });
    });
  }

  // ===============================
  // 🟡 تحديث يدوي (زر)
  // ===============================
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      final position = await LocationUtils.getCurrentPosition(context);

      if (position == null) {
        setState(() => _isLocationLoading = false);
        return;
      }

      final nearbyPharmacies = await LocationUtils.getNearbyPharmacies(
        currentPosition: position,
        radiusInKm: 4,
      );

      setState(() {
        _currentPosition = position;
        _pharmacies = nearbyPharmacies;
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() => _isLocationLoading = false);
      print('⚠️ خطأ: $e');
    }
  }

  // ===============================
  // 🔹 جلب بيانات Firebase للتاريخ
  // ===============================
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
      print('⚠️ خطأ في Firebase: $e');
    }
  }

  void updateCurrentIndex(int index) {
    setState(() {
      currentSelectedIndex = index;
    });
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // جلب الموقع الحالي
      final position = await LocationUtils.getCurrentPosition(context);

      if (position != null) {
        // جلب الصيدليات القريبة
        final nearbyPharmacies = await LocationUtils.getNearbyPharmacies(
          currentPosition: position,
          radiusInKm: 4,
        );

        setState(() {
          _currentPosition = position;
          _pharmacies = nearbyPharmacies;
        });
      } else {
        // إذا لم يتم الحصول على الموقع
        setState(() {
          _pharmacies = [];
        });
      }
    } catch (e) {
      print('Error refreshing location: $e');
      // عرض رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ في تحديث الموقع'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  List<Widget> get pages => [
    HomeTabContent(
      currentPosition: _currentPosition,
      pharmacies: _pharmacies, // الصيدليات القريبة فقط
      allPharmacies: _allPharmacies, // 🔥 جميع الصيدليات
      isLoading: _isLocationLoading,
      onRefresh: _refreshLocation,
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
  void dispose() {
    _positionStream?.cancel(); // 🔥 إيقاف التتبع
    super.dispose();
  }

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