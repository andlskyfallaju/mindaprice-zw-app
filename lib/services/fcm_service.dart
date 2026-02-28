import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Called once after login / when HomeScreen opens
  static Future<void> initAndSubscribe() async {
    // Android 13+ requires runtime notification permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe device to advisory broadcast topic
    await _messaging.subscribeToTopic('advisories');

    // Save device token to Firestore
    await registerDeviceToken();

    // Listen for token refresh (Firebase rotates tokens occasionally)
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(newToken);
    });
  }

  // Get the current device token and store it
  static Future<void> registerDeviceToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  // Save token under the current user
  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}
