import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/models/order_status.dart';
import 'package:user_application/features/orders/views/order_details_page.dart';
import 'package:user_application/features/orders/widgets/order_card.dart';

OrderModel sample({bool pending = false, bool accepted = false}) =>
    OrderModel.fromMap('order', {
      'status': 'ready',
      'insurance': {'enabled': !accepted},
      'containsInsurance': !accepted,
      'estimatedTotalPrice': accepted ? 20 : 15,
      'finalCustomerTotalPrice': accepted ? 20 : 15,
      'updatedAt': DateTime.utc(
        2026,
        9,
        26,
        0,
        accepted
            ? 2
            : pending
            ? 1
            : 0,
      ),
      'insuranceRemoval': pending
          ? {
              'status': 'pending',
              'version': 1,
              'quote': {'previousCustomerTotal': 15, 'customerTotal': 20},
            }
          : accepted
          ? {'status': 'accepted', 'version': 1}
          : {},
    });

void main() {
  testWidgets(
    'live order updates replace the old invoice price and show continue or cancel',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final updates = StreamController<OrderModel?>();
      addTearDown(() {
        updates.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailsPage(order: sample(), orderUpdates: updates.stream),
        ),
      );
      updates.add(sample(pending: true));
      await tester.pump();
      await tester.pump();
      final summary = find.ancestor(
        of: find.text('السعر الحالي:').first,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: summary, matching: find.text('20.00 د.ل')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('15.00 د.ل')),
        findsNothing,
      );
      expect(find.text('متابعة'), findsOneWidget);
      expect(find.text('رفض التحول'), findsNothing);
      expect(find.text('إلغاء الطلب'), findsWidgets);
      updates.add(sample(accepted: true));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('السعر الحالي:'),
        findsNothing,
      );
      expect(find.text('متابعة'), findsNothing);
      final finalSummary = find.ancestor(
        of: find.text('السعر النهائي:'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: finalSummary, matching: find.text('20.00 د.ل')),
        findsOneWidget,
      );
      updates.add(sample(pending: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('متابعة'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'order list card shows current uninsured quote rather than old invoice price',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderCard(order: sample(pending: true), onTap: () {}),
          ),
        ),
      );
      expect(find.text('20.00 د.ل'), findsOneWidget);
      expect(find.text('15.00 د.ل'), findsNothing);
      expect(find.text('بدون تأمين'), findsOneWidget);
    },
  );
}


