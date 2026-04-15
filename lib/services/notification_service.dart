import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init({
    void Function(String? payload)? onNotificationTap,
  }) async {
    if (kIsWeb) return; // Local notifications not supported on web via this plugin

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (onNotificationTap != null) {
          onNotificationTap(response.payload);
        }
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'advisory_channel',
        'Advisory Notifications',
        description: 'Notifications for farming advisory alerts and chat messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required String notificationType, // 'advisory' or 'messenger'
    String? payload,
  }) async {
    if (kIsWeb) return; // Skip showing local UI notifications on web

    final prefs = await SharedPreferences.getInstance();
    
    // Check if notifications are enabled for this type
    final isEnabled = prefs.getBool('${notificationType}_notifications') ?? true;
    if (!isEnabled) return;

    // Get sound and vibration preferences
    final soundEnabled = prefs.getBool('sound_enabled') ?? true;
    final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    final androidDetails = AndroidNotificationDetails(
      'advisory_channel',
      'Advisory Notifications',
      channelDescription: 'Notifications for farming advisory alerts and chat messages',
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      fullScreenIntent: true,
      ticker: 'ticker',
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}