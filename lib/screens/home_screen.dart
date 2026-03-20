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
import 'chat_list_screen.dart';
import '../services/fcm_service.dart';
import '../services/weather_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

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
  String photoUrl = '';

  String miniAdvisory = "Loading weather...";
  double? miniTemp;
  int? miniRainProb;
  double? miniWindSpeed;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    fetchUsername();
    startClock();
    getLocation();
    loadMiniWeather();
    FcmService.registerDeviceToken();
    FcmService.initAndSubscribe();
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
      photoUrl = (doc.data()?['photoUrl'] ?? '').toString();
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => locationText = "Turn on Location/GPS");
        return;
      }

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

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

      // Fetch dynamic weather now that we have the coordinates
      loadMiniWeather(lat: position.latitude, lon: position.longitude);
      
    } catch (_) {
      if (!mounted) return;
      setState(() => locationText = "Location unavailable");
    }
  }

  Future<void> loadMiniWeather({double? lat, double? lon}) async {
    try {
      final data = await WeatherService.fetchWeatherAdvisory(lat: lat, lon: lon);

      setState(() {
        miniTemp = (data["weather"]["temperature"] as num).toDouble();
        miniRainProb =
            (data["weather"]["precipitation_probability"] as num).toInt();
        miniWindSpeed = (data["weather"]["wind_speed"] as num).toDouble();
        miniAdvisory = data["advisory"] ?? "No advisory available";
      });
    } catch (_) {
      setState(() {
        miniAdvisory = "Weather unavailable";
      });
    }
  }

  IconData getWeatherIcon({
    required int? rainProbability,
    required double? temperature,
    required double? windSpeed,
  }) {
    if (rainProbability != null && rainProbability >= 70) {
      return Icons.thunderstorm_outlined;
    }
    if (rainProbability != null && rainProbability >= 40) {
      return Icons.cloud_outlined;
    }
    if (windSpeed != null && windSpeed >= 20) {
      return Icons.air;
    }
    if (temperature != null && temperature >= 30) {
      return Icons.wb_sunny_outlined;
    }
    return Icons.wb_cloudy_outlined;
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

  Widget buildMiniWeatherCard() {
    final weatherIcon = getWeatherIcon(
      rainProbability: miniRainProb,
      temperature: miniTemp,
      windSpeed: miniWindSpeed,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.green.shade200,
            Colors.green.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  weatherIcon,
                  size: 34,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Weather",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      miniTemp != null
                          ? "${miniTemp!.toStringAsFixed(1)}°C"
                          : "--°C",
                      style: GoogleFonts.montserrat(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      miniRainProb != null
                          ? "Rain chance: $miniRainProb%"
                          : "Loading forecast...",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loadMiniWeather,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: "Refresh weather",
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  size: 18,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    miniAdvisory,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 3,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.orange.shade800,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 28),
              ],
            ),
          ),
        ),
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
          automaticallyImplyLeading: false,
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/settings').then((_) {
                    fetchUsername();
                  });
                },
                child: photoUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 17,
                        backgroundImage: NetworkImage(photoUrl),
                      )
                    : CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white, // Changed from green[200]
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green, // Changed from black87
                          ),
                        ),
                      ),
              ),
            ),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "MindaPrice ZW",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currentTime, style: const TextStyle(fontSize: 12)),
                InkWell(
                  onTap: toggleLocation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Welcome, $username!\nMindaPrice ZW",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            buildMiniWeatherCard(),
            const SizedBox(height: 26),
            buildFeatureCard(
              icon: Icons.storefront_outlined,
              title: "Market Prices",
              subtitle:
                  "Browse agricultural product pricing and marketplace updates.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PriceScreen()),
                );
              },
            ),
            const SizedBox(height: 18),
            buildFeatureCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: "Messenger",
              subtitle:
                  "Chat in real time with other users and admins in the app.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            buildFeatureCard(
              icon: Icons.eco_outlined,
              title: "Farming Advisory",
              subtitle:
                  "View weather-based guidance and admin broadcast advisories.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdvisoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
}
}