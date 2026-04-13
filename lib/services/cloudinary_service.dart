import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  // Cloudinary configuration
  static String get cloudName => dotenv.get('CLOUDINARY_CLOUD_NAME', fallback: '');
  static String get uploadPreset => dotenv.get('CLOUDINARY_UPLOAD_PRESET', fallback: '');

  /// Uploads a profile picture to Cloudinary using the REST API.
  static Future<String?> uploadProfilePicture(String filePath, String userId) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['public_id'] = userId
        ..fields['folder'] = 'profile_pictures'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonResponse = jsonDecode(responseString);
        return jsonResponse['secure_url'] as String;
      } else {
        final responseData = await response.stream.toBytes();
        debugPrint('Cloudinary Upload Failed (${response.statusCode}): ${String.fromCharCodes(responseData)}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary Upload Error: $e');
      return null;
    }
  }

  /// Uploads a chat image to Cloudinary.
  static Future<String?> uploadChatImage(String filePath, String conversationId) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final publicId = '${DateTime.now().millisecondsSinceEpoch}';

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['public_id'] = publicId
        ..fields['folder'] = 'chat_images/$conversationId'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonResponse = jsonDecode(String.fromCharCodes(responseData));
        return jsonResponse['secure_url'] as String;
      } else {
        final responseData = await response.stream.toBytes();
        debugPrint('Cloudinary Chat Upload Failed (${response.statusCode}): ${String.fromCharCodes(responseData)}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary Chat Upload Error: $e');
      return null;
    }
  }
}
