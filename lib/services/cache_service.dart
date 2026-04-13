import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String weatherBoxName = 'weather_cache';
  static const String priceBoxName = 'price_cache';
  static const String advisoryBoxName = 'advisory_cache';

  /// Saves any JSON-compatible data with a timestamp.
  static Future<void> cacheData(String boxName, String key, dynamic data) async {
    final box = await Hive.openBox(boxName);
    await box.put(key, {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Retrieves cached data if it exists.
  static Future<Map<String, dynamic>?> getCachedData(String boxName, String key) async {
    final box = await Hive.openBox(boxName);
    final cached = box.get(key);
    if (cached == null) return null;
    
    return Map<String, dynamic>.from(cached as Map);
  }

  /// Clears 7 days old data specifically for advisories as requested.
  static Future<void> performMaintenance() async {
    final box = await Hive.openBox(advisoryBoxName);
    final now = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysInMs = 7 * 24 * 60 * 60 * 1000;

    final keysToDelete = [];
    for (var key in box.keys) {
      final item = box.get(key);
      if (item is Map && item['timestamp'] != null) {
        if (now - (item['timestamp'] as int) > sevenDaysInMs) {
          keysToDelete.add(key);
        }
      }
    }

    for (var key in keysToDelete) {
      await box.delete(key);
    }
  }
}
