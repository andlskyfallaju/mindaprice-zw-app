import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/advisory_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/chat_screen.dart';
import 'services/notification_service.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_settings_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void handleNotificationPayload(Map data) {
  final safeData = Map<String, dynamic>.from(data);

  if (safeData['type'] == 'chat') {
    final senderId = safeData['senderId'];
    final senderName = (safeData['senderName'] ?? 'Chat').toString();

    if (senderId != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUserId: senderId.toString(),
            otherUsername: senderName,
          ),
        ),
      );
    }
  } else if (safeData['type'] == 'advisory') {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(initialIndex: 2),
        ),
      );
    }
  }
}

void handleNotificationTapPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;

  try {
    final decoded = jsonDecode(payload);
    final data = Map<String, dynamic>.from(decoded as Map);
    handleNotificationPayload(data);
  } catch (e) {
    debugPrint("Notification payload error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.init(
    onNotificationTap: handleNotificationTapPayload,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final payload = jsonEncode(message.data);

    NotificationService.showNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      payload: payload,
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    handleNotificationPayload(message.data);
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  runApp(MindaPriceApp(initialMessage: initialMessage));
}

class MindaPriceApp extends StatefulWidget {
  final RemoteMessage? initialMessage;

  const MindaPriceApp({super.key, this.initialMessage});

  @override
  State<MindaPriceApp> createState() => _MindaPriceAppState();
}

class _MindaPriceAppState extends State<MindaPriceApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessage != null) {
        handleNotificationPayload(widget.initialMessage!.data);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MindaPrice ZW',
      theme: ThemeData(
        primaryColor: Colors.green[800],
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const MainNavigationScreen(),
        '/advisory': (context) => const AdvisoryScreen(),
        '/chat': (context) => const ChatListScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
      },
    );
  }
}