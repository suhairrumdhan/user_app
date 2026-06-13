import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/controllers/main_navigation_controller.dart';
import '../../../app/core/utils/location_utils.dart';
import '../../../app/core/widgets/custom_bottom_navigation_bar.dart';
import '../../chat/views/chats_screen.dart';
import '../../notifications/views/notifications_page.dart';
import '../../orders/views/orders_page.dart';
import '../../profile/views/profile_page.dart';
import '../models/pharmacy_model.dart';
import 'home_tab_content.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLocationLoading = true;
  LatLng? _currentPosition;

  List<PharmacyModel> _allPharmacies = [];
  List<PharmacyModel> _filteredPharmacies = [];

  double _selectedDistance = 4.0;

  final MainNavigationController _navController =
  Get.find<MainNavigationController>();

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _pharmaciesSubscription;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _listenToPharmacies();
    await _refreshLocation();
    await _startLiveLocation();
  }
  Future<PharmacyModel> _pharmacyFromDocWithBusinessHours(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final hoursDoc = await FirebaseFirestore.instance
        .collection('pharmacies')
        .doc(doc.id)
        .collection('settings')
        .doc('businessHours')
        .get();

    return PharmacyModel.fromFirestore(
      doc,
      workingHours: hoursDoc.data(),
    );
  }
  Future<void> _listenToPharmacies() async {
    await _pharmaciesSubscription?.cancel();

    _pharmaciesSubscription = FirebaseFirestore.instance
        .collection('pharmacies')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
          (snapshot) async {
        final pharmacies = await Future.wait(
          snapshot.docs.map((doc) => _pharmacyFromDocWithBusinessHours(doc)),
        );

        final pharmaciesWithDistance = _currentPosition == null
            ? pharmacies
            : _attachDistances(
          pharmacies: pharmacies,
          currentPosition: _currentPosition!,
        );

        final filtered = _currentPosition == null
            ? <PharmacyModel>[]
            : pharmaciesWithDistance.where((pharmacy) {
          final distance = pharmacy.distance;
          if (distance == null) return false;
          return (distance / 1000) <= _selectedDistance;
        }).toList()
          ..sort(
                (a, b) => (a.distance ?? double.infinity)
                .compareTo(b.distance ?? double.infinity),
          );

        if (!mounted) return;

        setState(() {
          _allPharmacies = pharmaciesWithDistance;
          _filteredPharmacies = filtered;
          _isLocationLoading = false;
        });
      },
      onError: (error) {
        debugPrint('Error listening to pharmacies: $error');
        if (!mounted) return;
        setState(() {
          _isLocationLoading = false;
        });
      },
    );
  }

  List<PharmacyModel> _attachDistances({
    required List<PharmacyModel> pharmacies,
    required LatLng currentPosition,
  }) {
    return pharmacies.map((pharmacy) {
      final lat = pharmacy.latitude;
      final lng = pharmacy.longitude;

      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        return pharmacy.copyWith(distance: null);
      }

      final distance = LocationUtils.calculateDistance(
        currentPosition,
        LatLng(lat, lng),
      );

      return pharmacy.copyWith(distance: distance);
    }).toList();
  }

  void _filterPharmaciesByDistance(double maxDistanceInKm) {
    final filtered = _allPharmacies.where((pharmacy) {
      final distance = pharmacy.distance;
      if (distance == null) return false;

      return (distance / 1000) <= maxDistanceInKm;
    }).toList()
      ..sort(
            (a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity),
      );

    setState(() {
      _selectedDistance = maxDistanceInKm;
      _filteredPharmacies = filtered;
    });
  }

  Future<void> _updateCurrentLocationAndPharmacies(LatLng position) async {
    final pharmaciesWithDistance = _attachDistances(
      pharmacies: _allPharmacies,
      currentPosition: position,
    );

    final filtered = pharmaciesWithDistance.where((pharmacy) {
      final distance = pharmacy.distance;
      if (distance == null) return false;
      return (distance / 1000) <= _selectedDistance;
    }).toList()
      ..sort(
            (a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity),
      );

    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _allPharmacies = pharmaciesWithDistance;
      _filteredPharmacies = filtered;
      _isLocationLoading = false;
    });
  }

  Future<void> _startLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        await LocationDialog.showServiceDisabledDialog(context);
      }
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (mounted) {
          await LocationDialog.showPermissionDialog(context);
          setState(() => _isLocationLoading = false);
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        await LocationDialog.showPermissionDialog(context);
        setState(() => _isLocationLoading = false);
      }
      return;
    }

    _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(
          (Position position) async {
        final current = LatLng(position.latitude, position.longitude);

        if (_currentPosition != null) {
          final movedMeters = LocationUtils.calculateDistance(
            _currentPosition!,
            current,
          );

          if (movedMeters < 15) return;
        }

        try {
          await _updateCurrentLocationAndPharmacies(current);
        } catch (e) {
          debugPrint('Error updating live location: $e');
          if (mounted) {
            setState(() => _isLocationLoading = false);
          }
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
        if (mounted) {
          setState(() => _isLocationLoading = false);
        }
      },
    );
  }

  Future<void> _refreshLocation() async {
    if (mounted) {
      setState(() {
        _isLocationLoading = true;
      });
    }

    try {
      final position = await LocationUtils.getCurrentPosition(context);

      if (position == null) {
        if (mounted) {
          setState(() {
            _filteredPharmacies = [];
            _isLocationLoading = false;
          });
        }
        return;
      }

      await _updateCurrentLocationAndPharmacies(position);
    } catch (e) {
      debugPrint('Error refreshing location: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ في تحديث الموقع'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  List<Widget> get pages => [
    HomeTabContent(
      currentPosition: _currentPosition,
      pharmacies: _filteredPharmacies,
      allPharmacies: _allPharmacies,
      isLoading: _isLocationLoading,
      onRefresh: _refreshLocation,
      selectedDistance: _selectedDistance,
      onDistanceChanged: _filterPharmaciesByDistance,
    ),
    ChatsScreen(),
    OrdersPage(),
    const NotificationsPage(),
    const ProfilePage(),
  ];

  @override
  void dispose() {
    _positionStream?.cancel();
    _pharmaciesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentIndex = _navController.currentIndex.value;

      return Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _navController.changeIndex,
        ),
      );
    });
  }
}