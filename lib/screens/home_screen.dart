import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../services/cache_service.dart';

import 'price_screen.dart';
import 'advisory_screen.dart';
import 'chat_list_screen.dart';
import 'ai_advisor_screen.dart';
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
  String accountType = 'farmer'; // Default

  String miniAdvisory = "Loading weather...";
  double? miniTemp;
  int? miniRainProb;
  double? miniWindSpeed;
  String weatherTimestamp = "";
  bool isOffline = false;
  StreamSubscription? _connectivitySubscription;

  double? _lat;
  double? _lon;
  String? _currentLocationTopic;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    fetchUsername();
    startClock();
    getLocation();
    loadMiniWeather();
    initConnectivity();
    WeatherService.weatherNotifier.addListener(_onWeatherUpdated);
    FcmService.registerDeviceToken();
    FcmService.initAndSubscribe();
  }

  void initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!mounted) return;
      setState(() {
        isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      });
      if (!isOffline) {
        loadMiniWeather(); // Refresh when back online
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _connectivitySubscription?.cancel();
    WeatherService.weatherNotifier.removeListener(_onWeatherUpdated);
    super.dispose();
  }

  void _onWeatherUpdated() async {
    final data = WeatherService.weatherNotifier.value;
    if (data == null || !mounted) return;

    setState(() {
      miniTemp = (data["weather"]["temperature"] as num).toDouble();
      miniRainProb = (data["weather"]["precipitation_probability"] as num).toInt();
      miniWindSpeed = (data["weather"]["wind_speed"] as num).toDouble();
      miniAdvisory = data["advisory"] ?? "No advisory available";
    });

    // Refresh timestamp from cache
    final cacheKey = "weather_${_lat?.toStringAsFixed(2)}_${_lon?.toStringAsFixed(2)}";
    final cached = await CacheService.getCachedData(CacheService.weatherBoxName, cacheKey);
    if (cached != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(cached['timestamp']);
      setState(() {
        weatherTimestamp = "Last updated: ${DateFormat('jm').format(dt)}";
      });
    }
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
        accountType = (doc.data()?['accountType'] ?? 'farmer').toString().toLowerCase();
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

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (!mounted) return;
        setState(() => locationText = "Location unavailable (Timeout)");
        return;
      }

      _lat = position.latitude;
      _lon = position.longitude;

      if (!mounted) return;

      String displayLocation = "";
      String topicName = "";

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        final place = placemarks.isNotEmpty ? placemarks.first : null;
        final city = place?.locality ?? place?.subAdministrativeArea ?? 'UnknownCity';
        final country = place?.country ?? 'UnknownCountry';
        
        displayLocation = "$city, $country";
        // Sanitize topic name: only alphanumeric, -, ~, % and _
        topicName = "advisories_${city.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_${country.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}";
      } catch (_) {
        displayLocation = "Location unavailable";
      }

      if (showLatLong) {
        setState(() {
          locationText =
              "${position!.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      } else {
        setState(() {
          locationText = displayLocation;
        });
      }

      // 1. Unsubscribe from previous location topic to avoid redundant notifications
      if (_currentLocationTopic != null && _currentLocationTopic != topicName) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_currentLocationTopic!);
        debugPrint("FCM: Unsubscribed from old topic: $_currentLocationTopic");
      }

      // 2. Subscribe to new location topic
      if (topicName.isNotEmpty) {
        await FirebaseMessaging.instance.subscribeToTopic(topicName);
        _currentLocationTopic = topicName;
        debugPrint("FCM: Subscribed to new topic: $topicName");

        // 2. Save active region location to Firestore users document for the Node.js backend to map
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'locationTopic': topicName,
            'locationName': displayLocation,
            'lat': _lat,
            'lon': _lon,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });

          // Feature 2: Register this region in active_regions via backend
          // This is fire-and-forget — errors are non-critical
          try {
            final idToken = await user.getIdToken();
            http.post(
              Uri.parse('https://mindaprice-backend.onrender.com/users/register-location'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: '{"locationTopic":"$topicName","lat":$_lat,"lon":$_lon,"locationName":"$displayLocation"}',
            ).then((r) => debugPrint('register-location: ${r.statusCode}'))
             .catchError((e) => debugPrint('register-location error: $e'));
          } catch (e) {
            debugPrint('register-location token error: $e');
          }
        }
      }

      // Fetch dynamic weather now that we have the coordinates
      loadMiniWeather(lat: _lat, lon: _lon);
      
    } catch (_) {
      if (!mounted) return;
      setState(() => locationText = "Location unavailable");
    }
  }

  Future<void> loadMiniWeather({double? lat, double? lon}) async {
    try {
      final data = await WeatherService.fetchWeatherAdvisory(lat: lat, lon: lon);

      if (!mounted) return;
      setState(() {
        miniTemp = (data["weather"]["temperature"] as num).toDouble();
        miniRainProb =
            (data["weather"]["precipitation_probability"] as num).toInt();
        miniWindSpeed = (data["weather"]["wind_speed"] as num).toDouble();
        miniAdvisory = data["advisory"] ?? "No advisory available";
      });

      // Fetch timestamp from Cache for UI
      final cacheKey = "weather_${_lat?.toStringAsFixed(2)}_${_lon?.toStringAsFixed(2)}";
      final cached = await CacheService.getCachedData(CacheService.weatherBoxName, cacheKey);
      if (cached != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(cached['timestamp']);
        if (!mounted) return;
        setState(() {
          weatherTimestamp = "Last updated: ${DateFormat('jm').format(dt)}";
        });
      }
    } catch (_) {
      if (!mounted) return;
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
                  color: Colors.white.withValues(alpha: 0.45),
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
                    if (weatherTimestamp.isNotEmpty)
                      Text(
                        weatherTimestamp,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => loadMiniWeather(lat: _lat, lon: _lon),
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
              color: Colors.white.withValues(alpha: 0.55),
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
      body: Column(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                "Offline Mode - Viewing Cached Data",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
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
                  if (accountType == 'farmer') buildMiniWeatherCard(),
                  const SizedBox(height: 26),
                  buildFeatureCard(
                    icon: Icons.storefront_outlined,
                    title: "Market Prices",
                    subtitle:
                        "Browse agricultural product pricing and marketplace updates.",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PriceScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  buildFeatureCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: "Messenger",
                    subtitle: "Chat in real time with other users and admins in the app.",
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
                  if (accountType == 'farmer')
                    buildFeatureCard(
                      icon: Icons.psychology_outlined,
                      title: "AI Advisor (Minda)",
                      subtitle: "Get personalized agricultural advice from our AI expert.",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AiAdvisorScreen()),
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  buildFeatureCard(
                    icon: Icons.eco_outlined,
                    title: "Farming Advisory",
                    subtitle: "View weather-based guidance and admin broadcast advisories.",
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
        ],
      ),
    ),
  );
}
}