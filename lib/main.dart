import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/controllers/main_navigation_controller.dart';
import 'app/core/services/push_notification_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/services/user_repository.dart';
import 'features/auth/views/welcome_page.dart';
import 'features/pharmacy/views/home_page.dart';
import 'features/profile/controllers/user_controller.dart';
import 'features/reminders/controllers/reminders_controller.dart';
import 'features/reminders/data/local/reminders_local_db.dart';
import 'features/reminders/services/local_notification_service.dart';
import 'features/reminders/services/reminder_permission_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('🔔 Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ التهيئة أولاً
  await RemindersLocalDb.init();
  await LocalNotificationService.init();
  await ReminderPermissionService.requestPermissions();
  await PushNotificationService.instance.init();

  // ✅ ثم إنشاء الـ Controllers
  Get.put(UserRepository(), permanent: true);
  Get.put(UserController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(MainNavigationController(), permanent: true);
  Get.put(RemindersController());  // الآن أصبح آمناً

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Medicine',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const AuthWrapper(),
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
        return const SplashScreen();
      }

      if (authController.user.value != null) {
        return const HomePage();
      }

      return const WelcomeScreen();
    });
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Quran.jpg.jpg',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.white.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    'صيدليتك بين يديك',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Cairo',
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black54,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}