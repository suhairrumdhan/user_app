import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:user_application/screens/home_page.dart';
import 'package:user_application/screens/welcome_page.dart';
import 'firebase_options.dart'; // تولده من Firebase Console
import 'package:user_application/auth/user_repository.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Get.put(UserRepository()); // ← تهيئة الريبو
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'user app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const HomePage(),
    );
  }
}
