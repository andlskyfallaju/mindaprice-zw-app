import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'profile_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import 'notification_settings_screen.dart';
import 'license_screen.dart';
import '../widgets/chat_wallpaper_picker.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String version = "";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    loadVersion();
  }

  Future<void> loadVersion() async {
    PackageInfo info = await PackageInfo.fromPlatform();

    setState(() {
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Logout",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to log out?",
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "No",
              style: GoogleFonts.montserrat(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(
              "Yes",
              style: GoogleFonts.montserrat(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Appearance",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, "System Default", Icons.brightness_auto, ThemeMode.system),
            _buildThemeOption(context, "Light Mode", Icons.light_mode, ThemeMode.light),
            _buildThemeOption(context, "Dark Mode", Icons.dark_mode, ThemeMode.dark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, ThemeMode mode) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isSelected = currentMode == mode;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListTile(
          leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
          title: Text(
            title,
            style: GoogleFonts.montserrat(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isSelected ? Icon(Icons.check_circle, color: isDark ? Colors.greenAccent : Colors.green) : null,
          onTap: () {
            ThemeService.setThemeMode(mode);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
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
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
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
            "Settings",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  buildSettingsTile(
                    icon: Icons.person_outline,
                    title: "Profile",
                    subtitle: "View your account details",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  buildSettingsTile(
                    icon: Icons.notifications_outlined,
                    title: "Notifications",
                    subtitle: "Manage message and advisory alerts",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  buildSettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: "Appearance",
                    subtitle: "Choose between light, dark, or system theme",
                    onTap: () => _showThemeDialog(context),
                  ),
                  buildSettingsTile(
                    icon: Icons.wallpaper_rounded,
                    title: "Chat Wallpaper",
                    subtitle: "Customize your chat background",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatWallpaperPicker(),
                        ),
                      );
                    },
                  ),
                  buildSettingsTile(
                    icon: Icons.info_outline,
                    title: "About",
                    subtitle: "About the MindaPriceZW app & Licenses",
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          title: Row(
                            children: [
                              Image.asset('assets/icon.png', height: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "MindaPriceZW",
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    Text(
                                      "Version $version ($buildNumber)",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          content: const Text(
                            "MindaPriceZW is an agricultural marketplace and advisory platform designed to help farmers access real-time market prices, weather-based farming advice, and communication tools.",
                            style: TextStyle(fontSize: 14, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                "Close",
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LicenseScreen(),
                                  ),
                                );
                              },
                              child: const Text("View Licenses"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  buildSettingsTile(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    subtitle: "Sign out of your account",
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Version $version (Build $buildNumber)",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}