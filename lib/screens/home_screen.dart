import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'price_screen.dart';
import 'advisory_screen.dart';
import '../services/fcm_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';
  String currentTime = '';
  String locationText = 'Loading location...';
  bool showLatLong = true;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    fetchUsername();
    startClock();
    getLocation();

    // FCM (token + topic subscribe)
    FcmService.registerDeviceToken();
    FcmService.initAndSubscribe(); // make sure your fcm_service.dart has this method
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      setState(() {
        username = (doc.data()?['username'] ?? '').toString();
      });
    }
  }

  void startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        currentTime = DateFormat('EEE, MMM d • HH:mm:ss').format(DateTime.now());
      });
    });
  }

  Future<void> getLocation() async {
    try {
      // 1) Check if location services are on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => locationText = "Turn on Location/GPS");
        return;
      }

      // 2) Check permission first (don’t always request)
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => locationText = "Location permission denied");
        return;
      }

      // 3) Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      // 4) Display lat/long or city/country
      if (showLatLong) {
        setState(() {
          locationText =
              "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      } else {
        final placemarks =
            await placemarkFromCoordinates(position.latitude, position.longitude);

        final place = placemarks.isNotEmpty ? placemarks.first : null;
        final city = place?.locality ?? place?.subAdministrativeArea;
        final country = place?.country;

        setState(() {
          if (city != null && country != null) {
            locationText = "$city, $country";
          } else if (country != null) {
            locationText = country;
          } else {
            locationText = "Location unavailable";
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => locationText = "Location unavailable");
    }
  }

  void toggleLocation() {
    setState(() => showLatLong = !showLatLong);
    getLocation();
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MindaPrice ZW",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currentTime, style: const TextStyle(fontSize: 12)),
                InkWell(
                  onTap: toggleLocation,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      locationText,
                      style: const TextStyle(
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ CENTERED GREETING + PADDING
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  "Welcome, $username! to MindaPrice ZW",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.store),
              label: Text(
                "View Market Prices",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PriceScreen()),
                );
              },
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.eco),
              label: Text(
                "Farming Advisory",
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdvisoryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
