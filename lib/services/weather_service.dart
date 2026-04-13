import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class WeatherService {
  // Local backend for emulator testing
  static const String baseUrl = "https://mindaprice-backend.onrender.com";

  /// Global notifier that any widget can listen to for the latest weather data
  static final ValueNotifier<Map<String, dynamic>?> weatherNotifier = ValueNotifier(null);

  static Future<Map<String, dynamic>> fetchWeatherAdvisory({double? lat, double? lon}) async {
    final cacheKey = "weather_${lat?.toStringAsFixed(2)}_${lon?.toStringAsFixed(2)}";

    try {
      String url = "$baseUrl/weather/advisory";
      if (lat != null && lon != null) {
        url += "?lat=${lat.toStringAsFixed(4)}&lon=${lon.toStringAsFixed(4)}";
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save to cache on success
        await CacheService.cacheData(CacheService.weatherBoxName, cacheKey, data);
        
        // Update global notifier
        weatherNotifier.value = data;
        
        return data;
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      // Return cached data if network fails
      final cached = await CacheService.getCachedData(CacheService.weatherBoxName, cacheKey);
      if (cached != null) {
        final data = Map<String, dynamic>.from(cached['data']);
        
        // Update global notifier even if it's cached data (if it's newer than null)
        if (weatherNotifier.value == null) {
          weatherNotifier.value = data;
        }
        
        return data;
      }
      throw Exception("Failed to load weather: $e");
    }
  }
}