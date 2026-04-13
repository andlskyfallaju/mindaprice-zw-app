import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../services/notification_service.dart';
import '../services/weather_service.dart';
import 'advisory_archive_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _isGeneratingAI = false;

  final String baseUrl = "https://mindaprice-backend.onrender.com";

  bool _isLoadingWeather = true;
  String weatherAdvisory = "";
  double? temperature;
  int? rainProbability;
  double? precipitation;
  double? windSpeed;

  String userRole = "user";
  String accountType = "farmer";
  double? _lat;
  double? _lon;
  String _locationName = "your area";
  String _currentTopicName = "";

  @override
  void initState() {
    super.initState();
    _fetchLocationThenWeather();
    loadUserRole();
    WeatherService.weatherNotifier.addListener(_onWeatherUpdated);
  }

  @override
  void dispose() {
    WeatherService.weatherNotifier.removeListener(_onWeatherUpdated);
    _controller.dispose();
    super.dispose();
  }

  void _onWeatherUpdated() {
    final data = WeatherService.weatherNotifier.value;
    if (data == null || !mounted) return;

    setState(() {
      temperature = (data["weather"]["temperature"] as num).toDouble();
      rainProbability = (data["weather"]["precipitation_probability"] as num).toInt();
      precipitation = (data["weather"]["precipitation"] as num).toDouble();
      windSpeed = (data["weather"]["wind_speed"] as num).toDouble();
      weatherAdvisory = data["advisory"] ?? "";
      _isLoadingWeather = false;
    });
  }

  Future<void> _fetchLocationThenWeather() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        loadWeatherAdvisory();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        loadWeatherAdvisory();
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        loadWeatherAdvisory();
        return;
      }

      _lat = pos.latitude;
      _lon = pos.longitude;

      // Resolve human-readable location name
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final p = placemarks.isNotEmpty ? placemarks.first : null;
        final city = p?.locality ?? p?.subAdministrativeArea ?? p?.administrativeArea ?? 'UnknownCity';
        final country = p?.country ?? 'UnknownCountry';
        if (p != null) {
          _locationName = "$city, $country";
          _currentTopicName = "advisories_${city.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_${country.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}";
        }
      } catch (_) {}

      if (mounted) {
        setState(() {}); // trigger rebuild for the bulletin board stream
      }
      
      loadWeatherAdvisory(lat: _lat, lon: _lon);
    } catch (_) {
      loadWeatherAdvisory();
    }
  }

  Future<void> loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      if (!mounted) return;
      setState(() {
        userRole = (doc.data()?['role'] ?? 'user').toString();
        accountType = (doc.data()?['accountType'] ?? 'farmer').toString().toLowerCase();
      });
    }
  }

  Future<void> loadWeatherAdvisory({double? lat, double? lon}) async {
    try {
      final data = await WeatherService.fetchWeatherAdvisory(lat: lat, lon: lon);

      if (!mounted) return;
      setState(() {
        temperature = (data["weather"]["temperature"] as num).toDouble();
        rainProbability =
            (data["weather"]["precipitation_probability"] as num).toInt();
        precipitation = (data["weather"]["precipitation"] as num).toDouble();
        windSpeed = (data["weather"]["wind_speed"] as num).toDouble();
        weatherAdvisory = data["advisory"] ?? "";
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        weatherAdvisory = "Failed to load weather advisory.";
        _isLoadingWeather = false;
      });
    }
  }

  IconData getWeatherIcon() {
    if (rainProbability != null && rainProbability! >= 70) {
      return Icons.thunderstorm_outlined;
    }
    if (rainProbability != null && rainProbability! >= 40) {
      return Icons.cloud_outlined;
    }
    if (windSpeed != null && windSpeed! >= 20) {
      return Icons.air;
    }
    if (temperature != null && temperature! >= 30) {
      return Icons.wb_sunny_outlined;
    }
    return Icons.wb_cloudy_outlined;
  }

  Future<void> sendAdvisory() async {
    final message = _controller.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message cannot be empty")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final idToken = await user.getIdToken(true);

      final response = await http.post(
        Uri.parse("$baseUrl/advisories/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.body}");
      }

      await NotificationService.showNotification(
        title: "Farming Advisory",
        body: message,
        notificationType: 'advisory',
        payload: jsonEncode({"type": "advisory"}),
      );

      _controller.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Advisory sent successfully 🚀")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send advisory: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> generateAIDraft() async {
    setState(() => _isGeneratingAI = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final idToken = await user.getIdToken(true);

      // Pass the current weather readings so the AI knows the exact context without re-fetching
      final weatherOverrides = (temperature != null && rainProbability != null && windSpeed != null) 
          ? {
              "temp": temperature,
              "rain": precipitation ?? 0.0,
              "wind": windSpeed,
            }
          : null;

      final response = await http.post(
        Uri.parse("$baseUrl/advisories/ai-draft"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "location": _locationName,
          "lat": _lat,
          "lon": _lon,
          "weather": weatherOverrides,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.body}");
      }
      
      final data = jsonDecode(response.body);
      final draft = data["result"] ?? data["advisoryDraft"] ?? "";
      
      if (draft.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _controller.text = draft;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("AI Draft generated successfully ✨")),
        );
      } else {
         throw Exception("Received empty draft from AI.");
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate AI draft: $e")),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Widget buildWeatherSection() {
    if (_isLoadingWeather) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [Colors.green.shade200, Colors.green.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(getWeatherIcon(), size: 34, color: Colors.black87),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  "Live Weather Advisory",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildWeatherStat(
                  icon: Icons.thermostat_outlined,
                  label: "Temp",
                  value: temperature != null
                      ? "${temperature!.toStringAsFixed(1)}°C"
                      : "--",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildWeatherStat(
                  icon: Icons.grain_outlined,
                  label: "Rain",
                  value: rainProbability != null ? "$rainProbability%" : "--",
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: buildWeatherStat(
                  icon: Icons.water_drop_outlined,
                  label: "Rainfall",
                  value: precipitation != null
                      ? "${precipitation!.toStringAsFixed(1)} mm"
                      : "--",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildWeatherStat(
                  icon: Icons.air_outlined,
                  label: "Wind",
                  value: windSpeed != null
                      ? "${windSpeed!.toStringAsFixed(1)} km/h"
                      : "--",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weatherAdvisory,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => loadWeatherAdvisory(lat: _lat, lon: _lon),
              icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
              label: const Text("Refresh", style: TextStyle(color: Colors.black87)),
            ),
          )
        ],
      ),
    );
  }

  Widget buildWeatherStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdminSenderSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Send Manual Advisory",
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              if (_isGeneratingAI)
                const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              // AI Assist button removed as requested
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Broadcast a farming update to all subscribed users.",
            style: GoogleFonts.montserrat(
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Type your advisory message here...",
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _isSending
              ? const Center(child: CircularProgressIndicator())
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sendAdvisory,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text("Send Advisory"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget buildBulletinBoard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Advisory Bulletin Board",
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Latest farming updates sent by admins.",
            style: GoogleFonts.montserrat(
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('advisories')
                .where('createdAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))))
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs ?? [];

              final docs = allDocs.where((doc) {
                final data = Map<String, dynamic>.from(doc.data() as Map);
                final source = data['source']?.toString();
                final topic = data['topic']?.toString();

                if (source == 'manual') return true;
                if (_currentTopicName.isNotEmpty && topic == _currentTopicName) return true;
                return false;
              }).toList();

              if (docs.isEmpty) {
                return Text(
                  "No advisories yet.",
                  style: GoogleFonts.montserrat(color: Colors.black54),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = Map<String, dynamic>.from(doc.data() as Map);
                  final message = (data['message'] ?? '').toString();
                  final ts = data['createdAt'];

                  String dateText = "";
                  if (ts != null && ts is Timestamp) {
                    final dt = ts.toDate();
                    dateText =
                        "${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (dateText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            dateText,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white60 
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdvisoryArchiveScreen(currentTopicName: _currentTopicName),
                  ),
                );
              },
              icon: const Icon(Icons.history_toggle_off),
              label: const Text("View Past Advisories"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: Colors.orange.shade800),
                foregroundColor: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole == "admin";

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          automaticallyImplyLeading: false,
          elevation: 2,
          title: Text(
            "Farming Advisory",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              if (accountType == 'farmer' || isAdmin) buildWeatherSection(),
              const SizedBox(height: 20),
              if (isAdmin) buildAdminSenderSection(),
              if (!isAdmin) buildBulletinBoard(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}