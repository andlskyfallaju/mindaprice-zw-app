import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Local backend for emulator testing
  static const String baseUrl = "https://mindaprice-backend.onrender.com";

  static Future<Map<String, dynamic>> fetchWeatherAdvisory() async {
    final response = await http.get(
      Uri.parse("$baseUrl/weather/advisory"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load weather advisory");
    }
  }
}