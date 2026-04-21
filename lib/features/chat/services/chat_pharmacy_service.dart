import 'package:cloud_firestore/cloud_firestore.dart';
import '../../pharmacy/models/pharmacy_model.dart';

class ChatPharmacyService {
  ChatPharmacyService._();
  static final ChatPharmacyService instance = ChatPharmacyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<PharmacyModel?> watchPharmacyById(String pharmacyId) {
    if (pharmacyId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('pharmacies')
        .doc(pharmacyId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return PharmacyModel.fromFirestore(doc);
    });
  }
}