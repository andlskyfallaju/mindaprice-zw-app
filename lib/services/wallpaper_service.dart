import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as io;

enum WallpaperType { none, color, image }

class WallpaperService {
  static const String _typeKey = 'chat_wallpaper_type';
  static const String _valueKey = 'chat_wallpaper_value';

  static String _getTypeKey(String? chatId) => chatId != null ? 'chat_wallpaper_type_$chatId' : _typeKey;
  static String _getValueKey(String? chatId) => chatId != null ? 'chat_wallpaper_value_$chatId' : _valueKey;

  /// Saves a solid color as the chat wallpaper.
  static Future<void> setWallpaperColor(Color color, {String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getTypeKey(chatId), 'color');
    await prefs.setInt(_getValueKey(chatId), color.toARGB32());
  }

  /// Copies an image to the app container and saves its path as the chat wallpaper.
  static Future<void> setWallpaperImage(dynamic imageFile, {String? chatId}) async {
    if (kIsWeb) return; // Local file persistence not supported on web in this implementation
    
    final prefs = await SharedPreferences.getInstance();
    
    // Save image to app docs directory for persistence
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'chat_wallpaper_${chatId ?? "global"}_${DateTime.now().millisecondsSinceEpoch}.png';
    // Cast to io.File since we know we're not on web
    final savedImage = await (imageFile as io.File).copy('${appDir.path}/$fileName');

    await prefs.setString(_getTypeKey(chatId), 'image');
    await prefs.setString(_getValueKey(chatId), savedImage.path);
  }

  /// Resets wallpaper to the default (global if chatId provided, otherwise none).
  static Future<void> resetWallpaper({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getTypeKey(chatId));
    await prefs.remove(_getValueKey(chatId));
  }

  /// Returns the current wallpaper preference (chat-specific or global fallback).
  static Future<Map<String, dynamic>> getWallpaper({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try chat-specific first, then global
    String typeStr = prefs.getString(_getTypeKey(chatId)) ?? 'none';
    String finalValueKey = _getValueKey(chatId);

    // If chat-specific is none and we have a chatId, fallback to global
    if (typeStr == 'none' && chatId != null) {
      typeStr = prefs.getString(_typeKey) ?? 'none';
      finalValueKey = _valueKey;
    }
    
    if (typeStr == 'color') {
      return {
        'type': WallpaperType.color,
        'value': Color(prefs.getInt(finalValueKey) ?? 0xFFE5DDD5),
      };
    } else if (typeStr == 'image') {
      if (kIsWeb) return {'type': WallpaperType.none, 'value': null};
      
      final imagePath = prefs.getString(finalValueKey);
      if (imagePath != null) {
        final file = io.File(imagePath);
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
