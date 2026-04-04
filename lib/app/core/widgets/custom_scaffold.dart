import 'dart:ui';

import 'package:flutter/material.dart';

class CustomScaffold extends StatelessWidget {
  const CustomScaffold({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // الخلفية بالصورة + بلور
          SizedBox.expand(
            // درجة التمويه
            child: Image.asset(
              'assets/images/BG.jpg', // مسار الصورة
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withOpacity(0.3), // هنا الشفافية تعمل
              ),
            ),
          ),

          // محتوى التطبيق فوق الخلفية
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(child: child!),
          ),
        ],
      ),
    );
  }
}
