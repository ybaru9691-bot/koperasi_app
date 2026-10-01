/// 🌐 Konstanta Terpusat URL & Endpoint API Backend Laravel Sanctum
abstract class ApiEndpoints {
  // Base URL Server Backend Laravel
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static const String localBaseUrl = 'http://localhost:8000/api';

  // --- AUTH ENDPOINTS ---
  static const String login = '$baseUrl/login';
  static const String logout = '$baseUrl/logout';
  static const String me = '$baseUrl/me';

  // --- ANGGOTA ENDPOINTS ---
  static const String members = '$baseUrl/members';
  static String memberDetail(int id) => '$baseUrl/members/$id';

  // --- TRANSAKSI & KAS ENDPOINTS ---
  static const String transactions = '$baseUrl/transactions';
  static const String kasKeluar = '$baseUrl/kas-keluar';
  static const String approvalList = '$baseUrl/approvals';

  // --- KEUANGAN & REPORT ENDPOINTS ---
  static const String dashboardSummary = '$baseUrl/dashboard/summary';
  static const String financialReport = '$baseUrl/reports/financial';
  static const String worksheet = '$baseUrl/reports/worksheet';
}
