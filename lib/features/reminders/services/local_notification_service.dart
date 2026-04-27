import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin plugin =
  FlutterLocalNotificationsPlugin();

  static const String medicationChannelId = 'medication_reminders_channel';
  static const String appointmentChannelId = 'appointment_reminders_channel';
  static const String snoozeChannelId = 'health_snooze_channel';

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapNotification,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    final enabled = await android?.areNotificationsEnabled();
    debugPrint('🔔 notifications enabled: $enabled');
    await _createAndroidChannels();
  }


  static Future<void> _createAndroidChannels() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        medicationChannelId,
        'Medication Reminders',
        description: 'Daily medication reminder notifications',
        importance: Importance.max,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        appointmentChannelId,
        'Appointment Reminders',
        description: 'Appointment reminder notifications',
        importance: Importance.max,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        snoozeChannelId,
        'Snoozed Health Reminders',
        description: 'Snoozed reminder notifications',
        importance: Importance.max,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // لاحقًا نربطها بـ deep-link / reminder action flow
  }

  static void _onTapNotification(NotificationResponse response) {
    final payload = response.payload;

    if (response.actionId == 'taken') {
      debugPrint('💊 taken clicked');
      // سجل في ReminderLog
    } else if (response.actionId == 'snooze') {
      debugPrint('⏰ snooze clicked');
      // schedule بعد 10 دقائق
    } else {
      debugPrint('🔔 notification tapped');
    }
  }

  static NotificationDetails medicationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        medicationChannelId,
        'Medication Reminders',
        channelDescription: 'Reminders for medications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'taken',
            'تم الأخذ',
          ),
          AndroidNotificationAction(
            'snooze',
            'تأجيل 10 دقائق',
          ),
        ],
      ),
    );
  }
  
  static NotificationDetails appointmentDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        appointmentChannelId,
        'Appointment Reminders',
        channelDescription: 'Appointment reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    );
  }

  static NotificationDetails snoozeDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        snoozeChannelId,
        'Snoozed Health Reminders',
        channelDescription: 'Snoozed reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    );
  }


  static Future<void> cancel(int id) => plugin.cancel(id);

  static Future<void> cancelAll(List<int> ids) async {
    for (final id in ids) {
      await plugin.cancel(id);
    }
  }

  static Future<void> cancelSingle(int? id) async {
    if (id == null) return;
    await plugin.cancel(id);
  }

  static Future<List<PendingNotificationRequest>> pendingRequests() {
    return plugin.pendingNotificationRequests();
  }

  static tz.TZDateTime nextInstanceOfTime({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  static tz.TZDateTime fromDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }
}