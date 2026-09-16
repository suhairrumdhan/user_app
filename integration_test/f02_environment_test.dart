import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const projectId = String.fromEnvironment(
  'ROSHITA_TEST_PROJECT_ID',
  defaultValue: 'demo-roshita-f02',
);
const useFirebaseEmulators = bool.fromEnvironment(
  'ROSHITA_USE_FIREBASE_EMULATORS',
  defaultValue: true,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user integration harness is isolated from production', (
    _,
  ) async {
    expect(projectId.startsWith('demo-'), isTrue);
    expect(projectId, isNot('pharma-apps'));
    expect(useFirebaseEmulators, isTrue);
  });
}
