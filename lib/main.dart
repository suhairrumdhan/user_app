import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/screens/home_page.dart';
import 'package:user_application/screens/welcome_page.dart';
import 'package:user_application/screens/health_info.dart';
import 'controllers/AuthController.dart';
import 'firebase_options.dart';
import 'package:user_application/auth/user_repository.dart';
import 'package:user_application/controllers/user_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تهيئة الـ Controllers
  Get.put(UserRepository());
  Get.put(UserController());
  Get.put(AuthController()); // ← إضافة الـ Auth Controller

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'User App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      // استخدام الـ AuthController لتحديد الشاشة المناسبة
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Obx(() {
      if (authController.isLoading.value) {
        return const SplashScreen(); // شاشة تحميل
      }

      if (authController.user.value != null) {
        // المستخدم مسجل دخول - انتقل مباشرة إلى HomePage
        return const HomePage();
      } else {
        // المستخدم غير مسجل دخول
        return const WelcomeScreen();
      }
    });
  }
}

// شاشة تحميل بسيطة

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الصورة كخلفية
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Quran.jpg'),
                fit: BoxFit.fill, // لتغطية الشاشة كاملة
              ),
            ),
          ),
          // طبقة تدرج لوني فوق الصورة لتحسين قراءة النص
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.white.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
          // المحتوى
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 300),
                // نص فرعي
                Text(
                  'صيدليتك بين يديك',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                    fontFamily: 'Cairo',
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // مؤشر تحميل
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}