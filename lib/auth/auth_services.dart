import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/screens/health_info.dart';
import 'package:user_application/screens/home_page.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> registerWithEmail({
    required BuildContext context,
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
    required String phoneNumber,
    required Function(bool) setLoading,
    String? gender,
    int? age,
  }) async {
    if (password != confirmPassword) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("كلمة المرور وتأكيدها غير متطابقين")),
      );
      return;
    }

    setLoading(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user!.uid;

      await credential.user!.updateDisplayName(name.trim());

      // حفظ البيانات في Firestore (مع إمكانية الدمج لاحقًا)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email.trim(),
        'name': name.trim(),
        'phone': phoneNumber.trim(),
        'gender': gender,
        'age': age,
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HealthInfoScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      String message = "حدث خطأ";
      if (e.code == 'email-already-in-use') {
        message = "البريد الإلكتروني مستخدم بالفعل";
      } else if (e.code == 'weak-password') {
        message = "كلمة المرور ضعيفة (يجب أن تكون 6 أحرف على الأقل)";
      } else if (e.code == 'invalid-email') {
        message = "بريد إلكتروني غير صالح";
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ غير متوقع: ${e.toString()}")),
      );
    } finally {
      setLoading(false);
    }
  }

  Future<void> signInWithGoogle(
    BuildContext context,
    Function(bool) setLoading,
  ) async {
    setLoading(true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setLoading(false);
        return; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;
      if (user != null) {
        // Check if health info exists
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (!context.mounted) return;

        if (doc.exists && doc.data()?['healthInfoCompleted'] == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          // Create user document if not exists
          if (!doc.exists) {
            await FirebaseFirestore.instance
                .collection("users")
                .doc(user.uid)
                .set({
                  'uid': user.uid,
                  'email': user.email,
                  'name': user.displayName,
                  'photoUrl': user.photoURL,
                  'phone': user.phoneNumber,
                  'createdAt': Timestamp.now(),
                  'provider': 'google.com',
                }, SetOptions(merge: true));
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HealthInfoScreen()),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google sign-in failed: ${e.toString()}")),
      );
      debugPrint('Google sign-in error: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> loginWithEmail({
    required BuildContext context,
    required String email,
    required String password,
    required Function(bool) setLoading,
  }) async {
    setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = _auth.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (!context.mounted) return;

        if (doc.exists && doc.data()?['healthInfoCompleted'] == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HealthInfoScreen()),
          );
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("تم تسجيل الدخول بنجاح")));
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      String message = "حدث خطأ";
      if (e.code == 'user-not-found') {
        message = "البريد الإلكتروني غير مسجل";
      } else if (e.code == 'wrong-password') {
        message = "كلمة المرور غير صحيحة";
      } else if (e.code == 'invalid-email') {
        message = "البريد الإلكتروني غير صالح";
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ غير متوقع: ${e.toString()}")),
      );
    } finally {
      setLoading(false);
    }
  }
}
