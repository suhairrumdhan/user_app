import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/models/order_status.dart';

void main() {
  test(
    'pending coverage decision retains insured price and its separate quote',
    () {
      final order = OrderModel.fromMap('order', {
        'status': 'confirmedReserved',
        'insurance': {'enabled': true},
        'containsInsurance': true,
        'estimatedTotalPrice': 15,
        'insuranceRemoval': {
          'status': 'pending',
          'version': 2,
          'quote': {'previousCustomerTotal': 15, 'customerTotal': 20},
        },
      });
      expect(order.insurance.enabled, isTrue);
      expect(order.estimatedTotalPrice, 15);
      expect(order.currentCustomerTotalPrice, 20);
      expect(order.insuranceRemoval['quote']['customerTotal'], 20);
      expect(order.copyWith().insuranceRemoval, order.insuranceRemoval);
      expect(order.toMap()['insuranceRemoval'], order.insuranceRemoval);
    },
  );

  test(
    'pending uninsured quote overrides an older invoice total, including zero',
    () {
      final order = OrderModel.fromMap('order', {
        'status': 'ready',
        'finalCustomerTotalPrice': 15,
        'estimatedTotalPrice': 15,
        'insuranceRemoval': {
          'status': 'pending',
          'quote': {'customerTotal': 20},
        },
      });
      expect(order.currentCustomerTotalPrice, 20);
      expect(
        order
            .copyWith(
              insuranceRemoval: {
                'status': 'pending',
                'quote': {'customerTotal': 0},
              },
            )
            .currentCustomerTotalPrice,
        0,
      );
      expect(
        order
            .copyWith(insuranceRemoval: {'status': 'pending'})
            .currentCustomerTotalPrice,
        isNull,
      );
    },
  );

  test('accepted invoiced removal reads final amount without insurance', () {
    final order = OrderModel.fromMap('order', {
      'status': 'ready',
      'insurance': {'enabled': false},
      'containsInsurance': false,
      'estimatedTotalPrice': 20,
      'finalCustomerTotalPrice': 20,
      'finalInsuranceShare': 0,
      'insuranceRemoval': {'status': 'accepted', 'version': 2},
    });
    expect(order.insurance.enabled, isFalse);
    expect(order.containsInsurance, isFalse);
    expect(order.finalCustomerTotalPrice, 20);
    expect(order.finalInsuranceShare, 0);
    expect(order.insuranceRemoval['status'], 'accepted');
  });
}
