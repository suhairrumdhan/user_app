import '../../../shared/availability_policy.dart';
import '../../../shared/stock_availability.dart';

/// An estimate in one explicit selling unit, never package price for a piece.
class MedicineSaleQuote {
  const MedicineSaleQuote({
    required this.stock,
    required this.soldByPiece,
    required this.price,
  });

  final StockAvailability stock;
  final bool soldByPiece;
  final double price;
  int get availableQuantity =>
      soldByPiece ? stock.availablePieces : stock.availablePackages;

  static MedicineSaleQuote? fromIndex(
    Map<String, dynamic> data, {
    bool? soldByPiece,
    DateTime? now,
  }) {
    if (!medicineAvailableForSearch(data, now: now)) return null;
    final stock = StockAvailability.fromMap(data);
    final piecesEnabled = data['sellByPiece'] == true;
    final usePieces =
        soldByPiece ?? (piecesEnabled && stock.availablePieces > 0);
    if (usePieces && (!piecesEnabled || stock.availablePieces <= 0)) {
      return null;
    }
    if (!usePieces && stock.availablePackages <= 0) return null;

    double positivePrice(dynamic raw) {
      final value = num.tryParse(raw?.toString() ?? '');
      return value != null && value.isFinite && value > 0
          ? value.toDouble()
          : 0;
    }

    final packagePrice = positivePrice(data['sellingPrice']);
    final configuredPiecePrice = positivePrice(data['piecePrice']);
    final piecePrice = configuredPiecePrice > 0
        ? configuredPiecePrice
        : stock.units > 0
        ? packagePrice / stock.units
        : 0.0;
    return MedicineSaleQuote(
      stock: stock,
      soldByPiece: usePieces,
      price: usePieces ? piecePrice : packagePrice,
    );
  }
}
