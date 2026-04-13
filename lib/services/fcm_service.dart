import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


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
    debugPrint("FCM: Subscribed to 'advisories' topic");

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

  // Handle topic subscription dynamically
  static Future<void> updateTopicSubscription(String topic, bool subscribe) async {
    if (subscribe) {
      await _messaging.subscribeToTopic(topic);
      debugPrint("FCM: Subscribed to topic: $topic");
    } else {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint("FCM: Unsubscribed from topic: $topic");
    }
  }

  /// Clean up subscriptions and tokens before user logs out.
  static Future<void> prepareForLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch the user's current location topic from Firestore to unsubscribe
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final locationTopic = userDoc.data()?['locationTopic'] as String?;

      // 2. Unsubscribe from all known topics
      await _messaging.unsubscribeFromTopic('advisories');
      debugPrint("FCM: Unsubscribed from 'advisories'");

      await _messaging.unsubscribeFromTopic('messages');
      debugPrint("FCM: Unsubscribed from 'messages'");

      if (locationTopic != null && locationTopic.isNotEmpty) {
        await _messaging.unsubscribeFromTopic(locationTopic);
        debugPrint("FCM: Unsubscribed from location topic: $locationTopic");
      }

      // 3. Clear the token from Firestore (so backend stops sending targeted messages)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
        'locationTopic': FieldValue.delete(),
      });

      // 4. Delete the token locally (forces a new one on next login)
      await _messaging.deleteToken();
      
    } catch (e) {
      debugPrint("Error during FCM cleanup: $e");
    }
  }
}
