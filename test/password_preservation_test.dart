import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_application/features/auth/services/auth_services.dart';

class RecordingAuth implements FirebaseAuth {
  String? password;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.password = password;
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.password = password;
    throw FirebaseAuthException(code: 'invalid-email');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'registration and subsequent sign-in preserve the exact reset-compatible password',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final auth = RecordingAuth();
      final service = AuthService(auth: auth);
      const password = ' Aa123456! ';
      await service.registerWithEmail(
        context: context,
        email: 'u@example.test',
        password: password,
        confirmPassword: password,
        name: 'User',
        phoneNumber: '0912345678',
        setLoading: (_) {},
      );
      expect(auth.password, password);
      await service.loginWithEmail(
        context: context,
        email: 'u@example.test',
        password: password,
        setLoading: (_) {},
      );
      expect(auth.password, password);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
