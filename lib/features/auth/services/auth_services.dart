import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../app/core/services/push_notification_service.dart';
import '../../profile/controllers/user_controller.dart' show UserController;
import '../../health_records/views/health_info.dart';
import '../../pharmacy/views/home_page.dart';
import '../views/welcome_page.dart';
import 'email_action_service.dart';
import 'user_repository.dart';
import '../views/email_verification_page.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, EmailActionService? emailActions})
    : _auth = auth ?? FirebaseAuth.instance,
      _emailActions = emailActions ?? EmailActionService(auth: auth);
  final FirebaseAuth _auth;
  final EmailActionService _emailActions;

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
    var accountCreated = false;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      accountCreated = true;
      await UserRepository.instance.ensureUserProfile(
        credential.user!,
        name: name.trim(),
        phone: phoneNumber.trim(),
      );
      try {
        await credential.user!.updateDisplayName(name.trim());
      } catch (error) {
        debugPrint('Display name sync deferred: $error');
      }
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
        message = "البريد مسجل بالفعل. سجل الدخول أو استخدم بريدًا آخر.";
      } else if (e.code == 'weak-password') {
        message = "كلمة المرور ضعيفة. استخدم حروفًا وأرقامًا ورموزًا.";
      } else if (e.code == 'invalid-email') {
        message = "أدخل بريدًا إلكترونيًا صحيحًا.";
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
            content: Text(
              accountCreated
                  ? 'تم إنشاء الحساب. سجل الدخول لإكمال بياناتك.'
                  : 'تعذر إنشاء الحساب. أعد المحاولة.',
            ),
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
      onError?.call("أدخل البريد الإلكتروني.");
      return;
    }

    if (password.isEmpty) {
      onError?.call("أدخل كلمة المرور.");
      return;
    }

    setLoading(true);

    try {
      print('📧 محاولة تسجيل الدخول للبريد: $email');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('تم تسجيل الدخول.');

      final user = credential.user;
      if (user != null) {
        if (EmailActionService.requiresEmailVerification(user)) {
          if (!context.mounted) return;
          Get.offAll(() => const EmailVerificationPage());
          return;
        }

        print('📁 جلب بيانات المستخدم من Firestore...');
        final profile = await UserRepository.instance.ensureUserProfile(user);
        await Get.find<UserController>().loadUser(user.uid);

        if (!context.mounted) return;

        if (profile.healthInfoCompleted) {
          print('🏠 التوجه إلى HomePage');
          Get.offAll(() => const HomePage());
        } else {
          print('🏥 التوجه إلى HealthInfoScreen');
          Get.offAll(() => const HealthInfoScreen());
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم تسجيل الدخول."),
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
          message = "البريد الإلكتروني أو كلمة المرور غير صحيحة.";
          break;
        case 'invalid-email':
          message = "أدخل بريدًا إلكترونيًا صحيحًا.";
          break;
        case 'user-disabled':
          message = "الحساب معطل. تواصل مع الدعم.";
          break;
        case 'too-many-requests':
          message = "محاولات كثيرة. حاول لاحقًا.";
          break;
        case 'network-request-failed':
          message = "تحقق من اتصال الإنترنت وأعد المحاولة.";
          break;
        default:
          message = "تعذر تسجيل الدخول. حاول مرة أخرى.";
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

      String message = "تعذر تسجيل الدخول. أعد المحاولة.";

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
              content: Text("تعذر تسجيل الدخول. أعد المحاولة."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('تم تسجيل الدخول.: ${user.uid}');

      print('📁 التحقق من وجود المستخدم في Firestore...');
      final profile = await UserRepository.instance.ensureUserProfile(user);
      await Get.find<UserController>().loadUser(user.uid);
      final healthInfoCompleted = profile.healthInfoCompleted;
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
            content: Text("تم تسجيل الدخول."),
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
          message = "البريد مرتبط بحساب آخر. استخدم طريقة الدخول السابقة.";
          break;
        case 'invalid-credential':
          message = "تعذر التحقق من بيانات الدخول. أعد المحاولة.";
          break;
        case 'operation-not-allowed':
          message = "الدخول عبر Google غير متاح حاليًا. تواصل مع الدعم.";
          break;
        default:
          message = "تعذر تسجيل الدخول. حاول مرة أخرى.";
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

      String message = "تعذر إتمام العملية. أعد المحاولة.";

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
