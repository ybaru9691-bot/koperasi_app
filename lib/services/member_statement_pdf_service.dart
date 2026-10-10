import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';

/// Service untuk memuat data Lembar Buku Saham & Deviden Anggota serta Export PDF
class MemberStatementPdfService {
  static final MemberStatementPdfService _instance = MemberStatementPdfService._internal();
  factory MemberStatementPdfService() => _instance;
  MemberStatementPdfService._internal();

  /// Definisi header kolom baku (14 Sub-Kolom Sesuai Formulir Fisik Audit CUM Pelita):
  /// Tanggal | No. Bukti | Setoran (SW, SS, SP) | Penarikan (SW, SS, SP) | Saldo (SW, SS, SP) | TOTAL SAHAM | JASA | DEVIDEN
  static const List<String> tableHeaders = [
    'Tanggal',
    'No. Bukti',
    'Setoran SW',
    'Setoran SS',
    'Setoran SP',
    'Penarikan SW',
    'Penarikan SS',
    'Penarikan SP',
    'Saldo SW',
    'Saldo SS',
    'Saldo SP',
    'TOTAL SAHAM',
    'JASA',
    'DEVIDEN',
  ];

  static final NumberFormat formatCurrency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat formatDecimal = NumberFormat.decimalPattern('id_ID');

  /// Mapping Array Cell (14 Nilai Sub-Kolom):
  /// Menghasilkan baris sel array sesuai urutan formulir fisik audit
  static List<String> mapRowCells(Map<String, dynamic> row, {bool showCurrencySymbol = false}) {
    final formatter = showCurrencySymbol ? formatCurrency : formatDecimal;

    final String tgl = (row['transaction_date'] ?? row['tgl'] ?? row['date'] ?? '').toString();
    final String noBukti = (row['voucher_no'] ?? row['no_bukti'] ?? '').toString();

    final num setorSw = (row['setoran_sw'] ?? row['setor_sw'] ?? 0) as num;
    final num setorSs = (row['setoran_ss'] ?? row['setor_ss'] ?? 0) as num;
    final num setorSp = (row['setoran_sp'] ?? row['setor_sp'] ?? 0) as num;

    final num tarikSw = (row['penarikan_sw'] ?? row['tarik_sw'] ?? 0) as num;
    final num tarikSs = (row['penarikan_ss'] ?? row['tarik_ss'] ?? 0) as num;
    final num tarikSp = (row['penarikan_sp'] ?? row['tarik_sp'] ?? 0) as num;

    final num saldoSw = (row['saldo']?['sw'] ?? row['saldo_sw'] ?? 0) as num;
    final num saldoSs = (row['saldo']?['ss'] ?? row['saldo_ss'] ?? 0) as num;
    final num rawSaldoSp = (row['saldo']?['sp'] ?? row['saldo_sp'] ?? 0) as num;
    // Saldo SP: tidak boleh 0, default Rp 200.000 jika kosong/0
    final num saldoSp = rawSaldoSp > 0 ? rawSaldoSp : 200000;

    final num rawTotalSaham = (row['total_saham'] ?? (saldoSw + saldoSs + saldoSp)) as num;
    final num jasa = (row['jasa_saham'] ?? row['jasa'] ?? 0) as num;
    final num deviden = (row['deviden'] ?? 0) as num;

    return [
      tgl,
      noBukti,
      setorSw > 0 ? formatter.format(setorSw) : '',
      setorSs > 0 ? formatter.format(setorSs) : '',
      setorSp > 0 ? formatter.format(setorSp) : '',
      tarikSw > 0 ? formatter.format(tarikSw) : '',
      tarikSs > 0 ? formatter.format(tarikSs) : '',
      tarikSp > 0 ? formatter.format(tarikSp) : '',
      formatter.format(saldoSw),
      formatter.format(saldoSs),
      formatter.format(saldoSp), // Saldo SP (tidak boleh 0, default 200.000)
      formatter.format(rawTotalSaham),
      jasa > 0 ? formatter.format(jasa) : (jasa == 0 ? '0' : ''),
      deviden > 0 ? formatter.format(deviden) : (deviden == 0 ? '0' : ''),
    ];
  }

  // In-Memory Caches untuk mencegah spam duplicate HTTP request
  static final Map<String, Map<String, dynamic>> _statementCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlightStatementRequests = {};
  static final Map<String, Map<String, dynamic>> _whiteBookCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlightWhiteBookRequests = {};

  static String getStatementCacheKey(int memberId, {int? fiscalYear, int? month, int? year}) {
    return '$memberId-${fiscalYear ?? ""}-${month ?? ""}-${year ?? ""}';
  }

