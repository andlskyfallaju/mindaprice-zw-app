import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Compares semver strings. Returns true if [current] satisfies [minimum].
  static bool _meetsMinVersion(String current, String minimum) {
    final c = current.split('.').map(int.tryParse).toList();
    final m = minimum.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final cv = (i < c.length ? c[i] : 0) ?? 0;
      final mv = (i < m.length ? m[i] : 0) ?? 0;
      if (cv > mv) return true;
      if (cv < mv) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) return const LoginScreen();

        // Version check — non-blocking, fire-and-forget style
        return FutureBuilder<bool>(
          future: _checkVersion(),
          builder: (context, vSnap) {
            if (vSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final isOutdated = vSnap.data == false;
            if (isOutdated) {
              return _UpdateRequiredScreen();
            }

            return const MainNavigationScreen();
          },
        );
      },
    );
  }

  /// Fetches `config/app_version` from Firestore and compares with installed version.
  /// Returns true if the user's version is acceptable. Defaults to true on errors (fail-open).
  static Future<bool> _checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!doc.exists) return true; // No config set yet → pass

      final minVersion = (doc.data()?['min_version'] ?? '0.1.0').toString();
      return _meetsMinVersion(info.version, minVersion);
    } catch (_) {
      return true; // Fail-open: never block users due to a network error
    }
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_alt_rounded, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Update Required',
                style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'A new version of MindaPrice ZW is available. Please update to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Link to Play Store when published
                  // launchUrl(Uri.parse('market://details?id=com.example.mindaprice_test'));
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Update Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}