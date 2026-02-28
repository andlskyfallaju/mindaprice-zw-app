import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(initSettings);

    // 🔔 Create HIGH importance notification channel (WhatsApp-style popups)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'advisory_channel',
      'Advisory Notifications',
      description: 'Notifications for farming advisory alerts',
      importance: Importance.max, // CRITICAL for floating popup
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'advisory_channel',
      'Advisory Notifications',
      channelDescription: 'Notifications for farming advisory alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // helps force heads-up popup
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // unique ID so multiple notifications don't overwrite each other
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }
}
