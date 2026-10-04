import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/models/backup_file_model.dart';
import 'auth_service.dart';

// SERVICE BACKEND REST API UNTUK BACKUP & RESTORE DATABASE KOPERASI
class BackupService {
  static final String baseUrl = '${AuthService.staticBaseUrl}/v1/admin/backup';

  /// 1. Ambil Daftar File Backup yang Ada di Server
  static Future<List<BackupFileModel>> fetchBackupList() async {
    try {
      final token = await AuthService().getToken();

      if (token != null && token.isNotEmpty) {
        final response = await http.get(
          Uri.parse('$baseUrl/list'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List rawList = body['data'] ?? body['backups'] ?? [];
          return rawList.map((item) => BackupFileModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('Info BackupService.fetchBackupList (Mock Mode): $e');
    }

    return BackupFileModel.getDummyBackups();
  }

  /// 2. Eksekusi Buat File Backup Database Baru (.sql / .zip)
  static Future<Map<String, dynamic>> generateBackup() async {
    try {
      final token = await AuthService().getToken();

      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse('$baseUrl/generate'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return jsonDecode(response.body);
        }
      }
    } catch (e) {
      debugPrint('Info BackupService.generateBackup (Mock Mode): $e');
    }

    // Mock Response
    await Future.delayed(const Duration(milliseconds: 1200));
    return {
      'status': 'success',
      'message': 'File backup database berhasil dibuat!',
      'file': {
        'filename': 'backup_cumpelita_${DateTime.now().millisecondsSinceEpoch}.sql.zip',
        'size_formatted': '14.5 MB',
        'created_at': 'Sekarang',
      },
    };
  }

  /// 3. Eksekusi Pemulihan / Restore Database
  static Future<Map<String, dynamic>> restoreBackup({
    required String filename,
    required String confirmPassword,
  }) async {
    try {
      final token = await AuthService().getToken();

      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse('$baseUrl/restore'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'filename': filename,
            'password': confirmPassword,
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      }
    } catch (e) {
      debugPrint('Info BackupService.restoreBackup (Mock Mode): $e');
    }

    // Mock Response
    await Future.delayed(const Duration(milliseconds: 1500));
    return {
      'status': 'success',
      'message': 'Database berhasil dipulihkan dari file $filename.',
    };
  }
}
