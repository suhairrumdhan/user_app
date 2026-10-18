import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/prescription/services/prescription_text_layout.dart';
import 'package:user_application/features/prescription/services/drug_parser.dart';
import 'package:user_application/features/prescription/widgets/uncertain_prescription_text_card.dart';
import 'package:flutter/material.dart';

PrescriptionTextFragment word(
  String text,
  double x,
  double y,
  double width, {
  double height = 16,
}) => PrescriptionTextFragment(text, Rect.fromLTWH(x, y, width, height));

void main() {
  test('rebuilds mixed-style words by coordinates, not PDF stream order', () {
    final words = [
      word('at Bed time', 440, 304, 75),
      word('x30days', 380, 304, 53),
      word('1x1', 357, 304, 23),
      word('then', 323, 304, 30),
      word('Omnic', 128, 304, 42),
      word('0.4', 174, 304, 20),
      word('mg', 198, 304, 20),
      word('cap', 222, 304, 23),
      word('2x1x5 days', 249, 304, 70),
      word('الاصلي', 90, 304, 38),
      word('Ciprobay tab 500mg 1x2x10days', 128, 333, 211),
    ];
    expect(
      PrescriptionTextLayout.pageText(words),
      'Omnic 0.4 mg cap 2x1x5 days then 1x1x30days at Bed time\nCiprobay tab 500mg 1x2x10days',
    );
    expect(
      PrescriptionTextLayout.pageText(words.reversed),
      PrescriptionTextLayout.pageText(words),
    );
  });

  test(
    'layout scales with font/page size and tolerates small baseline shifts',
    () {
      for (final scale in [.5, 1.0, 3.0]) {
        final fragments = [
          word('Omnic', 40 * scale, 60 * scale, 40 * scale, height: 16 * scale),
          word('0.4mg', 84 * scale, 61 * scale, 44 * scale, height: 16 * scale),
          word(
            'Ciprobay',
            40 * scale,
            87 * scale,
            80 * scale,
            height: 16 * scale,
          ),
        ];
        expect(
          PrescriptionTextLayout.pageText(fragments),
          'Omnic 0.4mg\nCiprobay',
        );
      }
    },
  );

  test(
    'columns and large vertical gaps cannot look like wrapped strengths',
    () {
      expect(
        PrescriptionTextLayout.pageText([
          word('Name', 10, 10, 40),
          word('20mg', 350, 10, 40),
          word('Trido tab', 10, 100, 70),
        ]),
        'Name\n\n20mg\n\nTrido tab',
      );
    },
  );

  test(
    'small inline fragments join but adjacent medication rows stay separate',
    () {
      expect(
        PrescriptionTextLayout.pageText([
          word('0.', 70, 10, 10),
          word('4', 80, 10, 8),
          word('Omnic', 20, 10, 46),
          word('mg cap', 92, 10, 50),
          word('Ciprobay', 20, 29, 90),
        ]),
        'Omnic 0.4 mg cap\nCiprobay',
      );
    },
  );

  test('duplicate layers deduplicate at same position, not other rows', () {
    expect(
      PrescriptionTextLayout.pageText([
        word('Test', 10, 10, 40),
        word('Test', 10, 10, 40),
        word('Test', 10, 30, 40),
      ]),
      'Test\nTest',
    );
  });

  test(
    'unknown response text is separate from medicines and supports old API',
    () {
      final response = <String, dynamic>{
        'items': <dynamic>[],
        'uncertainText': [
          {'text': 'UnknownBrand'},
          {'text': ''},
        ],
      };
      expect(DrugParser.parseReviewResponse(response), isEmpty);
      expect(DrugParser.parseUncertainText(response), ['UnknownBrand']);
      expect(DrugParser.parseUncertainText({}), isEmpty);
    },
  );

  testWidgets(
    'uncertain text requires explicit review and is initially collapsed',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UncertainPrescriptionTextCard(
              texts: const ['UnknownBrand'],
              onReview: (text) => selected = text,
            ),
          ),
        ),
      );
      expect(find.text('UnknownBrand'), findsNothing);
      expect(selected, isNull);
      await tester.tap(find.text('نصوص لم تُصنّف كأدوية'));
      await tester.pumpAndSettle();
      expect(find.text('UnknownBrand'), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.text('مراجعة الاسم'));
      expect(selected, 'UnknownBrand');
    },
  );
}
