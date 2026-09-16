import 'package:cloud_firestore/cloud_firestore.dart';
import 'stock_availability.dart';

bool pharmacyVisibleInSearch(Map<String, dynamic> pharmacy) =>
    (pharmacy['status'] ?? '').toString().trim().toLowerCase() == 'approved' &&
    pharmacy['isActive'] != false &&
    pharmacy['isBlocked'] != true;

bool pharmacyAcceptsNewOrders(Map<String, dynamic> pharmacy) =>
    pharmacyVisibleInSearch(pharmacy) && pharmacy['isOnline'] == true;

class MedicineSaleState {
  MedicineSaleState.fromMap(Map<String, dynamic> medicine, {DateTime? now}) {
    final raw = medicine['expiryDate'];
    if (raw is Timestamp) {
      expiryAt = raw.toDate().toUtc();
    } else if (raw is DateTime) {
      expiryAt = raw.toUtc();
    } else if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      // Match the source server's UTC interpretation of timezone-less ISO.
      expiryAt = parsed == null
          ? null
          : parsed.isUtc
          ? parsed
          : DateTime.utc(
              parsed.year,
              parsed.month,
              parsed.day,
              parsed.hour,
              parsed.minute,
              parsed.second,
              parsed.millisecond,
              parsed.microsecond,
            );
    }
    invalidExpiry = raw != null && expiryAt == null;
    expired =
        expiryAt != null && !expiryAt!.isAfter((now ?? DateTime.now()).toUtc());
    active = medicine['isActive'] == null || medicine['isActive'] == true;
  }

  DateTime? expiryAt;
  late final bool invalidExpiry;
  late final bool expired;
  late final bool active;
  bool get saleable => active && !invalidExpiry && !expired;
}

bool medicineAvailableForSearch(Map<String, dynamic> data, {DateTime? now}) {
  if (data['available'] == false ||
      data['isExpired'] == true ||
      data['invalidStock'] == true ||
      data['invalidExpiry'] == true ||
      data['pharmacyVisible'] == false ||
      data['isBlocked'] == true ||
      !MedicineSaleState.fromMap(data, now: now).saleable) {
    return false;
  }
  try {
    final stock = StockAvailability.fromMap(data);
    return stock.availablePackages > 0 ||
        (data['sellByPiece'] == true && stock.availablePieces > 0);
  } on StateError {
    return false;
  }
}
