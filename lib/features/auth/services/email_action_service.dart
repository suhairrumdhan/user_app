import 'package:firebase_auth/firebase_auth.dart';

class EmailActionService {
  EmailActionService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const String _continueUrl = 'https://pharma-apps.firebaseapp.com/';
  static const String _androidPackageName = 'com.example.user_application';

  ActionCodeSettings get _mobileActionCodeSettings => ActionCodeSettings(
    url: _continueUrl,
    handleCodeInApp: true,
    androidPackageName: _androidPackageName,
    androidInstallApp: false,
  );

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('لا يوجد مستخدم مسجل حالياً');
    }

    await _auth.setLanguageCode('ar');
    await user.sendEmailVerification(_mobileActionCodeSettings);
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified == true) {
      await refreshedUser?.getIdToken(true);
      return true;
    }

    return false;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.setLanguageCode('ar');
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: _mobileActionCodeSettings,
    );
  }

  static bool requiresEmailVerification(User user) {
    return usesEmailPassword(user) && !user.emailVerified;
  }

  static bool usesEmailPassword(User? user) {
    return user?.providerData.any(
          (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
        ) ??
        false;
  }
}
