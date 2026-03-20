import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WallpaperType { none, color, image }

class WallpaperService {
  static const String _typeKey = 'chat_wallpaper_type';
  static const String _valueKey = 'chat_wallpaper_value';

  /// Saves a solid color as the chat wallpaper.
  static Future<void> setWallpaperColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'color');
    await prefs.setInt(_valueKey, color.value);
  }

  /// Copies an image to the app container and saves its path as the chat wallpaper.
  static Future<void> setWallpaperImage(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save image to app docs directory for persistence
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'chat_wallpaper_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = await imageFile.copy('${appDir.path}/$fileName');

    await prefs.setString(_typeKey, 'image');
    await prefs.setString(_valueKey, savedImage.path);
  }

  /// Resets wallpaper to the default light beige.
  static Future<void> resetWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_typeKey);
    await prefs.remove(_valueKey);
  }

  /// Returns the current wallpaper preference.
  static Future<Map<String, dynamic>> getWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString(_typeKey) ?? 'none';
    
    if (typeStr == 'color') {
      return {
        'type': WallpaperType.color,
        'value': Color(prefs.getInt(_valueKey) ?? 0xFFE5DDD5),
      };
    } else if (typeStr == 'image') {
      final imagePath = prefs.getString(_valueKey);
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          return {
            'type': WallpaperType.image,
            'value': file,
          };
        }
      }
    }
    
    return {'type': WallpaperType.none, 'value': null};
  }
}
