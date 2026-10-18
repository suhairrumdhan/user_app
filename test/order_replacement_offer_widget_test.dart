import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/models/order_status.dart';
import 'package:user_application/features/orders/views/order_details_page.dart';

OrderModel replacement(int version, String name, double amount) =>
    OrderModel.fromMap('order', {
      'status': 'partialOfferPending',
      'offerVersion': version,
      'invoiceId': 'old-invoice',
      'updatedAt': DateTime.utc(2026, 9, 26, version),
      'finalCustomerTotalPrice': 10,
      'medicines': [
        {'medicineId': 'original', 'medicineName': 'Original', 'quantity': 2},
      ],
      'partialOffer': {
        'version': version,
        'kind': 'replacement',
        'reason': 'Agreed in chat',
        'items': [
          {
            'medicineId': 'alternative',
            'medicineName': name,
            'quantity': 2,
            'replacesMedicineId': 'original',
            'originalMedicineName': 'Original',
            'originalQuantity': 2,
            'isReplacement': true,
          },
        ],
        'quote': {
          'customerTotal': amount,
          'grossTotal': amount,
          'insuranceShare': 0,
          'items': [
            {
              'medicineId': 'alternative',
              'quantity': 2,
              'unitPrice': amount / 2,
              'lineTotal': amount,
            },
          ],
        },
      },
    });

void main() {
  testWidgets('full offer shows price approval actions and current total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final map = replacement(1, 'Original', 30).toMap();
    map['invoiceId'] = null;
    map['partialOffer']['kind'] = 'full';
    map['partialOffer']['items'][0]['isReplacement'] = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsPage(
          order: OrderModel.fromMap('order', map),
          orderUpdates: const Stream.empty(),
        ),
      ),
    );
    expect(find.text('عرض سعر الطلب'), findsOneWidget);
    expect(find.text('قبول العرض'), findsOneWidget);
    expect(find.text('رفض العرض وإلغاء الطلب'), findsOneWidget);
    expect(find.textContaining('بدلاً من'), findsNothing);
    final summary = find.ancestor(
      of: find.text('السعر الإجمالي:').first,
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: summary, matching: find.text('30.00 د.ل')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'replacement displays lineage and live price instead of old invoice',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final updates = StreamController<OrderModel?>();
      addTearDown(() {
        updates.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailsPage(
            order: replacement(1, 'Alternative A', 30),
            orderUpdates: updates.stream,
          ),
        ),
      );
      expect(find.text('عرض تبديل الأصناف'), findsOneWidget);
      expect(find.text('Alternative A'), findsOneWidget);
      expect(find.textContaining('بدلاً من Original'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsNWidgets(2));
      expect(find.text('رفض التبديل'), findsOneWidget);
      expect(find.text('إلغاء الطلب'), findsNothing);
      final summary = find.ancestor(
        of: find.text('السعر الإجمالي:').first,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: summary, matching: find.text('30.00 د.ل')),
        findsOneWidget,
      );
      updates.add(replacement(2, 'Alternative B', 40));
      await tester.pump();
      await tester.pump();
      expect(find.text('Alternative A'), findsNothing);
      expect(find.text('Alternative B'), findsOneWidget);
      expect(
        find.descendant(of: summary, matching: find.text('40.00 د.ل')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
