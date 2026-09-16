import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testProjectId = String.fromEnvironment(
  'ROSHITA_TEST_PROJECT_ID',
  defaultValue: 'demo-roshita-f02',
);

bool get isIsolatedTestProject =>
    testProjectId.startsWith('demo-') && testProjectId != 'pharma-apps';

void main() {
  test('F02 rejects the production Firebase project', () {
    expect(isIsolatedTestProject, isTrue);
  });

  testWidgets('isolated user test harness renders without Firebase startup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Roshita user F02 isolated harness')),
      ),
    );
    expect(find.text('Roshita user F02 isolated harness'), findsOneWidget);
  });
}