  /// Mengecek dan mengambil data statement dari memori lokal jika sudah pernah di-fetch
  Map<String, dynamic>? getCachedStatement(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
  }) {
    final key = getStatementCacheKey(memberId, fiscalYear: fiscalYear, month: month, year: year);
    return _statementCache[key];
  }

  /// Membersihkan cache statement jika data diperbarui
  void clearStatementCache([int? memberId]) {
    if (memberId != null) {
      _statementCache.removeWhere((k, _) => k.startsWith('$memberId-'));
    } else {
      _statementCache.clear();
    }
  }

  /// Mengambil data statement individual anggota (12 bulan siklus 21-20)
  /// Dilengkapi guard in-flight & cache memory agar tidak spam request
  Future<Map<String, dynamic>> fetchStatement(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final key = getStatementCacheKey(memberId, fiscalYear: fiscalYear, month: month, year: year);

    // 1. Kembalikan data dari cache lokal jika tersedia dan bukan forceRefresh
    if (!forceRefresh && _statementCache.containsKey(key)) {
      debugPrint('[MEMBER_STATEMENT] Menggunakan data cache untuk key: $key');
      return _statementCache[key]!;
    }

    // 2. Cegah duplicate request yang sedang berjalan (in-flight deduplication)
    if (_inFlightStatementRequests.containsKey(key)) {
      debugPrint('[MEMBER_STATEMENT] Request sedang berjalan, menunggu Future yang sama: $key');
      return await _inFlightStatementRequests[key]!;
    }

    final future = _executeFetchStatement(
      memberId,
      fiscalYear: fiscalYear,
      month: month,
      year: year,
    );

    _inFlightStatementRequests[key] = future;

    try {
      final result = await future;
      _statementCache[key] = result;
      return result;
    } finally {
      _inFlightStatementRequests.remove(key);
    }
  }

  Future<Map<String, dynamic>> _executeFetchStatement(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
  }) async {
    final token = await AuthService().getToken();
    final queryParams = <String, String>{};
    if (fiscalYear != null) queryParams['fiscal_year'] = fiscalYear.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse(
      '${AuthService.staticBaseUrl}/manager/members/$memberId/dividend-statement',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Map<String, dynamic>.from(body['data'] ?? {});
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Gagal memuat lembar buku saham (HTTP ${response.statusCode}).');
    }
  }

  /// Membuka download file PDF Slip Lembar Buku Saham individual 1 halaman A4
  Future<String> exportPdf(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
    String? memberName,
  }) async {
    final token = await AuthService().getToken();
    final String baseUrl = AuthService.staticBaseUrl;
    final String tokenParam = (token != null && token.isNotEmpty) ? '&token=$token' : '';
    final String fyParam = fiscalYear != null ? '&fiscal_year=$fiscalYear' : '';
    final String mParam = month != null ? '&month=$month' : '';
    final String yParam = year != null ? '&year=$year' : '';

    final String downloadUrl = '$baseUrl/manager/members/$memberId/dividend-statement/export-pdf?$tokenParam$fyParam$mParam$yParam';

    debugPrint('[MEMBER_STATEMENT_PDF] Triggering download: $downloadUrl');

    final uri = Uri.parse(downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    return downloadUrl;
  }

  /// Mengambil data statement individual Buku Putih anggota (12 bulan siklus 21-20)
  Future<Map<String, dynamic>> fetchWhiteBookStatement(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
    bool forceRefresh = false,
  }) async {
    final key = getStatementCacheKey(memberId, fiscalYear: fiscalYear, month: month, year: year);

    if (!forceRefresh && _whiteBookCache.containsKey(key)) {
      debugPrint('[WHITE_BOOK_STATEMENT] Menggunakan data cache untuk key: $key');
      return _whiteBookCache[key]!;
    }

    if (_inFlightWhiteBookRequests.containsKey(key)) {
      debugPrint('[WHITE_BOOK_STATEMENT] Request in-flight, menunggu Future yang sama: $key');
      return await _inFlightWhiteBookRequests[key]!;
    }

    final future = _executeFetchWhiteBookStatement(
      memberId,
      fiscalYear: fiscalYear,
      month: month,
      year: year,
    );

    _inFlightWhiteBookRequests[key] = future;

    try {
      final result = await future;
      _whiteBookCache[key] = result;
      return result;
    } finally {
      _inFlightWhiteBookRequests.remove(key);
    }
  }

  Future<Map<String, dynamic>> _executeFetchWhiteBookStatement(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
  }) async {
    final token = await AuthService().getToken();
    final queryParams = <String, String>{};
    if (fiscalYear != null) queryParams['fiscal_year'] = fiscalYear.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse(
      '${AuthService.staticBaseUrl}/members/$memberId/white-book-statement',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Map<String, dynamic>.from(body['data'] ?? {});
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Gagal memuat lembar buku putih (HTTP ${response.statusCode}).');
    }
  }

  /// Membuka download file PDF Slip Lembar Buku Putih individual 1 halaman A4
  Future<String> exportWhiteBookPdf(
    int memberId, {
    int? fiscalYear,
    int? month,
    int? year,
    String? memberName,
  }) async {
    final token = await AuthService().getToken();
    final String baseUrl = AuthService.staticBaseUrl;
    final String tokenParam = (token != null && token.isNotEmpty) ? '&token=$token' : '';
    final String fyParam = fiscalYear != null ? '&fiscal_year=$fiscalYear' : '';
    final String mParam = month != null ? '&month=$month' : '';
    final String yParam = year != null ? '&year=$year' : '';

    final String downloadUrl = '$baseUrl/members/$memberId/white-book-statement/export-pdf?$tokenParam$fyParam$mParam$yParam';

    debugPrint('[WHITE_BOOK_PDF] Triggering download: $downloadUrl');

    final uri = Uri.parse(downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    return downloadUrl;
  }
}