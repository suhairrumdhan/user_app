import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/search/models/medicine_sale_quote.dart';
import 'package:user_application/features/search/models/medicine_search_request.dart';
import 'package:user_application/features/search/services/medicine_matcher.dart';

void main() {
  final index = <String, dynamic>{
    'pharmacyId': 'pharmacy',
    'medicineId': 'drug',
    'medicineName': 'Example Drug',
    'quantity': 2,
    'pieceQuantity': 0,
    'reservedQuantity': 1,
    'reservedPieceQuantity': 0,
    'unitsPerPackage': 10,
    'sellByPiece': true,
    'sellingPrice': 20,
    'expiryDate': '2099-01-01T00:00:00Z',
  };
  test('missing piece price converts the package price by its unit count', () {
    final quote = MedicineSaleQuote.fromIndex(index)!;
    expect(quote.soldByPiece, isTrue);
    expect(quote.price, 2);
    expect(quote.availableQuantity, 10);
  });
  test('explicit piece price wins over conversion', () {
    expect(MedicineSaleQuote.fromIndex({...index, 'piecePrice': 3})!.price, 3);
  });
  test(
    'nonpositive or nonfinite piece prices never masquerade as a package price',
    () {
      for (final price in [0, -1, 'NaN', double.infinity]) {
        expect(
          MedicineSaleQuote.fromIndex({...index, 'piecePrice': price})!.price,
          2,
        );
      }
    },
  );
  test('package-only stock selects package price and package quantity', () {
    final quote = MedicineSaleQuote.fromIndex({
      ...index,
      'unitsPerPackage': 0,
    })!;
    expect(quote.soldByPiece, isFalse);
    expect(quote.price, 20);
    expect(quote.availableQuantity, 1);
  });
  test(
    'requested piece unit is rejected rather than silently changed to a package',
    () {
      expect(
        MedicineSaleQuote.fromIndex({
          ...index,
          'unitsPerPackage': 0,
        }, soldByPiece: true),
        isNull,
      );
      expect(
        MedicineSaleQuote.fromIndex({
          ...index,
          'sellByPiece': false,
        }, soldByPiece: true),
        isNull,
      );
    },
  );
  test(
    'loose pieces without a conversion or piece price show an unknown price',
    () {
      final quote = MedicineSaleQuote.fromIndex({
        ...index,
        'quantity': 0,
        'reservedQuantity': 0,
        'unitsPerPackage': 0,
        'pieceQuantity': 3,
      })!;
      expect(quote.soldByPiece, isTrue);
      expect(quote.availableQuantity, 3);
      expect(quote.price, 0);
    },
  );
  test(
    'partial piece reservation reduces package availability without counting stock twice',
    () {
      final quote = MedicineSaleQuote.fromIndex({
        ...index,
        'reservedPieceQuantity': 1,
      })!;
      expect(quote.availableQuantity, 9);
      expect(quote.stock.availablePackages, 0);
      expect(
        MedicineSaleQuote.fromIndex({
          ...index,
          'reservedPieceQuantity': 1,
        }, soldByPiece: false),
        isNull,
      );
    },
  );
  test('changed availability and expiry invalidate a saved selection', () {
    for (final patch in [
      {'reservedQuantity': 2},
      {'expiryDate': '2020-01-01'},
      {'pharmacyVisible': false},
    ]) {
      expect(
        MedicineSaleQuote.fromIndex({...index, ...patch}, soldByPiece: true),
        isNull,
      );
    }
  });
  test('real matcher uses the same unit and price as order confirmation', () {
    final request = MedicineSearchRequest(
      requestKey: 'request',
      rawText: 'Example Drug',
      normalizedText: 'EXAMPLE DRUG',
    );
    for (final units in [0, 10]) {
      final data = {...index, 'unitsPerPackage': units};
      final match = MedicineMatcher.matchMedicine(
        request: request,
        medicineData: data,
      )!;
      final quote = MedicineSaleQuote.fromIndex(
        data,
        soldByPiece: match.soldByPiece,
      )!;
      expect(match.price, quote.price);
      expect(match.soldByPiece, units > 0);
      expect(
        match.soldByPiece
            ? match.availablePieceQuantity
            : match.availableQuantity,
        quote.availableQuantity,
      );
    }
  });
}
