import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Cloudinary configuration
  static const String cloudName = 'dfdngxznn';
  static const String uploadPreset = 'mindaprice_profile_pictures';

  /// Uploads an image to Cloudinary using the REST API.
  /// This bypasses the old 'cloudinary_public' package which does not support null safety.
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
        print('Cloudinary Upload Failed (${response.statusCode}): ${String.fromCharCodes(responseData)}');
        return null;
      }
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }
}
