import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SERVIS CACHE LOKAL & PEMBERSIHAN MEMORI UNTUK DATA ANGGOTA KOPERASI
class MemberCacheService {
  static const String _membersCacheKey = 'cached_members_list_v1';
  static const String _lastSyncKey = 'cached_members_last_sync';

  /// 1. Simpan Data Anggota ke Cache SharedPreferences
  static Future<void> saveMembersCache(List<Map<String, dynamic>> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(members);
      await prefs.setString(_membersCacheKey, jsonStr);
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving members cache: $e');
    }
  }

  /// 2. Ambil Data Anggota dari Cache Lokal
  static Future<List<Map<String, dynamic>>?> getMembersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_membersCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading members cache: $e');
    }
    return null;
  }

  /// 3. Hapus Seluruh Cache Aplikasi (Image Cache & SharedPreferences)
  static Future<bool> clearAppCache() async {
    try {
      // A. Bersihkan ImageCache Flutter Memori
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // B. Bersihkan Storage Cache Lokal (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_membersCacheKey);
      await prefs.remove(_lastSyncKey);

      return true;
    } catch (e) {
      debugPrint('Error clearing app cache: $e');
      return false;
    }
  }
}
