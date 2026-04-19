import 'dart:convert';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../controllers/main_navigation_controller.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      debugPrint('🔁 PushNotificationService already initialized');
      return;
    }

    debugPrint('🚀 PushNotificationService.init() started');

    try {
      await _messaging.setAutoInitEnabled(true);
      debugPrint('✅ Auto init enabled');

      await _requestPermission();
      await _initLocalNotifications();
      await _setupInteractedMessage();
      await _printAndRefreshToken();
      _listenForegroundMessages();
      _listenOpenedApp();

      _initialized = true;
      debugPrint('✅ PushNotificationService.init() completed');
    } catch (e, s) {
      debugPrint('❌ PushNotificationService.init error: $e');
      debugPrint('$s');
    }
  }

  Future<void> _requestPermission() async {
    try {
      debugPrint('🔐 Requesting notification permission...');

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        '🔐 Notification permission status: ${settings.authorizationStatus}',
      );
    } catch (e, s) {
      debugPrint('❌ _requestPermission error: $e');
      debugPrint('$s');
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      debugPrint('🔔 Initializing local notifications...');

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          final payload = details.payload;
          debugPrint('🖱 Local notification clicked. payload=$payload');

          if (payload == null || payload.isEmpty) return;

          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _handleNavigation(data);
        },
      );

      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Local notifications initialized');
    } catch (e, s) {
      debugPrint('❌ _initLocalNotifications error: $e');
      debugPrint('$s');
    }
  }

  Future<void> _setupInteractedMessage() async {
    try {
      debugPrint('📦 Checking initial message...');

      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint('📦 App opened from terminated notification');
        debugPrint('📦 Initial message data: ${initialMessage.data}');
        _handleNavigation(initialMessage.data);
      } else {
        debugPrint('📦 No initial message');
      }
    } catch (e, s) {
      debugPrint('❌ _setupInteractedMessage error: $e');
      debugPrint('$s');
    }
  }

  Future<void> _printAndRefreshToken() async {
    final token = await _messaging.getToken();
    debugPrint('📱 FCM Token: $token');

    await _saveToken(token);

    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('♻️ Refreshed FCM Token: $newToken');
      await _saveToken(newToken);
    });
  }

  Future<void> _saveToken(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }
  void _listenForegroundMessages() {
    debugPrint('👂 Listening for foreground messages...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📩 Foreground message received');
      debugPrint('📩 Title: ${message.notification?.title}');
      debugPrint('📩 Body: ${message.notification?.body}');
      debugPrint('📩 Data: ${message.data}');

      await _showLocalNotification(message);
    });
  }

  void _listenOpenedApp() {
    debugPrint('👂 Listening for notification opens...');

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🟢 Notification opened app');
      debugPrint('🟢 OpenedApp data: ${message.data}');
      _handleNavigation(message.data);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;

      if (notification == null) {
        debugPrint('⚠️ No notification payload, skipping local notification');
        return;
      }

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );

      debugPrint('✅ Local notification shown');
    } catch (e, s) {
      debugPrint('❌ _showLocalNotification error: $e');
      debugPrint('$s');
    }
  }
  void _openOrdersPage({String? orderId}) {
    try {
      final navController = Get.find<MainNavigationController>();
      navController.goOrders(orderId: orderId);

      debugPrint('📦 Opening orders page. orderId=$orderId');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }
  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final orderId = data['orderId']?.toString();

    debugPrint('➡️ Notification click data: $data');

    switch (type) {
      case 'order':
      case 'orderUpdate':
        _openOrdersPage(orderId: orderId);
        break;

      case 'chat':
      // لاحقاً
        break;

      case 'medicine_reminder':
      // لاحقاً
        break;

      default:
        _openOrdersPage(orderId: orderId);
        break;
    }
  }
}