import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/fcm_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool advisoryNotifications = true;
  bool messengerNotifications = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  bool reviewNotifications = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      advisoryNotifications =
          prefs.getBool('advisory_notifications') ?? true;
      messengerNotifications =
          prefs.getBool('messenger_notifications') ?? true;
      soundEnabled = prefs.getBool('sound_enabled') ?? true;
      vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      reviewNotifications = prefs.getBool('review_notifications') ?? true;
      isLoading = false;
    });
  }

  Future<void> _syncReviewPreferenceToFirestore(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'reviewNotificationsEnabled': value,
      });
    }
  }

  Future<void> saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.green[800]),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.montserrat(fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            "Notifications",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  buildSwitchTile(
                    icon: Icons.eco_outlined,
                    title: 'Advisory Notifications',
                    subtitle: 'Receive farming advisory alerts and updates.',
                    value: advisoryNotifications,
                    onChanged: (value) {
                      setState(() => advisoryNotifications = value);
                      saveSetting('advisory_notifications', value);
                      FcmService.updateTopicSubscription('advisories', value);
                    },
                  ),
                  buildSwitchTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Messenger Notifications',
                    subtitle: 'Receive new message alerts.',
                    value: messengerNotifications,
                    onChanged: (value) {
                      setState(() => messengerNotifications = value);
                      saveSetting('messenger_notifications', value);
                    },
                  ),
                  buildSwitchTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Notification Sound',
                    subtitle: 'Play sound when a notification arrives.',
                    value: soundEnabled,
                    onChanged: (value) {
                      setState(() => soundEnabled = value);
                      saveSetting('sound_enabled', value);
                    },
                  ),
                  buildSwitchTile(
                    icon: Icons.vibration_outlined,
                    title: 'Vibration',
                    subtitle: 'Vibrate when receiving notifications.',
                    value: vibrationEnabled,
                    onChanged: (value) {
                      setState(() => vibrationEnabled = value);
                      saveSetting('vibration_enabled', value);
                    },
                  ),
                  buildSwitchTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Marketplace Reviews',
                    subtitle: 'Be notified when someone gives you a rating.',
                    value: reviewNotifications,
                    onChanged: (value) {
                      setState(() => reviewNotifications = value);
                      saveSetting('review_notifications', value);
                      _syncReviewPreferenceToFirestore(value);
                    },
                  ),
                ],
              ),
            ),
    ),
  );
}
}