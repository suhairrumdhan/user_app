import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/orders/widgets/offer_medicine_image.dart';

void main() {
  testWidgets('missing medicine image is an icon without a caption', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfferMedicineImage())),
    );
    expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
  });
}
