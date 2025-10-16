import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/auth/user_repository.dart' show UserRepository;
import '../controllers/user_controller.dart' show UserController;
import '../screens/health_info.dart';
import '../screens/home_page.dart';
import '../screens/welcome_page.dart';
import 'models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------- تسجيل مستخدم جديد ----------
  // ---------- تسجيل مستخدم جديد ----------
  Future<void> registerWithEmail({
    required BuildContext context,
    required String email,
    required String password,
    required String confirmPassword,
    required String name,
    required String phoneNumber,
    required Function(bool) setLoading,
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
      print('🔄 جاري إنشاء مستخدم جديد في Authentication...');

      // 1. إنشاء المستخدم في Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      print('✅ تم إنشاء المستخدم في Authentication: $uid');

      // 2. تحديث الاسم في Auth
      await credential.user!.updateDisplayName(name.trim());

      // 3. إنشاء UserModel
      final newUser = UserModel(
        id: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phoneNumber.trim(),
        createdAt: DateTime.now(),
        healthInfoCompleted: false,
      );

      print('🔄 جاري حفظ المستخدم في Firestore...');

      // 4. حفظ المستخدم في Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set(newUser.toJson());

      print('✅ تم حفظ المستخدم في Firestore بنجاح');

      // 5. تحميل بيانات المستخدم في الـ Controller
      final userController = Get.find<UserController>();
      await userController.loadUser(uid);

      print('✅ تم تحميل بيانات المستخدم في الـ Controller');

      // 6. الانتقال إلى شاشة المعلومات الصحية
      if (!context.mounted) return;
      Get.offAll(() => const HealthInfoScreen());

    } on FirebaseAuthException catch (e) {
      String message = "حدث خطأ";
      if (e.code == 'email-already-in-use') {
        message = "البريد الإلكتروني مستخدم بالفعل";
      } else if (e.code == 'weak-password') {
        message = "كلمة المرور ضعيفة (6 أحرف على الأقل)";
      } else if (e.code == 'invalid-email') {
        message = "بريد إلكتروني غير صالح";
      }
      print('❌ خطأ في التسجيل: $message');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      print('❌ خطأ غير متوقع في التسجيل: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ غير متوقع: ${e.toString()}")),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // ---------- تسجيل الدخول بالبريد وكلمة المرور ----------
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
        final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (!context.mounted) return;

        if (doc.exists && doc.data()?['healthInfoCompleted'] == true) {
          Get.offAll(() => const HomePage());
        } else {
          Get.offAll(() => const HealthInfoScreen());
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم تسجيل الدخول بنجاح")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "حدث خطأ";
      if (e.code == 'user-not-found') {
        message = "البريد الإلكتروني غير مسجل";
      } else if (e.code == 'wrong-password') {
        message = "كلمة المرور غير صحيحة";
      } else if (e.code == 'invalid-email') {
        message = "البريد الإلكتروني غير صالح";
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ غير متوقع: ${e.toString()}")),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // ---------- تسجيل الدخول بجوجل ----------
  Future<void> signInWithGoogle(
      BuildContext context,
      Function(bool) setLoading,
      ) async {
    setLoading(true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName,
          'photoUrl': user.photoURL,
          'phone': user.phoneNumber,
          'createdAt': Timestamp.now(),
          'provider': 'google.com',
        }, SetOptions(merge: true));
      }

      if (doc.exists && doc.data()?['healthInfoCompleted'] == true) {
        Get.offAll(() => const HomePage());
      } else {
        Get.offAll(() => const HealthInfoScreen());
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google sign-in failed: ${e.toString()}")),
        );
      }
      debugPrint('Google sign-in error: $e');
    } finally {
      setLoading(false);
    }
  }

  // ---------- تسجيل الخروج ----------
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      Get.offAll(() => const WelcomeScreen());
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
  }
}
