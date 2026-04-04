import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/core/utils/location_utils.dart';
import '../../../app/core/widgets/custom_bottom_navigation_bar.dart';
import '../../chat/views/chats_screen.dart';
import '../../notifications/views/notifications_page.dart';
import '../../profile/views/profile_page.dart';
import '../models/pharmacy_history.dart';
import '../models/pharmacy_model.dart';
import 'home_tab_content.dart';
import 'pharmacy_history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentSelectedIndex = 0;

  bool _isLocationLoading = true;
  LatLng? _currentPosition;

  List<PharmacyModel> _allPharmacies = [];
  List<PharmacyModel> _filteredPharmacies = [];

  double _selectedDistance = 4.0;

  List<PharmacyHistory> _searchedPharmacies = [];
  List<PharmacyHistory> _orderedPharmacies = [];

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _fetchAllPharmacies();
    await _fetchPharmacyHistories();
    await _startLiveLocation();
  }

  Future<void> _fetchAllPharmacies() async {
    try {
      final allPharmacies = await LocationUtils.fetchAllPharmacies();

      if (!mounted) return;

      setState(() {
        _allPharmacies = allPharmacies;
      });

      debugPrint('📦 Total pharmacies loaded: ${allPharmacies.length}');
    } catch (e) {
      debugPrint('Error fetching all pharmacies: $e');
    }
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
    if (_currentPosition == null || _allPharmacies.isEmpty) {
      setState(() {
        _selectedDistance = maxDistanceInKm;
        _filteredPharmacies = [];
      });
      return;
    }

    final filtered = _allPharmacies.where((pharmacy) {
      final distance = pharmacy.distance;
      if (distance == null) return false;

      final distanceInKm = distance / 1000;
      return distanceInKm <= maxDistanceInKm;
    }).toList();

    filtered.sort(
          (a, b) => (a.distance ?? double.infinity).compareTo(
        b.distance ?? double.infinity,
      ),
    );

    setState(() {
      _filteredPharmacies = filtered;
      _selectedDistance = maxDistanceInKm;
    });
  }

  Future<void> _updateCurrentLocationAndPharmacies(LatLng position) async {
    final allPharmacies = await LocationUtils.fetchAllPharmacies();
    final pharmaciesWithDistance = _attachDistances(
      pharmacies: allPharmacies,
      currentPosition: position,
    );

    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _allPharmacies = pharmaciesWithDistance;
      _isLocationLoading = false;
    });

    _filterPharmaciesByDistance(_selectedDistance);
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

  Future<void> _fetchPharmacyHistories() async {
    try {
      final searchedSnapshot = await FirebaseFirestore.instance
          .collection('searched_pharmacies')
          .get();

      final orderedSnapshot = await FirebaseFirestore.instance
          .collection('ordered_pharmacies')
          .get();

      final searched = searchedSnapshot.docs.map((doc) {
        final data = doc.data();
        return PharmacyHistory(
          name: data['name'] ?? 'غير معروف',
          address: data['address'] ?? 'غير معروف',
          date: data['date'] ?? '',
          searchCount: data['searchCount'] ?? 0,
        );
      }).toList();

      final ordered = orderedSnapshot.docs.map((doc) {
        final data = doc.data();
        return PharmacyHistory(
          name: data['name'] ?? 'غير معروف',
          address: data['address'] ?? 'غير معروف',
          date: data['date'] ?? '',
          searchCount: data['searchCount'] ?? 0,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _searchedPharmacies = searched;
        _orderedPharmacies = ordered;
      });
    } catch (e) {
      debugPrint('⚠️ خطأ في Firebase: $e');
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
      pharmacies: _filteredPharmacies,
      allPharmacies: _allPharmacies,
      isLoading: _isLocationLoading,
      onRefresh: _refreshLocation,
      selectedDistance: _selectedDistance,
      onDistanceChanged: _filterPharmaciesByDistance,
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
    _positionStream?.cancel();
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