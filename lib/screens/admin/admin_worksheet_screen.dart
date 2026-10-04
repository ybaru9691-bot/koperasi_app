import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class WorksheetAccountItem {
  final String code;
  final String name;
  final String type;
  final double trialDebet;
  final double trialKredit;
  final double adjDebet;
  final double adjKredit;
  final double adjustedTrialDebet;
  final double adjustedTrialKredit;
  final double incomeStatementDebet;
  final double incomeStatementKredit;
  final double balanceSheetDebet;
  final double balanceSheetKredit;
  final bool isIkhtisarRl;

  WorksheetAccountItem({
    required this.code,
    required this.name,
    required this.type,
    required this.trialDebet,
    required this.trialKredit,
    this.adjDebet = 0,
    this.adjKredit = 0,
    required this.adjustedTrialDebet,
    required this.adjustedTrialKredit,
    required this.incomeStatementDebet,
    required this.incomeStatementKredit,
    required this.balanceSheetDebet,
    required this.balanceSheetKredit,
    this.isIkhtisarRl = false,
  });

  factory WorksheetAccountItem.fromJson(Map<String, dynamic> json) {
    // 1. Neraca Saldo Awal (NSA) - Utamakan nsa_debit / nsa_credit dari API
    double tD = (json['nsa_debit'] ?? json['nsa_debet'] ?? json['opening_debit'] ?? json['saldo_awal_debit'] ?? json['trial_debit'] ?? json['trial_debet'] ?? json['saldo_debit'] as num?)?.toDouble() ?? 0.0;
    double tK = (json['nsa_credit'] ?? json['nsa_kredit'] ?? json['opening_credit'] ?? json['saldo_awal_credit'] ?? json['trial_credit'] ?? json['trial_kredit'] ?? json['saldo_credit'] as num?)?.toDouble() ?? 0.0;

    // Bersihkan posisi satu sisi (netting) agar tidak ada angka mutasi kotor di kedua sisi untuk akun kas
    if (tD > 0 && tK > 0) {
      if (tD >= tK) {
        tD = tD - tK;
        tK = 0.0;
      } else {
        tK = tK - tD;
        tD = 0.0;
      }
    }

    // 2. Penyesuaian / Mutasi Periode - Langsung dari API tanpa kalkulasi manual ganda
    double aD = (json['adj_debit'] ?? json['adj_debet'] ?? json['adjustment_debit'] ?? json['penyesuaian_debit'] ?? json['mutasi_debit'] ?? json['mutasi_debet'] as num?)?.toDouble() ?? 0.0;
    double aK = (json['adj_credit'] ?? json['adj_kredit'] ?? json['adjustment_credit'] ?? json['penyesuaian_credit'] ?? json['mutasi_credit'] ?? json['mutasi_kredit'] as num?)?.toDouble() ?? 0.0;
    
    // 3. Neraca Percobaan (Adjusted Trial Balance) - Utamakan dari API
    double atD = (json['adjusted_trial_debit'] ?? json['percobaan_debit'] ?? json['neraca_disesuaikan_debit'] ?? json['adjusted_trial_debet'] ?? json['ns_disesuaikan_debet'] as num?)?.toDouble() ?? 0.0;
    double atK = (json['adjusted_trial_credit'] ?? json['percobaan_credit'] ?? json['neraca_disesuaikan_credit'] ?? json['adjusted_trial_kredit'] ?? json['ns_disesuaikan_kredit'] as num?)?.toDouble() ?? 0.0;

    if (atD == 0.0 && atK == 0.0 && (tD != 0.0 || tK != 0.0 || aD != 0.0 || aK != 0.0)) {
      double netBal = (tD - tK) + (aD - aK);
      if (netBal >= 0) {
        atD = netBal;
        atK = 0.0;
      } else {
        atD = 0.0;
        atK = netBal.abs();
      }
    }

    // 4. Rugi Laba & Neraca
    double isD = (json['income_statement_debit'] ?? json['rugi_laba_debit'] ?? json['income_statement_debet'] ?? json['laba_rugi_debit'] as num?)?.toDouble() ?? 0.0;
    double isK = (json['income_statement_credit'] ?? json['rugi_laba_credit'] ?? json['income_statement_kredit'] ?? json['laba_rugi_credit'] as num?)?.toDouble() ?? 0.0;
    double bsD = (json['balance_sheet_debit'] ?? json['neraca_debit'] ?? json['balance_sheet_debet'] as num?)?.toDouble() ?? 0.0;
    double bsK = (json['balance_sheet_credit'] ?? json['neraca_credit'] ?? json['balance_sheet_kredit'] as num?)?.toDouble() ?? 0.0;

    String code = (json['account_code'] ?? json['code'] ?? '').toString().trim();
    String type = (json['account_type'] ?? json['type'] ?? '').toString().trim().toUpperCase();
    bool isIkhtisar = json['is_ikhtisar_rl'] == true || json['is_system_row'] == true || code == '9900';

    // Konsistensi Kolom Akuntansi:
    // Akun Pendapatan (4xxx) & Beban (5xxx, 6xxx, 7xxx, 8xxx) -> Kolom 4 (Rugi Laba)
    // Akun Harta (1xxx), Kewajiban/Simpanan (2xxx), Modal (3xxx) -> Kolom 5 (Neraca)
    bool isIncomeStatement = type == 'REVENUE' || type == 'EXPENSE' || 
                             type.contains('INCOME') || type.contains('PENDAPATAN') || type.contains('BEBAN') || type.contains('BIAYA') ||
                             code.startsWith('4') || code.startsWith('5') || code.startsWith('6') || code.startsWith('7') || code.startsWith('8');

    if (isIncomeStatement) {
      if (isD == 0.0 && isK == 0.0) {
        isD = atD;
        isK = atK;
      }
      bsD = 0.0;
      bsK = 0.0;
    } else if (!isIkhtisar) {
      if (bsD == 0.0 && bsK == 0.0) {
        bsD = atD;
        bsK = atK;
      }
      isD = 0.0;
      isK = 0.0;
    }

    return WorksheetAccountItem(
      code: code,
      name: (json['account_name'] ?? json['name'] ?? '').toString(),
      type: type,
      trialDebet: tD,
      trialKredit: tK,
      adjDebet: aD,
      adjKredit: aK,
      adjustedTrialDebet: atD,
      adjustedTrialKredit: atK,
      incomeStatementDebet: isD,
      incomeStatementKredit: isK,
      balanceSheetDebet: bsD,
      balanceSheetKredit: bsK,
      isIkhtisarRl: isIkhtisar,
    );
  }
}

