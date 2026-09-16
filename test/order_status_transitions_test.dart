import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/models/order_status.dart';

void main() {
  test('only the user can decide the partial offer', () {
    expect(
      OrderStatus.partialOfferPending.canTransitionTo(
        OrderStatus.confirmedReserved,
        actorType: 'user',
      ),
      isTrue,
    );
    expect(
      OrderStatus.partialOfferPending.canTransitionTo(
        OrderStatus.confirmedReserved,
        actorType: 'pharmacy',
      ),
      isFalse,
    );
    expect(
      OrderStatus.partialOfferPending.canTransitionTo(
        OrderStatus.cancelled,
        actorType: 'pharmacy',
      ),
      isFalse,
    );
  });
  test('pharmacy can revise a waiting or confirmed uninvoiced offer', () {
    for (final status in [
      OrderStatus.partialOfferPending,
      OrderStatus.confirmedReserved,
    ]) {
      expect(
        status.canTransitionTo(
          OrderStatus.partialOfferPending,
          actorType: 'pharmacy',
        ),
        isTrue,
      );
      expect(
        status.canTransitionTo(
          OrderStatus.partialOfferPending,
          actorType: 'user',
        ),
        isFalse,
      );
    }
    expect(
      OrderStatus.preparing.canTransitionTo(
        OrderStatus.partialOfferPending,
        actorType: 'pharmacy',
      ),
      isFalse,
    );
  });
  test('insurance decision and unknown actors match the source contract', () {
    for (final actor in ['user', 'system']) {
      expect(
        OrderStatus.received.canTransitionTo(
          OrderStatus.underReview,
          actorType: actor,
        ),
        isTrue,
      );
    }
    for (final actor in ['pharmacy', 'unknown', '']) {
      expect(
        OrderStatus.received.canTransitionTo(
          OrderStatus.underReview,
          actorType: actor,
        ),
        isFalse,
      );
    }
    expect(
      OrderStatus.underReview.canTransitionTo(
        OrderStatus.confirmedReserved,
        actorType: 'unknown',
      ),
      isFalse,
    );
  });
}
