import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/core/services/push_notification_service.dart';
import '../../profile/controllers/user_controller.dart' show UserController;
import '../../health_records/views/health_info.dart';
import '../../pharmacy/views/home_page.dart';
import '../views/welcome_page.dart';
import '../../profile/models/user_model.dart';
import 'email_action_service.dart';
import '../views/email_verification_page.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmailActionService _emailActions = EmailActionService();

  // ---------- تسجيل مستخدم جديد ----------
  // ---------- تسجيل مستخدم جديد ----------
  // في auth_services.dart - تحسين رسائل الخطأ
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
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name.trim());

      final newUser = UserModel(
        id: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phoneNumber.trim(),
        createdAt: DateTime.now(),
        healthInfoCompleted: false,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(newUser.toJson());
      final userController = Get.find<UserController>();
      await userController.loadUser(uid);

      var verificationEmailSent = false;
      try {
        await _emailActions.sendVerificationEmail();
        verificationEmailSent = true;
      } on FirebaseAuthException catch (e) {
        debugPrint('تعذر إرسال رسالة تأكيد البريد: ${e.code}');
      }

      if (!context.mounted) return;
      Get.offAll(() => EmailVerificationPage(emailSent: verificationEmailSent));
    } on FirebaseAuthException catch (e) {
      String message = "حدث خطأ";
      print('🔥 FirebaseAuthException code: ${e.code}'); // للتتبع

      if (e.code == 'email-already-in-use') {
        message =
            "❌ هذا البريد الإلكتروني مسجل بالفعل. يرجى استخدام بريد آخر أو تسجيل الدخول";
      } else if (e.code == 'weak-password') {
        message =
            "❌ كلمة المرور ضعيفة جداً. يرجى استخدام كلمة مرور أقوى (أكثر من 6 أحرف، تحتوي على أرقام ورموز وحروف)";
      } else if (e.code == 'invalid-email') {
        message = "❌ البريد الإلكتروني غير صالح";
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ خطأ غير متوقع في التسجيل: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("حدث خطأ غير متوقع: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // تحديث دالة loginWithEmail في AuthService
  Future<void> loginWithEmail({
    required BuildContext context,
    required String email,
    required String password,
    required Function(bool) setLoading,
    Function(String)? onError,
  }) async {
    // تحقق أولي قبل الإرسال
    if (email.isEmpty) {
      onError?.call("❌ يرجى إدخال البريد الإلكتروني");
      return;
    }

    if (password.isEmpty) {
      onError?.call("❌ يرجى إدخال كلمة المرور");
      return;
    }

    setLoading(true);

    try {
      print('📧 محاولة تسجيل الدخول للبريد: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      print('✅ تم تسجيل الدخول بنجاح');

      final user = credential.user;
      if (user != null) {
        if (EmailActionService.requiresEmailVerification(user)) {
          if (!context.mounted) return;
          Get.offAll(() => const EmailVerificationPage());
          return;
        }

        print('📁 جلب بيانات المستخدم من Firestore...');
        final doc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (!context.mounted) return;

        if (doc.exists && doc.data()?['healthInfoCompleted'] == true) {
          print('🏠 التوجه إلى HomePage');
          Get.offAll(() => const HomePage());
        } else {
          print('🏥 التوجه إلى HealthInfoScreen');
          Get.offAll(() => const HealthInfoScreen());
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ تم تسجيل الدخول بنجاح"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException: ${e.code} - ${e.message}');

      String message = "";

      // معالجة جميع حالات الخطأ الممكنة
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message =
              " البريد الإلكتروني أو كلمة المرور غير صحيحة\n يرجى التأكد من بيانات الدخول";
          break;
        case 'invalid-email':
          message =
              " صيغة البريد الإلكتروني غير صحيحة\n مثال: name@example.com";
          break;
        case 'user-disabled':
          message = " هذا الحساب معطل\n يرجى الاتصال بالدعم الفني";
          break;
        case 'too-many-requests':
          message = "⚠️ تم تجاوز عدد المحاولات المسموحة\n يرجى المحاولة لاحقاً";
          break;
        case 'network-request-failed':
          message =
              "⚠️ مشكلة في الاتصال بالإنترنت\n يرجى التحقق من اتصالك بالإنترنت";
          break;
        default:
          message = " خطأ: ${e.message}\n يرجى المحاولة مرة أخرى";
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      onError?.call(message);
    } catch (e) {
      print('========================================');
      print(' خطأ غير متوقع:');
      print('نوع الخطأ: ${e.runtimeType}');
      print('الرسالة: $e');
      print('========================================');

      String message = " حدث خطأ: ${e.toString()}\n يرجى المحاولة مرة أخرى";

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      onError?.call(message);
    } finally {
      setLoading(false);
    }
  }

  // ---------- تسجيل الدخول بجوجل ----------
  // ---------- تسجيل الدخول بجوجل (المصلحة) ----------
  Future<void> signInWithGoogle(
    BuildContext context,
    Function(bool) setLoading,
  ) async {
    setLoading(true);

    try {
      print('🌐 بدء عملية تسجيل الدخول بجوجل...');

      // ✅ أضف Web Client ID هنا
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId:
            '657034913156-sg2ln6ge94ckda9elbsu3qfv1ltejlct.apps.googleusercontent.com',
      );

      // تسجيل الخروج من أي حساب سابق لضمان ظهور شاشة الاختيار
      await googleSignIn.signOut();

      print('📱 جاري اختيار حساب Google...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ المستخدم ألغى عملية تسجيل الدخول');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم إلغاء تسجيل الدخول بجوجل"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      print('✅ تم اختيار الحساب: ${googleUser.email}');
      print('🔐 جاري الحصول على معلومات المصادقة...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔥 جاري تسجيل الدخول إلى Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user == null) {
        print('❌ فشل تسجيل الدخول إلى Firebase');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("فشل تسجيل الدخول، يرجى المحاولة مرة أخرى"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('✅ تم تسجيل الدخول بنجاح: ${user.uid}');

      print('📁 التحقق من وجود المستخدم في Firestore...');
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('📝 إنشاء مستخدم جديد في Firestore...');
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          'id': user.uid,
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'مستخدم Google',
          'photoUrl': user.photoURL ?? '',
          'phone': user.phoneNumber ?? '',
          'createdAt': Timestamp.now(),
          'provider': 'google.com',
          'healthInfoCompleted': false,
        });
        print('✅ تم إنشاء مستخدم جديد في Firestore');
      } else {
        print('✅ المستخدم موجود مسبقاً في Firestore');
      }

      final healthInfoCompleted = doc.data()?['healthInfoCompleted'] ?? false;
      print('📊 healthInfoCompleted: $healthInfoCompleted');

      if (!context.mounted) return;

      if (healthInfoCompleted) {
        print('🏠 التوجه إلى HomePage');
        Get.offAll(() => const HomePage());
      } else {
        print('🏥 التوجه إلى HealthInfoScreen');
        Get.offAll(() => const HealthInfoScreen());
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم تسجيل الدخول بنجاح"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException في Google Sign-In: ${e.code}');
      print('📝 تفاصيل: ${e.message}');

      String message = "";
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message =
              "هذا البريد مرتبط بحساب آخر. يرجى تسجيل الدخول باستخدام الطريقة الأخرى.";
          break;
        case 'invalid-credential':
          message = "بيانات الاعتماد غير صالحة. يرجى المحاولة مرة أخرى.";
          break;
        case 'operation-not-allowed':
          message = "تسجيل الدخول بجوجل غير مفعل. يرجى مراجعة الدعم الفني.";
          break;
        default:
          message = "خطأ في تسجيل الدخول: ${e.message}";
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ خطأ غير متوقع في Google Sign-In:');
      print('نوع الخطأ: ${e.runtimeType}');
      print('الرسالة: $e');
      print('Stack trace: $stackTrace');
      print('========================================');

      String message = "حدث خطأ غير متوقع: ${e.toString()}";

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // ---------- تسجيل الخروج ----------
  Future<void> signOut() async {
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
      await _auth.signOut();
      Get.offAll(() => const WelcomeScreen());
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
  }
}
