import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';

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

    setState(() {
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About MindaPriceZW"),
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
                  color: Colors.green[800],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "Version $version (Build $buildNumber)",
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 25),

              const Text(
                "MindaPriceZW is an agricultural platform designed to provide farmers with real-time market prices, weather-based farming advisory, and communication tools.",
                textAlign: TextAlign.center,
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
    );
  }
}