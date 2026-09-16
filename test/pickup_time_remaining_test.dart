import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/models/pickup_time_remaining.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 12);

  test('formats remaining time and rounds up a partial minute', () {
    expect(
      PickupTimeRemaining.format(
        deadline: now.add(const Duration(days: 1, hours: 2, minutes: 3)),
        now: now,
      ),
      'الوقت المتبقي: 1 يوم و2 ساعة و3 دقيقة',
    );
    expect(
      PickupTimeRemaining.format(
        deadline: now.add(const Duration(microseconds: 1)),
        now: now,
      ),
      'الوقت المتبقي: 1 دقيقة',
    );
    expect(PickupTimeRemaining.format(deadline: null, now: now), isNull);
  });

  test('deadline crossing warns without changing ready status', () {
    final deadline = now.add(const Duration(minutes: 5));
    expect(
      PickupTimeRemaining.isOverdue(
        isReady: true,
        serverMarkedOverdue: false,
        deadline: deadline,
        now: deadline.subtract(const Duration(microseconds: 1)),
      ),
      isFalse,
    );
    expect(
      PickupTimeRemaining.isOverdue(
        isReady: true,
        serverMarkedOverdue: false,
        deadline: deadline,
        now: deadline,
      ),
      isTrue,
    );
    expect(
      PickupTimeRemaining.format(deadline: deadline, now: deadline),
      'انتهت مهلة الاستلام',
    );
    expect(
      PickupTimeRemaining.isOverdue(
        isReady: false,
        serverMarkedOverdue: true,
        deadline: deadline,
        now: deadline,
      ),
      isFalse,
    );
  });
}
