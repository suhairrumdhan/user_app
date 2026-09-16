import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/shared/availability_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14);
  final profile = <String, dynamic>{'status': 'approved', 'isOnline': true};
  final medicine = <String, dynamic>{
    'quantity': 2,
    'pieceQuantity': 0,
    'reservedQuantity': 1,
    'reservedPieceQuantity': 0,
    'unitsPerPackage': 10,
    'sellByPiece': true,
    'expiryDate': Timestamp.fromDate(now.add(const Duration(seconds: 1))),
  };
  test('visible pharmacy remains searchable when new orders stop', () {
    final stopped = {...profile, 'isOnline': false};
    expect(pharmacyVisibleInSearch(stopped), isTrue);
    expect(pharmacyAcceptsNewOrders(stopped), isFalse);
    expect(
      medicineAvailableForSearch({
        ...medicine,
        'pharmacyAcceptingOrders': false,
        'pharmacyVisible': true,
      }, now: now),
      isTrue,
    );
  });
  test(
    'hidden or unapproved pharmacy is not eligible for search or new orders',
    () {
      for (final patch in [
        {'isBlocked': true},
        {'status': 'pending'},
        {'status': null},
        {'isActive': false},
      ]) {
        final current = {...profile, ...patch};
        expect(pharmacyVisibleInSearch(current), isFalse);
        expect(pharmacyAcceptsNewOrders(current), isFalse);
      }
      expect(
        medicineAvailableForSearch({
          ...medicine,
          'pharmacyVisible': false,
        }, now: now),
        isFalse,
      );
    },
  );
  test('new orders require an explicit receiving flag', () {
    expect(pharmacyAcceptsNewOrders({'status': 'approved'}), isFalse);
    expect(pharmacyAcceptsNewOrders(profile), isTrue);
  });
  test(
    'expiry is checked at the exact boundary without another index update',
    () {
      expect(medicineAvailableForSearch(medicine, now: now), isTrue);
      expect(
        medicineAvailableForSearch(
          medicine,
          now: now.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    },
  );
  test('missing expiry differs from malformed supplied expiry', () {
    expect(
      MedicineSaleState.fromMap({'expiryDate': null}, now: now).saleable,
      isTrue,
    );
    for (final raw in ['', 'not-a-date', 12, <String, dynamic>{}]) {
      expect(
        MedicineSaleState.fromMap({'expiryDate': raw}, now: now).invalidExpiry,
        isTrue,
      );
    }
  });
  test('ISO timestamps with explicit offsets and timestamp values agree', () {
    for (final raw in [
      '2026-09-14T03:00:00+03:00',
      '2026-09-14T00:00:00Z',
      '2026-09-14T00:00:00',
      Timestamp.fromDate(now),
      now,
    ]) {
      final state = MedicineSaleState.fromMap({'expiryDate': raw}, now: now);
      expect(state.expiryAt, now);
      expect(state.expired, isTrue);
    }
  });
  test('invalid or fully reserved stock cannot advertise availability', () {
    for (final patch in [
      {'reservedQuantity': 2},
      {'reservedQuantity': 3},
      {'quantity': -1},
      {'quantity': 1.5},
      {'quantity': 9007199254740992},
      {'quantity': 9007199254740991, 'unitsPerPackage': 10},
      {'isActive': false},
      {'invalidStock': true},
      {'isExpired': true},
    ]) {
      expect(
        medicineAvailableForSearch({...medicine, ...patch}, now: now),
        isFalse,
      );
    }
  });
  test(
    'loose pieces require piece sales while packages can remain available',
    () {
      final loose = {
        ...medicine,
        'quantity': 0,
        'reservedQuantity': 0,
        'pieceQuantity': 3,
      };
      expect(medicineAvailableForSearch(loose, now: now), isTrue);
      expect(
        medicineAvailableForSearch({...loose, 'sellByPiece': false}, now: now),
        isFalse,
      );
      expect(
        medicineAvailableForSearch({
          ...medicine,
          'unitsPerPackage': 0,
        }, now: now),
        isTrue,
      );
    },
  );
}
