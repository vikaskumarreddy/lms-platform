import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local offline caching of JSON data (courses, lessons, profile, etc.)
/// in student mobile storage so retrieved data is reused until changed.
class LocalCacheService {
  static final LocalCacheService instance = LocalCacheService._internal();
  LocalCacheService._internal();

  static const String _kCachePrefix = 'app_cache_';
  static const String _kCacheMetaPrefix = 'app_cache_meta_';

  /// Saves JSON-encodable data locally with a timestamp
  Future<void> save(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      await prefs.setString('$_kCachePrefix$key', jsonString);
      await prefs.setInt('$_kCacheMetaPrefix${key}_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignored - caching failure should never crash the app
    }
  }

  /// Retrieves cached JSON data. Returns null if not cached.
  Future<dynamic> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_kCachePrefix$key');
      if (jsonString == null || jsonString.isEmpty) return null;
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }

  /// Checks if a cache entry exists
  Future<bool> has(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_kCachePrefix$key');
    } catch (e) {
      return false;
    }
  }

  /// Returns the timestamp (milliseconds since epoch) when the cache was saved
  Future<int?> getCacheTime(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_kCacheMetaPrefix${key}_time');
    } catch (e) {
      return null;
    }
  }

  /// Removes a specific cached key
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kCachePrefix$key');
      await prefs.remove('$_kCacheMetaPrefix${key}_time');
    } catch (e) {}
  }

  /// Clears all cached data (useful on logout)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_kCachePrefix) || k.startsWith(_kCacheMetaPrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {}
  }
}
