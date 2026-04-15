import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'services/theme_service.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/pricing_admin_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/cache_service.dart';

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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (senderId != null && senderId != currentUid && navigatorKey.currentState != null) {
      // Clear stack and jump to Messenger tab (index 2), then push the specific chat
      navigatorKey.currentState!.pushNamedAndRemoveUntil('/home', (route) => false, arguments: 2);
      
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
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: 2, // initialIndex is handled in MainNavigationScreen if we pass it as arg, or we can just push with replacement
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
  await Hive.initFlutter();
  await CacheService.performMaintenance();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    // Initialize Google Sign-In once at startup for mobile
    await GoogleSignIn.instance.initialize();

    await NotificationService.init(
      onNotificationTap: handleNotificationTapPayload,
    );
  }

  await ThemeService.init();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final payload = jsonEncode(message.data);

      final dynamic type = message.data['type'];
      final String notificationType = (type == 'chat' || type == 'messenger') ? 'messenger' : 'advisory';

      NotificationService.showNotification(
        title: message.notification?.title ?? 'Notification',
        body: message.notification?.body ?? '',
        notificationType: notificationType,
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationPayload(message.data);
    });
  }

  RemoteMessage? initialMessage;
  if (!kIsWeb) {
    initialMessage = await FirebaseMessaging.instance.getInitialMessage().timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
  }

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'MindaPrice ZW',
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: Colors.green[800],
            scaffoldBackgroundColor: Colors.grey[50],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.green[700],
              elevation: 2,
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
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
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: Colors.green[900],
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF1A1A1A),
              elevation: 2,
              foregroundColor: Colors.white,
              titleTextStyle: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
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
            '/pricing-admin': (context) => const PricingAdminScreen(),
          },
        );
      },
    );
  }
}