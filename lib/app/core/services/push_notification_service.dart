import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

import '../../controllers/main_navigation_controller.dart';
import '../../../features/auth/services/email_action_service.dart';
import '../../../features/chat/models/chat_thread_model.dart';
import '../../../features/chat/views/chat_detail_screen.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<User?>? _userChangesSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;
  String? _pendingChatId;
  bool _openingChat = false;
  bool _pushDisabledWhileSignedOut = false;

  Future<void> init() async {
    if (_initialized) {
      debugPrint('🔁 PushNotificationService already initialized');
      return;
    }

    debugPrint('🚀 PushNotificationService.init() started');

    try {
      await _messaging.setAutoInitEnabled(
        FirebaseAuth.instance.currentUser != null,
      );
      debugPrint('✅ Auto init enabled');

      await _requestPermission();
      await _initLocalNotifications();
      _listenUserChanges();
      _listenForegroundMessages();
      _listenOpenedApp();
      await _setupInteractedMessage();

      _initialized = true;
      unawaited(_initializeToken());
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

      const androidSettings = AndroidInitializationSettings(
        'ic_notification',
      );

      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          final payload = details.payload;
          debugPrint('🖱 Local notification clicked. payload=$payload');
          _handleLocalPayload(payload);
        },
      );

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handleLocalPayload(launchDetails?.notificationResponse?.payload);
      }

      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Local notifications initialized');
    } catch (e, s) {
      debugPrint('❌ _initLocalNotifications error: $e');
      debugPrint('$s');
    }
  }

  void _handleLocalPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _handleNavigation(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (error) {
      debugPrint('Invalid local notification payload: $error');
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

  void _listenUserChanges() {
    _userChangesSubscription ??= FirebaseAuth.instance.userChanges().listen((
      user,
    ) {
      if (user == null) {
        _pendingChatId = null;
        unawaited(_localNotifications.cancelAll());
        return;
      }
      _pushDisabledWhileSignedOut = false;
      unawaited(_activateForUser(user.uid));
      _schedulePendingChat();
    });
  }

  Future<void> _initializeToken() async {
    try {
      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((
        newToken,
      ) {
        _currentToken = newToken;
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          unawaited(_unregisterTokenSafely(newToken));
          return;
        }
        unawaited(_registerTokenSafely(newToken, userId));
      });

      final token = await _messaging.getToken();
      _currentToken = token;
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (token == null) return;
      if (userId == null) {
        await _unregisterTokenSafely(token);
        await _deleteLocalToken();
      } else {
        await _registerTokenSafely(token, userId);
      }
    } catch (error) {
      debugPrint('Unable to initialize FCM token: $error');
    }
  }

  Future<void> _activateForUser(String userId) async {
    try {
      await _messaging.setAutoInitEnabled(true);
      final token = await _messaging.getToken();
      if (token == null || FirebaseAuth.instance.currentUser?.uid != userId) {
        return;
      }
      _currentToken = token;
      await _registerTokenSafely(token, userId);
    } catch (error) {
      debugPrint('Unable to activate FCM token: $error');
    }
  }

  Future<void> _registerTokenSafely(String token, String userId) async {
    if (FirebaseAuth.instance.currentUser?.uid != userId) return;
    try {
      await _functions.httpsCallable('syncUserPushToken').call({
        'action': 'register',
        'token': token,
      });
    } catch (error) {
      debugPrint('Unable to register FCM token: $error');
    }
  }

  Future<void> _unregisterTokenSafely(String token) async {
    try {
      await _functions.httpsCallable('syncUserPushToken').call({
        'action': 'unregister',
        'token': token,
      });
    } catch (error) {
      debugPrint('Unable to unregister FCM token: $error');
    }
  }

  Future<void> _deleteLocalToken() async {
    try {
      await _messaging.setAutoInitEnabled(false);
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Unable to delete local FCM token: $error');
    } finally {
      _currentToken = null;
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (_pushDisabledWhileSignedOut) return;
    _pushDisabledWhileSignedOut = true;
    _pendingChatId = null;

    try {
      final token = _currentToken ?? await _messaging.getToken();
      if (token != null) await _unregisterTokenSafely(token);
    } catch (error) {
      debugPrint('Device token cleanup deferred: $error');
    }
    try {
      await _localNotifications.cancelAll();
    } catch (error) {
      debugPrint('Local notification cleanup deferred: $error');
    }
    await _deleteLocalToken();
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
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final targetUserId = message.data['userId']?.toString().trim() ?? '';
      if (currentUserId == null ||
          (targetUserId.isNotEmpty && targetUserId != currentUserId)) {
        debugPrint('Skipped push for a signed-out or different user');
        return;
      }

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
            icon: 'ic_notification',
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

  void _openNotificationsPage() {
    try {
      Get.find<MainNavigationController>().goNotifications();
    } catch (error) {
      debugPrint('Unable to open notifications: $error');
    }
  }

  void _openChatsPage() {
    try {
      Get.find<MainNavigationController>().goChats();
    } catch (error) {
      debugPrint('Unable to open chats: $error');
    }
  }

  void _schedulePendingChat() {
    if (_pendingChatId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openPendingChat());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _openPendingChat() async {
    final chatId = _pendingChatId;
    final user = FirebaseAuth.instance.currentUser;
    if (chatId == null ||
        user == null ||
        EmailActionService.requiresEmailVerification(user) ||
        _openingChat) {
      return;
    }

    _openingChat = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      final data = snapshot.data();
      if (_pendingChatId != chatId ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return;
      }
      if (!snapshot.exists ||
          data == null ||
          data['userId']?.toString() != user.uid) {
        throw StateError('المحادثة غير متاحة لهذا الحساب');
      }

      final thread = ChatThread.fromFirestore(data, snapshot.id);
      _pendingChatId = null;
      _openChatsPage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
          Get.to(() => ChatDetailScreen(thread: thread));
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    } catch (error) {
      debugPrint('Unable to open chat from push: $error');
      if (_pendingChatId == chatId) {
        _pendingChatId = null;
        _openChatsPage();
      }
    } finally {
      _openingChat = false;
      if (_pendingChatId != null && _pendingChatId != chatId) {
        _schedulePendingChat();
      }
    }
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final targetUserId = data['userId']?.toString().trim() ?? '';
    if (currentUserId == null ||
        (targetUserId.isNotEmpty && targetUserId != currentUserId)) {
      debugPrint('Ignored notification navigation for another session');
      return;
    }

    final type = data['type']?.toString();
    final orderId = data['orderId']?.toString();
    final pushedChatId = data['chatId']?.toString().trim() ?? '';
    final chatId = pushedChatId.isNotEmpty
        ? pushedChatId
        : data['referenceId']?.toString().trim() ?? '';

    debugPrint('➡️ Notification click data: $data');

    if (data['referenceType'] == 'chat' ||
        type == 'pharmacyMessage' ||
        type == 'chatMessage' ||
        type == 'chat') {
      if (chatId.isEmpty) {
        _openChatsPage();
      } else {
        _pendingChatId = chatId;
        _schedulePendingChat();
      }
      return;
    }

    switch (type) {
      case 'order':
      case 'orderUpdate':
        _openOrdersPage(orderId: orderId);
        break;

      case 'adminMessage':
      case 'adminBroadcast':
      case 'admin_broadcast':
      case 'promotion':
      case 'system':
        _openNotificationsPage();
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
