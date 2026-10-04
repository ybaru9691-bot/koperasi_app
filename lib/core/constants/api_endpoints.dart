import 'package:flutter/foundation.dart';

/// 🌐 Konstanta Terpusat URL & Endpoint API Backend Laravel Sanctum
abstract class ApiEndpoints {
  // Base URL Server Backend Laravel
  // Otomatis pakai Railway jika kReleaseMode (hasil flutter build web --release)
  // Otomatis pakai Localhost jika sedang di-run/debug biasa
  static const String productionBaseUrl = 'https://cumpelitaresortdame.up.railway.app/api';
  static const String localBaseUrl = kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api';

  static String get baseUrl => kReleaseMode ? productionBaseUrl : localBaseUrl;

  // --- AUTH ENDPOINTS ---
  static String get login => '$baseUrl/login';
  static String get logout => '$baseUrl/logout';
  static String get me => '$baseUrl/me';

  // --- ANGGOTA ENDPOINTS ---
  static String get members => '$baseUrl/members';
  static String memberDetail(int id) => '$baseUrl/members/$id';

  // --- TRANSAKSI & KAS ENDPOINTS ---
  static String get transactions => '$baseUrl/transactions';
  static String get kasKeluar => '$baseUrl/kas-keluar';
  static String get approvalList => '$baseUrl/approvals';

  // --- KEUANGAN & REPORT ENDPOINTS ---
  static String get dashboardSummary => '$baseUrl/dashboard/summary';
  static String get financialReport => '$baseUrl/reports/financial';
  static String get worksheet => '$baseUrl/reports/worksheet';
}