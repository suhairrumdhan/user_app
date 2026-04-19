import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderPermissionService {
  ReminderPermissionService._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notificationsGranted =
        await android?.requestNotificationsPermission() ?? false;

    final exactAlarmsGranted =
        await android?.requestExactAlarmsPermission() ?? false;

    debugPrint('🔔 notificationsGranted=$notificationsGranted');
    debugPrint('⏰ exactAlarmsGranted=$exactAlarmsGranted');

    return notificationsGranted || exactAlarmsGranted;
  }
}