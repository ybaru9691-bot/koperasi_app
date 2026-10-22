import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants/api_endpoints.dart';

/// 🏷️ Model Semantic Versioning berbasis perbandingan numerik (Integer).
/// Mencegah kesalahan logika perbandingan string (misal: "1.9.0" vs "1.10.0").
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  /// Parsing string versi menjadi representasi numerik aman.
  /// Mendukung format:
  /// - "1.2.3"
  /// - "v1.2.3"
  /// - "1.2.3+4" (dengan build number)
  /// - "1.2.3-beta.1" (dengan suffix tag)
  /// - "1.2" atau "1"
  factory SemanticVersion.parse(String versionStr) {
    if (versionStr.trim().isEmpty) {
      return const SemanticVersion(major: 0, minor: 0, patch: 0);
    }

    try {
      String clean = versionStr.trim().toLowerCase();

      // Hapus prefix 'v' jika ada (contoh: "v1.0.5")
      if (clean.startsWith('v')) {
        clean = clean.substring(1).trim();
      }

      // Ambil build number (+) jika ada
      int buildNumber = 0;
      if (clean.contains('+')) {
        final plusParts = clean.split('+');
        clean = plusParts[0];
        if (plusParts.length > 1) {
          buildNumber = int.tryParse(plusParts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
      }

      // Hapus pre-release suffix (-) jika ada (contoh: "1.0.0-rc1")
      if (clean.contains('-')) {
        clean = clean.split('-')[0];
      }

      final parts = clean.split('.');
      final major = parts.isNotEmpty
          ? (int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          : 0;
      final minor = parts.length > 1
          ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          : 0;
      final patch = parts.length > 2
          ? (int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          : 0;

      return SemanticVersion(
        major: major,
        minor: minor,
        patch: patch,
        build: buildNumber,
      );
    } catch (e) {
      debugPrint('[SemanticVersion] Gagal parse versi "$versionStr": $e');
      return const SemanticVersion(major: 0, minor: 0, patch: 0);
    }
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool isLowerThan(SemanticVersion other) => compareTo(other) < 0;
  bool isGreaterThan(SemanticVersion other) => compareTo(other) > 0;
  bool isAtLeast(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build;

  @override
  int get hashCode =>
      major.hashCode ^ minor.hashCode ^ patch.hashCode ^ build.hashCode;

  @override
  String toString() =>
      '$major.$minor.$patch${build > 0 ? '+$build' : ''}';
}

/// 📦 Model data informasi versi aplikasi dari API Backend
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String minVersion;
  final bool forceUpdate;
  final String downloadUrl;
  final String releaseNotes;

  /// Apakah terdapat versi baru atau versi di bawah batas minimum
  final bool shouldUpdate;

  /// Apakah update bersifat WAJIB (Force Update) sehingga user tidak boleh melewati dialog
  final bool isMandatory;

  /// Apakah versi saat ini di bawah minimum yang diizinkan server
  final bool isBelowMinVersion;

  /// Apakah ada versi lebih baru di server
  final bool hasNewerVersion;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minVersion,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.shouldUpdate,
    required this.isMandatory,
    required this.isBelowMinVersion,
    required this.hasNewerVersion,
  });

  @override
  String toString() {
    return 'AppUpdateInfo(current: $currentVersion, latest: $latestVersion, min: $minVersion, '
        'forceUpdate: $forceUpdate, isMandatory: $isMandatory, shouldUpdate: $shouldUpdate)';
  }
}

/// 🚀 Service Pengelola Pengecekan Versi Aplikasi & Force Update
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Default timeout 4 detik untuk request pengecekan versi
  static const Duration defaultTimeout = Duration(seconds: 4);

  /// Default Play Store / Download URL jika dari backend kosong
  static const String defaultDownloadUrl =
      'https://play.google.com/store/apps/details?id=com.koperasi.pelita';

  /// Memanggil endpoint GET /api/app-version untuk memeriksa update aplikasi.
  ///
  /// **PENTING (Safety Guaranteed)**:
  /// - Fungsi ini dibungkus try-catch ketat dan timeout.
  /// - Jika koneksi timeout, offline, atau server error, fungsi mengembalikan `null`
  ///   sehingga aplikasi tidak macet/freeze dan dapat tetap melanjutkan alur normal.
  Future<AppUpdateInfo?> checkUpdate({
    String? customEndpoint,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      // 1. Ambil versi aplikasi lokal saat ini via package_info_plus
      String currentVersionStr = '1.0.0';
      int currentBuildNumber = 1;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        if (packageInfo.version.trim().isNotEmpty) {
          currentVersionStr = packageInfo.version.trim();
        }
        currentBuildNumber = int.tryParse(packageInfo.buildNumber.trim()) ?? 1;
      } catch (e) {
        debugPrint('[AppUpdateService] Peringatan: Gagal membaca PackageInfo: $e (pakai fallback $currentVersionStr)');
      }

      // 2. Siapkan URL endpoint versi (mengirimkan current_version sebagai query param)
      final baseUri = Uri.parse(customEndpoint ?? ApiEndpoints.appVersion);
      final queryParams = Map<String, String>.from(baseUri.queryParameters);
      queryParams['current_version'] = currentVersionStr;
      final uri = baseUri.replace(queryParameters: queryParams);

      debugPrint('[AppUpdateService] Memeriksa versi aplikasi ke: $uri (Versi Lokal: $currentVersionStr+$currentBuildNumber)');

      // 3. Request ke backend dengan timeout ketat
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        debugPrint('[AppUpdateService] Server merespon status non-200: ${response.statusCode}. Melewati pengecekan.');
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[AppUpdateService] Respons server bukan Map JSON yang valid.');
        return null;
      }

      // 4. Ekstraksi data versi (Mendukung wrapper Laravel "data" maupun direct map)
      final dynamic rawData = decoded['data'] ?? decoded;
      if (rawData is! Map<String, dynamic>) {
        debugPrint('[AppUpdateService] Objek data versi tidak ditemukan.');
        return null;
      }

      final String latestVersionStr = (rawData['latest_version'] ??
              rawData['latestVersion'] ??
              rawData['version'] ??
              currentVersionStr)
          .toString()
          .trim();

      final String minVersionStr = (rawData['min_version'] ??
              rawData['minVersion'] ??
              rawData['minimum_version'] ??
              latestVersionStr)
          .toString()
          .trim();

      final bool forceUpdateServer = rawData['force_update'] == true ||
          rawData['force_update'] == 1 ||
          rawData['force_update'] == 'true' ||
          rawData['forceUpdate'] == true ||
          rawData['is_force_update'] == true;

      final String rawDownloadUrl = (rawData['download_url'] ??
              rawData['downloadUrl'] ??
              rawData['update_url'] ??
              rawData['url'] ??
              '')
          .toString()
          .trim();
      final String downloadUrl = rawDownloadUrl.isNotEmpty ? rawDownloadUrl : defaultDownloadUrl;

      final String releaseNotes = (rawData['release_notes'] ??
              rawData['releaseNotes'] ??
              rawData['changelog'] ??
              rawData['notes'] ??
              rawData['description'] ??
              'Pembaruan performa dan peningkatan stabilitas sistem koperasi.')
          .toString()
          .trim();

      // 5. Perbandingan versi berbasis Semantic Versioning (Integer)
      final currentVer = SemanticVersion.parse(currentVersionStr);
      final latestVer = SemanticVersion.parse(latestVersionStr);
      final minVer = SemanticVersion.parse(minVersionStr);

      final bool hasNewerVersion = currentVer.isLowerThan(latestVer);
      final bool isBelowMinVersion = currentVer.isLowerThan(minVer);

      // Mandatory jika server meminta force_update ATAU versi lokal di bawah min_version
      final bool isMandatory = isBelowMinVersion || (hasNewerVersion && forceUpdateServer);
      final bool shouldUpdate = hasNewerVersion || isBelowMinVersion;

      final updateInfo = AppUpdateInfo(
        currentVersion: currentVersionStr,
        latestVersion: latestVersionStr,
        minVersion: minVersionStr,
        forceUpdate: forceUpdateServer,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        shouldUpdate: shouldUpdate,
        isMandatory: isMandatory,
        isBelowMinVersion: isBelowMinVersion,
        hasNewerVersion: hasNewerVersion,
      );

      debugPrint('[AppUpdateService] Hasil evaluasi: $updateInfo');
      return updateInfo;
    } on TimeoutException {
      debugPrint('[AppUpdateService] Koneksi timeout saat cek versi. Melanjutkan aplikasi secara normal.');
      return null;
    } on SocketException catch (e) {
      debugPrint('[AppUpdateService] Jaringan tidak dapat diakses (SocketException): $e. Melanjutkan alur normal.');
      return null;
    } on HttpException catch (e) {
      debugPrint('[AppUpdateService] Kesalahan HTTP: $e. Melanjutkan alur normal.');
      return null;
    } on FormatException catch (e) {
      debugPrint('[AppUpdateService] Gagal decode respons JSON: $e. Melanjutkan alur normal.');
      return null;
    } catch (e, stack) {
      debugPrint('[AppUpdateService] Exception tidak terduga pada pengecekan versi: $e\n$stack');
      return null;
    }
  }
}