/// Typedef agar kompatibel dengan pemanggilan NeracaLajurScreen
typedef NeracaLajurScreen = AdminWorksheetScreen;

class AdminWorksheetScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const AdminWorksheetScreen({super.key, this.onOpenDrawer});

  @override
  State<AdminWorksheetScreen> createState() => _AdminWorksheetScreenState();
}

class _AdminWorksheetScreenState extends State<AdminWorksheetScreen> {
  static const String _prefMonthKey = 'worksheet_selected_month';
  static const String _prefYearKey = 'worksheet_selected_year';
  static const String _prefWeekKey = 'worksheet_selected_week';

  bool _isLoading = true;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  String? _errorMessage;
  List<WorksheetAccountItem> _accounts = [];
  Map<String, dynamic>? _summaryData;
  
  final ScrollController _horizontalScrollController = ScrollController();
  
  String _selectedMonth = DateTime.now().month.toString();
  String _selectedYear = DateTime.now().year.toString();
  String _selectedWeek = 'Semua';

  final List<String> _months = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'
  ];
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  final List<String> _years = ['2023', '2024', '2025', '2026', '2027', '2028', '2029', '2030'];
  final List<String> _weeks = ['Semua', 'M1', 'M2', 'M3', 'M4', 'M5'];

  @override
  void initState() {
    super.initState();
    _initFiltersAndFetch();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  DateTimeRange _calculateDateRange() {
    int y = int.parse(_selectedYear);
    int m = int.parse(_selectedMonth);
    DateTime startDate;
    DateTime endDate;

    if (_selectedWeek == 'Semua') {
      startDate = DateTime(y, m, 1);
      endDate = DateTime(y, m + 1, 0); // Hari terakhir bulan tersebut
    } else {
      int weekNum = int.parse(_selectedWeek.replaceAll('M', ''));
      int startDay = 1;
      int endDay = 7;
      int lastDayOfMonth = DateTime(y, m + 1, 0).day;

      switch (weekNum) {
        case 1:
          startDay = 1;
          endDay = 7;
          break;
        case 2:
          startDay = 8;
          endDay = 14;
          break;
        case 3:
          startDay = 15;
          endDay = 21;
          break;
        case 4:
          startDay = 22;
          endDay = 28;
          break;
        case 5:
        default:
          startDay = 29;
          endDay = lastDayOfMonth;
          break;
      }

      if (endDay > lastDayOfMonth) endDay = lastDayOfMonth;
      if (startDay > lastDayOfMonth) startDay = lastDayOfMonth;

      startDate = DateTime(y, m, startDay);
      endDate = DateTime(y, m, endDay);
    }

    return DateTimeRange(start: startDate, end: endDate);
  }

  Future<void> _initFiltersAndFetch() async {
    try {
      // 1. Coba baca dari URL query parameter jika di web
      String? urlMonth;
      String? urlYear;
      String? urlWeek;
      try {
        final uri = Uri.base;
        urlMonth = uri.queryParameters['month'];
        urlYear = uri.queryParameters['year'];
        urlWeek = uri.queryParameters['week'];
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final savedMonth = urlMonth ?? prefs.getString(_prefMonthKey);
      final savedYear = urlYear ?? prefs.getString(_prefYearKey);
      final savedWeek = urlWeek ?? prefs.getString(_prefWeekKey);

      if (savedMonth != null && _months.contains(savedMonth)) {
        _selectedMonth = savedMonth;
      }
      if (savedYear != null && _years.contains(savedYear)) {
        _selectedYear = savedYear;
      }
      if (savedWeek != null && _weeks.contains(savedWeek)) {
        _selectedWeek = savedWeek;
      }
    } catch (e) {
      debugPrint('Error loading saved worksheet filters: $e');
    }

    if (mounted) {
      _saveFiltersToPreferences();
      _fetchTrialBalance();
    }
  }

  Future<void> _saveFiltersToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefMonthKey, _selectedMonth);
      await prefs.setString(_prefYearKey, _selectedYear);
      await prefs.setString(_prefWeekKey, _selectedWeek);

      // Sinkronkan ke URL query params di browser
      try {
        final currentUri = Uri.base;
        final newParams = Map<String, String>.from(currentUri.queryParameters);
        newParams['month'] = _selectedMonth;
        newParams['year'] = _selectedYear;
        newParams['week'] = _selectedWeek;
        final newUrl = Uri(path: html.window.location.pathname, queryParameters: newParams).toString();
        html.window.history.replaceState(null, '', newUrl);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error saving worksheet filters: $e');
    }
  }

  void _onFilterChanged({String? month, String? year, String? week}) {
    setState(() {
      if (month != null) _selectedMonth = month;
      if (year != null) _selectedYear = year;
      if (week != null) _selectedWeek = week;
    });
    _saveFiltersToPreferences();
    _fetchTrialBalance();
  }

  String _getMonthName(String month) {
    int m = int.tryParse(month) ?? 1;
    return _monthNames[m - 1];
  }

  Future<void> _fetchTrialBalance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();
      final dateRange = _calculateDateRange();
      final startDate = dateRange.start;
      final endDate = dateRange.end;

      final startStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      
      final queryParams = '?start_date=$startStr&end_date=$endStr&month=$_selectedMonth&year=$_selectedYear&week=$_selectedWeek';
      final uri = Uri.parse('${AuthService.staticBaseUrl}/accounting/worksheet$queryParams');
      
      http.Response response;
      try {
        response = await http.get(uri, headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60));
      } catch (_) {
        // Fallback ke endpoint /reports/trial-balance
        final fallbackUri = Uri.parse('${AuthService.staticBaseUrl}/reports/trial-balance$queryParams');
        response = await http.get(fallbackUri, headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60));
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> dataArr = [];
        Map<String, dynamic>? summaryMap;

        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map<String, dynamic>) {
            final inner = decoded['data'] as Map<String, dynamic>;
            summaryMap = inner['summary'] as Map<String, dynamic>?;
            dataArr = (inner['pure_accounts'] as List?) ?? 
                      (inner['accounts'] as List?) ?? 
                      (inner['reports'] as List?) ?? 
                      (inner['data'] as List?) ?? [];
          } else if (decoded['data'] is List) {
            dataArr = decoded['data'] as List;
          } else if (decoded['accounts'] is List) {
            dataArr = decoded['accounts'] as List;
          } else if (decoded['reports'] is List) {
            dataArr = decoded['reports'] as List;
          }
        } else if (decoded is List) {
          dataArr = decoded;
        }

        if (mounted) {
          setState(() {
            _summaryData = summaryMap;
            _accounts = dataArr
                .whereType<Map>()
                .map((e) => WorksheetAccountItem.fromJson(Map<String, dynamic>.from(e)))
                .where((acc) => acc.code != '9900' && !acc.isIkhtisarRl)
                .toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal memuat Neraca Lajur (Code: ${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan koneksi server: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportReport(String type) async {
    final isPdf = type.toLowerCase() == 'pdf';
    if (isPdf && _isExportingPdf) return;
    if (!isPdf && _isExportingExcel) return;

    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    try {
      final dateRange = _calculateDateRange();
      final startDate = dateRange.start;
      final endDate = dateRange.end;

      final startStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Menyiapkan Neraca Lajur (${type.toUpperCase()})...'),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final token = await AuthService().getToken();
      final queryParams = '?month=$_selectedMonth&year=$_selectedYear&period=$_selectedWeek&week=$_selectedWeek&start_date=$startStr&end_date=$endStr';
      final url = '${AuthService.staticBaseUrl}/reports/trial-balance/export/$type$queryParams';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': isPdf
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final mimeType = isPdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        final extension = isPdf ? 'pdf' : 'xlsx';
        final filename = 'Neraca_Lajur_${_selectedYear}_${_selectedMonth}_$_selectedWeek.$extension';

        final blob = html.Blob([response.bodyBytes], mimeType);
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = blobUrl
          ..download = filename;
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mengunduh $filename'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal export Neraca Lajur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _isExportingPdf = false;
          } else {
            _isExportingExcel = false;
          }
        });
      }
    }
  }

  static String _formatNumber(num? val) {
    if (val == null || val == 0 || val.abs() < 0.0001) return "-";
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  static String _formatRupiah(num? val) {
    if (val == null || val == 0 || val.abs() < 0.0001) return "-";
    return "Rp ${_formatNumber(val)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: Builder(
          builder: (btnContext) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: widget.onOpenDrawer ?? () {
              try { Scaffold.of(btnContext).openDrawer(); } catch (_) {}
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Neraca Lajur 10 Kolom (Worksheet)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Koperasi Credit Union CUM Pelita - ${_getMonthName(_selectedMonth)} $_selectedYear ($_selectedWeek)', 
              style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. FILTER HEADER SECTION: [Bulan] [Tahun] | [Semua] [M1] [M2] [M3] [M4] [M5] | [Export PDF] [Export Excel]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Dropdown Bulan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonth,
                        icon: const Icon(Icons.calendar_month, size: 18),
                        items: _months.map((m) => DropdownMenuItem(value: m, child: Text(_getMonthName(m), style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _onFilterChanged(month: val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Dropdown Tahun
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedYear,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _onFilterChanged(year: val);
                          }
                        },
                      ),
                    ),
                  ),
                  
                  // Pemisah vertikal
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  
                  // Pemilihan Pekan Mingguan (Semua, M1, M2, M3, M4, M5)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _weeks.map((w) {
                        final isSelected = _selectedWeek == w;
                        return InkWell(
                          onTap: () {
                            if (_selectedWeek != w) {
                              _onFilterChanged(week: w);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF16213E) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              w,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // Pemisah vertikal
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  
                  // Buttons Export
                  OutlinedButton.icon(
                    icon: _isExportingPdf
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                    label: Text(
                      _isExportingPdf ? 'Menyiapkan PDF...' : 'Export PDF',
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                    onPressed: _isExportingPdf ? null : () => _exportReport('pdf'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      disabledForegroundColor: Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: _isExportingExcel
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
                          )
                        : const Icon(Icons.table_view, color: Colors.green, size: 16),
                    label: Text(
                      _isExportingExcel ? 'Menyiapkan Excel...' : 'Export Excel',
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                    onPressed: _isExportingExcel ? null : () => _exportReport('excel'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      disabledForegroundColor: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null 
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : _buildCustomTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTable() {
    double totalTrialD = 0, totalTrialK = 0;
    double totalAdjD = 0, totalAdjK = 0;
    double totalAdjTrialD = 0, totalAdjTrialK = 0;
    double totalIsD = 0, totalIsK = 0;
    double totalBsD = 0, totalBsK = 0;

    for (var acc in _accounts) {
      totalTrialD += acc.trialDebet;
      totalTrialK += acc.trialKredit;
      totalAdjD += acc.adjDebet;
      totalAdjK += acc.adjKredit;
      totalAdjTrialD += acc.adjustedTrialDebet;
      totalAdjTrialK += acc.adjustedTrialKredit;
      totalIsD += acc.incomeStatementDebet;
      totalIsK += acc.incomeStatementKredit;
      totalBsD += acc.balanceSheetDebet;
      totalBsK += acc.balanceSheetKredit;
    }

    final double netIncome = (_summaryData?['net_income'] ?? _summaryData?['laba_rugi_bersih'] ?? _summaryData?['shu'] as num?)?.toDouble() ?? 
                             (totalIsK - totalIsD);
    
    // Perhitungan Ikhtisar R/L (SHU Periode Berjalan)
    double ikhtisarIsDebet = 0;
    double ikhtisarIsKredit = 0;
    double ikhtisarBsDebet = 0;
    double ikhtisarBsKredit = 0;

    if (netIncome > 0) {
      // LABA / SHU Positif (Pendapatan > Beban):
      // Dicatat di Debet R/L agar seimbang, dan Kredit Neraca (menambah Modal/Ekuitas)
      ikhtisarIsDebet = netIncome;
      ikhtisarBsKredit = netIncome;
    } else if (netIncome < 0) {
      // RUGI (Beban > Pendapatan):
      // Dicatat di Kredit R/L agar seimbang, dan Debet Neraca (mengurangi Modal)
      double rugi = netIncome.abs();
      ikhtisarIsKredit = rugi;
      ikhtisarBsDebet = rugi;
    }

    // Grand Total Setelah Ikhtisar R/L
    double grandTotalTrialD = (_summaryData?['total_trial_debit'] as num?)?.toDouble() ?? totalTrialD;
    double grandTotalTrialK = (_summaryData?['total_trial_credit'] as num?)?.toDouble() ?? totalTrialK;
    double grandTotalAdjD = (_summaryData?['total_adjustment_debit'] as num?)?.toDouble() ?? totalAdjD;
    double grandTotalAdjK = (_summaryData?['total_adjustment_credit'] as num?)?.toDouble() ?? totalAdjK;
    double grandTotalAdjTrialD = (_summaryData?['total_percobaan_debit'] as num?)?.toDouble() ?? totalAdjTrialD;
    double grandTotalAdjTrialK = (_summaryData?['total_percobaan_credit'] as num?)?.toDouble() ?? totalAdjTrialK;
    double grandTotalIsD = (_summaryData?['total_rugi_laba_debit'] as num?)?.toDouble() ?? (totalIsD + ikhtisarIsDebet);
    double grandTotalIsK = (_summaryData?['total_rugi_laba_credit'] as num?)?.toDouble() ?? (totalIsK + ikhtisarIsKredit);
    double grandTotalBsD = (_summaryData?['total_neraca_debit'] as num?)?.toDouble() ?? (totalBsD + ikhtisarBsDebet);
    double grandTotalBsK = (_summaryData?['total_neraca_credit'] as num?)?.toDouble() ?? (totalBsK + ikhtisarBsKredit);

    // Cek Keseimbangan Tiap Pasangan Kolom
    bool isTrialBalanced = (grandTotalTrialD - grandTotalTrialK).abs() < 1.0;
    bool isAdjBalanced = (grandTotalAdjD - grandTotalAdjK).abs() < 1.0;
    bool isAdjTrialBalanced = (grandTotalAdjTrialD - grandTotalAdjTrialK).abs() < 1.0;
    bool isIsBalanced = (grandTotalIsD - grandTotalIsK).abs() < 1.0;
    bool isBsBalanced = (grandTotalBsD - grandTotalBsK).abs() < 1.0;
    bool isAllBalanced = _summaryData?['is_balanced'] == true || 
                         (isTrialBalanced && isAdjBalanced && isAdjTrialBalanced && isIsBalanced && isBsBalanced);

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 1620),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. TINGKAT 1: GROUP HEADER (5 KELOMPOK BERPASANGAN D & K)
                          Container(
                            color: const Color(0xFF0F172A),
                            child: Row(
                              children: [
                                _buildHeaderCell('KODE & NAMA PERKIRAAN', width: 320),
                                _buildHeaderCell('1. NERACA SALDO AWAL', width: 260, borderLeft: true),
                                _buildHeaderCell('2. PENYESUAIAN / MUTASI', width: 260, borderLeft: true),
                                _buildHeaderCell('3. PERCOBAAN', width: 260, borderLeft: true),
                                _buildHeaderCell('4. RUGI LABA', width: 260, borderLeft: true),
                                _buildHeaderCell('5. NERACA', width: 260, borderLeft: true),
                              ],
                            ),
                          ),
                          // 2. TINGKAT 2: SUB-HEADER (D | K PERPASANGAN)
                          Container(
                            color: const Color(0xFF1E293B),
                            child: Row(
                              children: [
                                _buildHeaderCell('KODE', width: 80),
                                _buildHeaderCell('NAMA PERKIRAAN', width: 240, borderLeft: true),
                                _buildHeaderCell('DEBET (D)', width: 130, borderLeft: true),
                                _buildHeaderCell('KREDIT (K)', width: 130, borderLeft: true),
                                _buildHeaderCell('DEBET (D)', width: 130, borderLeft: true),
                                _buildHeaderCell('KREDIT (K)', width: 130, borderLeft: true),
                                _buildHeaderCell('DEBET (D)', width: 130, borderLeft: true),
                                _buildHeaderCell('KREDIT (K)', width: 130, borderLeft: true),
                                _buildHeaderCell('DEBET (D)', width: 130, borderLeft: true),
                                _buildHeaderCell('KREDIT (K)', width: 130, borderLeft: true),
                                _buildHeaderCell('DEBET (D)', width: 130, borderLeft: true),
                                _buildHeaderCell('KREDIT (K)', width: 130, borderLeft: true),
                              ],
                            ),
                          ),
                          // 3. BARIS DATA AKUN DARI API
                          ..._accounts.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var acc = entry.value;
                            return Container(
                              color: idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                              child: Row(
                                children: [
                                  _buildDataCell(acc.code, width: 80, isBold: true, color: const Color(0xFF0284C7), alignment: Alignment.center),
                                  _buildDataCell(acc.name, width: 240, alignment: Alignment.centerLeft, isBold: false),
                                  _buildDataCell(_formatNumber(acc.trialDebet), width: 130),
                                  _buildDataCell(_formatNumber(acc.trialKredit), width: 130),
                                  _buildDataCell(_formatNumber(acc.adjDebet), width: 130),
                                  _buildDataCell(_formatNumber(acc.adjKredit), width: 130),
                                  _buildDataCell(_formatNumber(acc.adjustedTrialDebet), width: 130),
                                  _buildDataCell(_formatNumber(acc.adjustedTrialKredit), width: 130),
                                  _buildDataCell(_formatNumber(acc.incomeStatementDebet), width: 130),
                                  _buildDataCell(_formatNumber(acc.incomeStatementKredit), width: 130),
                                  _buildDataCell(_formatNumber(acc.balanceSheetDebet), width: 130),
                                  _buildDataCell(_formatNumber(acc.balanceSheetKredit), width: 130),
                                ],
                              ),
                            );
                          }),

                          // 4. BARIS SUBTOTAL (JUMLAH SEBELUM IKHTISAR R/L)
                          Container(
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: [
                                _buildDataCell('JUMLAH SEBELUM SHU', width: 320, alignment: Alignment.centerLeft, isBold: true, color: const Color(0xFF1E293B)),
                                _buildDataCell(_formatNumber(totalTrialD), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalTrialK), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalAdjD), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalAdjK), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalAdjTrialD), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalAdjTrialK), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalIsD), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalIsK), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalBsD), width: 130, isBold: true),
                                _buildDataCell(_formatNumber(totalBsK), width: 130, isBold: true),
                              ],
                            ),
                          ),

                          // 5. BARIS PENYEIMBANG: IKHTISAR R/L (SHU PERIODE BERJALAN)
                          Container(
                            color: const Color(0xFFFEF3C7),
                            child: Row(
                              children: [
                                _buildDataCell('Ikhtisar R/L (SHU Periode Berjalan)', width: 320, alignment: Alignment.centerLeft, isBold: true, color: const Color(0xFFB45309)),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell('-', width: 130, alignment: Alignment.center),
                                _buildDataCell(_formatNumber(ikhtisarIsDebet), width: 130, isBold: true, color: const Color(0xFFB45309)),
                                _buildDataCell(_formatNumber(ikhtisarIsKredit), width: 130, isBold: true, color: const Color(0xFFB45309)),
                                _buildDataCell(_formatNumber(ikhtisarBsDebet), width: 130, isBold: true, color: const Color(0xFFB45309)),
                                _buildDataCell(_formatNumber(ikhtisarBsKredit), width: 130, isBold: true, color: const Color(0xFFB45309)),
                              ],
                            ),
                          ),

                          // 6. BARIS TOTAL PALING BAWAH (WARNA TEKS HIJAU TEBAL STATUS BALANCED)
                          Container(
                            color: const Color(0xFF0F172A),
                            child: Row(
                              children: [
                                _buildDataCell('TOTAL', width: 320, alignment: Alignment.centerLeft, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalTrialD), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalTrialK), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalAdjD), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalAdjK), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalAdjTrialD), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalAdjTrialK), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalIsD), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalIsK), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalBsD), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                                _buildDataCell(_formatNumber(grandTotalBsK), width: 130, isBold: true, color: const Color(0xFF4ADE80)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // FOOTER STATUS SUMMARY
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isAllBalanced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isAllBalanced ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isAllBalanced ? Icons.check_circle : Icons.warning_amber_rounded, 
                         color: isAllBalanced ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isAllBalanced ? 'STATUS: SEIMBANG / 100% BALANCED' : 'STATUS: PERLU REKONSILIASI / DIVERGENSI',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isAllBalanced ? const Color(0xFF15803D) : const Color(0xFFB45309))),
                          Text('Sisa Hasil Usaha (SHU) Bersih: ${_formatRupiah(netIncome)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Total Aset Neraca: ${_formatRupiah(grandTotalBsD)}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required double width, bool borderLeft = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: borderLeft ? const Border(left: BorderSide(color: Colors.white24, width: 1)) : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildDataCell(
    String text, {
    required double width, 
    Alignment alignment = Alignment.centerRight, 
    bool isBold = false, 
    Color? color,
    Color? bgColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
      ),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}
