import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_gradient.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = "";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    loadVersion();
  }

  Future<void> loadVersion() async {
    PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        version = info.version;
        buildNumber = info.buildNumber;
      });
    }
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
            "About MindaPriceZW",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "MindaPriceZW",
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Version $version (Build $buildNumber)",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 25),
                const Text(
                  "MindaPriceZW is an agricultural platform designed to provide farmers with real-time market prices, weather-based farming advisory, and communication tools.",
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 30),
                const Text(
                  "© 2026 MindaPriceZW",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}