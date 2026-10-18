import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/auth/services/user_repository.dart';
import 'helpers/memory_firestore.dart';

class Account implements User {
  @override
  String get uid => 'user';
  @override
  String? get displayName => 'User';
  @override
  String? get email => 'user@example.test';
  @override
  String? get phoneNumber => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed profile save can be resumed without creating another account or overwriting health data',
    () async {
      final db = MemoryFirestore();
      final repository = UserRepository(firestore: db);
      db.rejectCommit = true;
      await expectLater(
        repository.ensureUserProfile(Account()),
        throwsStateError,
      );
      expect(db.documents, isEmpty);
      db.rejectCommit = false;
      final profiles = await Future.wait([
        repository.ensureUserProfile(
          Account(),
          name: 'Registered name',
          phone: '0912345678',
        ),
        repository.ensureUserProfile(Account()),
      ]);
      expect(profiles.every((p) => p.id == 'user'), isTrue);
      expect(db.documents.length, 1);
      db.seed('users/user', {
        ...db.documents['users/user']!,
        'healthInfoCompleted': true,
        'allergies': ['allergy'],
      });
      final recovered = await repository.ensureUserProfile(Account());
      expect(recovered.healthInfoCompleted, isTrue);
      expect(recovered.allergies, ['allergy']);
      expect(recovered.name, 'Registered name');
    },
  );
}
