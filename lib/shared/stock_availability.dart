/// Shared quantity contract: unopened packages and loose pieces are distinct.
class StockAvailability {
  final int packages;
  final int pieces;
  final int reservedPackages;
  final int reservedPieces;
  final int units;
  const StockAvailability({
    required this.packages,
    required this.pieces,
    required this.reservedPackages,
    required this.reservedPieces,
    required this.units,
  });

  factory StockAvailability.fromMap(Map<String, dynamic> data) {
    int count(String key) {
      final raw = data[key] ?? 0;
      final n = num.tryParse(raw.toString());
      if (n == null ||
          !n.isFinite ||
          n < 0 ||
          n > 9007199254740991 ||
          n != n.truncateToDouble()) {
        throw StateError('بيانات كمية المخزون غير صالحة: $key');
      }
      return n.toInt();
    }

    final result = StockAvailability(
      packages: count('quantity'),
      pieces: count('pieceQuantity'),
      reservedPackages: count('reservedQuantity'),
      reservedPieces: count('reservedPieceQuantity'),
      units: count('unitsPerPackage'),
    );
    if (result.availablePackages < 0 ||
        result.availablePieces < 0 ||
        result.availablePieces > 9007199254740991) {
      throw StateError('الحجوزات تتجاوز المخزون الفعلي');
    }
    return result;
  }

  int get availablePackages {
    final missing = reservedPieces - pieces;
    if (missing > 0 && units == 0) return -1;
    final backing = missing > 0 ? (missing + units - 1) ~/ units : 0;
    return packages - reservedPackages - backing;
  }

  int get availablePieces =>
      (packages - reservedPackages) * units + pieces - reservedPieces;

  Map<String, int> sell({required int packageCount, required int pieceCount}) {
    if (packageCount < 0 ||
        pieceCount < 0 ||
        packageCount > availablePackages ||
        pieceCount > availablePieces - packageCount * units) {
      throw StateError('الكمية غير متاحة بعد استبعاد حجوزات الطلبات');
    }
    final missing = pieceCount - pieces;
    if (missing > 0 && units == 0)
      throw StateError('عدد القطع في العبوة غير محدد');
    final opened = missing > 0 ? (missing + units - 1) ~/ units : 0;
    return {
      'quantity': packages - packageCount - opened,
      'pieceQuantity': pieces + opened * units - pieceCount,
    };
  }
}
