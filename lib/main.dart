import 'features/search/views/search_ui_colors.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/controllers/main_navigation_controller.dart';
import 'app/core/services/push_notification_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/email_action_link_controller.dart';
import 'features/auth/services/email_action_service.dart';
import 'features/auth/views/email_verification_page.dart';
import 'features/auth/services/user_repository.dart';
import 'features/auth/views/welcome_page.dart';
import 'features/family/controllers/family_controller.dart';
import 'features/insurance/controllers/insurance_controller.dart';
import 'features/pharmacy/views/home_page.dart';
import 'features/profile/controllers/user_controller.dart';
import 'features/reminders/controllers/reminders_controller.dart';
import 'features/reminders/data/local/reminders_local_db.dart';
import 'features/reminders/services/local_notification_service.dart';
import 'features/reminders/services/reminder_permission_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('🔔 Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ التهيئة أولاً
  await RemindersLocalDb.init();
  await LocalNotificationService.init();
  await ReminderPermissionService.requestPermissions();

  // ✅ ثم إنشاء الـ Controllers
  Get.put(UserRepository(), permanent: true);
  Get.put(UserController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(FamilyController(), permanent: true);
  Get.put(InsuranceController(), permanent: true);
  Get.put(EmailActionLinkController(), permanent: true);
  Get.put(MainNavigationController(), permanent: true);
  Get.put(RemindersController()); // الآن أصبح آمناً

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());

  // FCM may wait for a token or a Firestore write when the phone is offline.
  // It must not delay the first screen or access to locally cached data.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(PushNotificationService.instance.init());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Medicine',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: SearchUiColors.primary)
            .copyWith(
              primary: SearchUiColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              surfaceTint: Colors.transparent,
            ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const AuthWrapper(), // ✅ رجعناها مثل ما كانت
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Obx(() {
      if (authController.isLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ); // ✅ مؤشر تحميل بسيط بدون سبلاش
      }

      if (authController.user.value != null) {
        if (EmailActionService.requiresEmailVerification(
          authController.user.value!,
        )) {
          return const EmailVerificationPage();
        }
        return const HomePage();
      }

      return const WelcomeScreen();
    });
  }
}
