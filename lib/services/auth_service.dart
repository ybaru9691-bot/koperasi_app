import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_endpoints.dart';
import '../screens/auth/welcome_screen.dart';
import 'api_service.dart';

/// Service untuk autentikasi Laravel Sanctum menggunakan NIK & 6-Digit PIN
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // URL Base API (Production Railway, terpusat di ApiEndpoints)
  static String get _baseUrl => ApiEndpoints.baseUrl;

  static const String _tokenKey = 'access_token';
  static const String _userDataKey = 'user_data';
  static const String _userRoleKey = 'user_role';

  /// Memeriksa apakah token sesi pengguna masih valid & tersimpan di Secure Storage
  Future<bool> isSessionValid() async {
    debugPrint('[AUTH_LOG] Memeriksa status sesi di SecureStorage & SharedPreferences...');
    final String? token = await getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint(
        '[AUTH_LOG] Sesi valid. Bearer Token terdeteksi: ${token.substring(0, token.length > 10 ? 10 : token.length)}...',
      );
      ApiService().setAuthToken(token);
      return true;
    }
    debugPrint('[AUTH_LOG] Sesi tidak ada atau kadaluwarsa.');
    return false;
  }

  /// Mengambil Bearer Token dari Secure Storage atau SharedPreferences
  Future<String?> getToken() async {
    try {
      final String? token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('[AUTH_ERROR] Error membaca token dari Storage: $e');
      return null;
    }
  }

  /// Mengambil Role Pengguna ('admin' vs 'anggota')
  Future<String> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? roleFromPrefs = prefs.getString(_userRoleKey);
      if (roleFromPrefs != null && roleFromPrefs.isNotEmpty) {
        return roleFromPrefs.trim().toLowerCase();
      }

      final String? roleFromStorage = await _storage.read(key: _userRoleKey);
      if (roleFromStorage != null && roleFromStorage.isNotEmpty) {
        return roleFromStorage.trim().toLowerCase();
      }
    } catch (e) {
      debugPrint('[AUTH_ERROR] Error membaca role user: $e');
    }
    return 'anggota';
  }

  /// Memproses Login menggunakan NIK (16 digit) & PIN (6 digit) ke Backend Laravel Sanctum
  Future<Map<String, dynamic>> login({
    required String nik,
    required String pin,
  }) async {
    final String cleanNik = nik.trim();
    final String cleanPin = pin.trim();
    final String maskedPin = '*' * cleanPin.length;
    final Uri loginUri = Uri.parse('$_baseUrl/login');

    debugPrint('===========================================================');
    debugPrint('[AUTH_LOG] Step 1: Memulai Request Login Anggota Koperasi');
    debugPrint('[AUTH_LOG] Target URL : $loginUri');
    debugPrint('[AUTH_LOG] Input NIK   : $cleanNik');
    debugPrint('[AUTH_LOG] Input PIN   : $maskedPin (${cleanPin.length} Digit)');
    debugPrint('===========================================================');

    try {
      debugPrint('[AUTH_LOG] Step 2: Mengirim HTTP POST Request ke Laravel...');
      final response = await http
          .post(
            loginUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'nik': cleanNik,
              'pin': cleanPin,
              'password': cleanPin,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[AUTH_LOG] Step 3: Respon HTTP Diterima dari Backend');
      debugPrint('[AUTH_LOG] Status Code : ${response.statusCode}');
      debugPrint('[AUTH_LOG] Raw Body    : ${response.body}');

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && responseData['success'] == true) {
        debugPrint('[AUTH_LOG] Step 4: Autentikasi NIK & PIN Berhasil!');
        final data = responseData['data'];
        final String? token =
            data != null ? data['access_token'] as String? : null;

        if (token != null && token.isNotEmpty) {
          // Extract User Role ('admin' / 'anggota')
          final dynamic rawRole = data['user']?['role'] ?? data['role'] ?? 'anggota';
          final String userRole = rawRole.toString().trim().toLowerCase();

          // Print Log Role Tersimpan
          // ignore: avoid_print
          print("DEBUG ROLE TERSIMPAN: $userRole");
          debugPrint('[AUTH_LOG] Step 5: Menyimpan Role [$userRole] & Token ke SharedPreferences & SecureStorage...');

          // 1. Simpan ke FlutterSecureStorage
          await _storage.write(key: _tokenKey, value: token);
          await _storage.write(key: _userRoleKey, value: userRole);

          if (data['user'] != null) {
            await _storage.write(
              key: _userDataKey,
              value: jsonEncode(data['user']),
            );
          }

          // 2. Simpan ke SharedPreferences (Syarat Pemisahan Role Dashboard)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_userRoleKey, userRole);

          ApiService().setAuthToken(token);
          debugPrint(
            '[AUTH_LOG] Step 6: Selesai! Login NIK & PIN Berhasil Terverifikasi.',
          );
          debugPrint('===========================================================');

          return {
            'success': true,
            'message': responseData['message'] ?? 'Login Berhasil.',
            'token': token,
            'user': data != null ? data['user'] : null,
            'role': userRole,
          };
        } else {
          debugPrint(
            '[AUTH_ERROR] Token tidak ditemukan dalam respon JSON Laravel.',
          );
        }
      }

      debugPrint(
        '[AUTH_WARNING] Login Gagal: ${responseData['message'] ?? 'NIK atau PIN salah.'}',
      );
      debugPrint('===========================================================');

      return {
        'success': false,
        'message': responseData['message'] ??
            'Nomor NIK atau PIN 6-digit yang Anda masukkan tidak sesuai.',
      };
    } on SocketException catch (e) {
      debugPrint(
        '[AUTH_ERROR] SocketException: Gagal koneksi IP $_baseUrl -> $e',
      );
      debugPrint('===========================================================');
      return {
        'success': false,
        'message':
            'Gagal terhubung ke server Laravel ($_baseUrl). Pastikan server aktif (php artisan serve) dan periksa jaringan internet Anda.',
      };
    } on TimeoutException catch (e) {
      debugPrint(
        '[AUTH_ERROR] TimeoutException: Server tidak merespon dalam 30 detik -> $e',
      );
      debugPrint('===========================================================');
      return {
        'success': false,
        'message':
            'Waktu koneksi ke server habis (Timeout). Silakan coba lagi.',
      };
    } catch (e, stackTrace) {
      debugPrint('[AUTH_ERROR] Unexpected Exception: $e');
      debugPrint('[AUTH_ERROR] StackTrace: $stackTrace');
      debugPrint('===========================================================');
      return {
        'success': false,
        'message': 'Terjadi kesalahan sistem saat mencoba login.',
      };
    }
  }

  /// Helper untuk mendapatkan URL Base yang aktif
  static String get staticBaseUrl => _baseUrl;

  /// Mengambil data user yang tersimpan lokal
  Future<Map<String, dynamic>?> getSavedUser() async {
    try {
      final String? userJson = await _storage.read(key: _userDataKey);
      if (userJson != null && userJson.isNotEmpty) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }

      final prefs = await SharedPreferences.getInstance();
      final String? userJsonPrefs = prefs.getString(_userDataKey);
      if (userJsonPrefs != null && userJsonPrefs.isNotEmpty) {
        return jsonDecode(userJsonPrefs) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AUTH_ERROR] Error membaca data user: $e');
    }
    return null;
  }

  /// Menyimpan/memperbarui data user ke Storage
  Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      final userJson = jsonEncode(user);
      await _storage.write(key: _userDataKey, value: userJson);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, userJson);
    } catch (e) {
      debugPrint('[AUTH_ERROR] Error menyimpan data user: $e');
    }
  }

  /// Memproses Logout (Menghapus Token, Role, & Data Sesi)
  Future<void> logout() async {
    debugPrint('[AUTH_LOG] Menghapus sesi, role, & token dari Storage...');
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userDataKey);
      await _storage.delete(key: _userRoleKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      debugPrint('[AUTH_LOG] Sesi berhasil dihapus.');
    } catch (e) {
      debugPrint('[AUTH_ERROR] Error saat logout: $e');
    }
  }

  /// Helper Global untuk Alur Logout Lengkap dengan Indikator Loading & Navigasi
  static Future<void> handleLogout(BuildContext context) async {
    // 1. Tampilkan Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF137A43)),
      ),
    );

    // 2. Hapus Cache & Sesi
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint("Error clearing SharedPreferences: $e");
    }

    await AuthService().logout();

    if (!context.mounted) return;

    // 3. Tutup Dialog Loading
    Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    // 4. Navigasi ke WelcomeScreen (Hapus seluruh stack route)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }
}
