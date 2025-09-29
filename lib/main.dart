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

// Widget جديد لإدارة حالة المصادقة
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
        // المستخدم مسجل دخول - نتحقق من المعلومات الصحية
        return const HealthCheckWrapper();
      } else {
        // المستخدم غير مسجل دخول
        return const WelcomeScreen();
      }
    });
  }
}

// Widget للتحقق من اكتمال المعلومات الصحية
class HealthCheckWrapper extends StatelessWidget {
  const HealthCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return FutureBuilder<bool>(
      future: authController.isHealthInfoComplete(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const HomePage(); // المعلومات الصحية مكتملة
        } else {
          return const HealthInfoScreen(); // يحتاج إكمال المعلومات الصحية
        }
      },
    );
  }
}

// شاشة تحميل بسيطة
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'PHARMACY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}