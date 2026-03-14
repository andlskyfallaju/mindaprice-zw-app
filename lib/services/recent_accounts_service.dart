import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentAccountsService {
  static const String _key = 'recent_accounts';

  static Future<void> saveAccount({
    required String uid,
    required String email,
    required String username,
    String photoUrl = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];

    final newAccount = jsonEncode({
      'uid': uid,
      'email': email,
      'username': username,
      'photoUrl': photoUrl,
    });

    final filtered = existing.where((item) {
      final decoded = jsonDecode(item);
      return decoded['email'] != email;
    }).toList();

    filtered.insert(0, newAccount);

    if (filtered.length > 5) {
      filtered.removeLast();
    }

    await prefs.setStringList(_key, filtered);
  }

  static Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];

    return existing
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];

    final filtered = existing.where((item) {
      final decoded = jsonDecode(item);
      return decoded['email'] != email;
    }).toList();

    await prefs.setStringList(_key, filtered);
  }
}