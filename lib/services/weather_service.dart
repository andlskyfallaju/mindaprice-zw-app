import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Local backend for emulator testing
  static const String baseUrl = "https://mindaprice-backend.onrender.com";

  static Future<Map<String, dynamic>> fetchWeatherAdvisory({double? lat, double? lon}) async {
    String url = "$baseUrl/weather/advisory";
    if (lat != null && lon != null) {
      url += "?lat=${lat.toStringAsFixed(4)}&lon=${lon.toStringAsFixed(4)}";
    }

    final response = await http.get(
      Uri.parse(url),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load weather advisory");
    }
  }
}