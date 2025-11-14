import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pharmacy_history.dart';

class PharmacyHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب الصيدليات التي تم الطلب منها (Ordered)
  Future<List<PharmacyHistory>> getOrderedPharmacies(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return PharmacyHistory(
        name: data['pharmacyName'] ?? 'غير معروف',
        address: data['pharmacyAddress'] ?? '',
        date: data['date'] != null
            ? (data['date'] as Timestamp).toDate().toString()
            : '',
        searchCount: data['totalItems'] ?? 0,
      );
    }).toList();
  }

  // جلب الصيدليات التي تم البحث عنها (Searched)
  Future<List<PharmacyHistory>> getSearchedPharmacies(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('searches')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return PharmacyHistory(
        name: data['pharmacyName'] ?? 'غير معروف',
        address: data['pharmacyAddress'] ?? '',
        date: data['lastSearch'] != null
            ? (data['lastSearch'] as Timestamp).toDate().toString()
            : '',
        searchCount: data['searchCount'] ?? 0,
      );
    }).toList();
  }
}
