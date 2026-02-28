import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/advisory_screen.dart';
import 'services/notification_service.dart';

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications
  await NotificationService.init();

  // Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      NotificationService.showNotification(
        title: message.notification!.title ?? 'Advisory Alert',
        body: message.notification!.body ?? '',
      );
    }
  });

  runApp(const MindaPriceApp());
}

class MindaPriceApp extends StatelessWidget {
  const MindaPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/advisory': (context) => const AdvisoryScreen(),
      },
    );
  }
}
