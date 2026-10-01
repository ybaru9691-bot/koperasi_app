import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../../constants/app_colors.dart';
import '../../data/models/executive_report_model.dart';
import '../../services/auth_service.dart';
import 'shu_parameter_screen.dart';
import 'widgets/dividend_distribution_dialog.dart';

/// 📊 HALAMAN RINGKASAN LAPORAN EKSEKUTIF KETUA KOPERASI (RESPONSIF)
class ExecutiveReportScreen extends StatefulWidget {
  const ExecutiveReportScreen({super.key});

  @override
  State<ExecutiveReportScreen> createState() => ExecutiveReportScreenState();
}

class ExecutiveReportScreenState extends State<ExecutiveReportScreen> with SingleTickerProviderStateMixin {
  Future<void> fetchReportData() async {
    await _fetchReportData();
  }
  late int _selectedMonth;
  late int _selectedYear;
  late String _selectedPeriod;
  final List<String> _periodOptions = [];
  
  final List<String> _monthsList = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  ExecutiveReportModel? _report;
  bool _isInitialLoading = true;
  bool _isChangingPeriod = false;
  bool _hasError = false;
  String? _errorMessage;
  double _shuAllocationPercentage = 25.0;
  bool _isTriggeringBunga = false;
  bool _isExportingPdf = false;
  bool _isExportingMemorialPdf = false;
  final Set<String> _processedInterestPeriods = {};

  bool get _isCurrentPeriodInterestProcessed =>
      _processedInterestPeriods.contains('$_selectedMonth-$_selectedYear') ||
      (_report?.isDistributed ?? false);

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    
    for (int y = 2025; y <= now.year + 1; y++) {
      for (int m = 1; m <= 12; m++) {
        _periodOptions.add('${_monthsList[m - 1]} $y');
      }
    }
    _selectedPeriod = '${_monthsList[_selectedMonth - 1]} $_selectedYear';
    
    _fetchReportData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData({bool isPeriodChange = false}) async {
    if (!mounted) return;
    setState(() {
      if (isPeriodChange && _report != null) {
        _isChangingPeriod = true;
      } else {
        _isInitialLoading = true;
      }
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            _hasError = _report == null;
            _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
            _isInitialLoading = false;
            _isChangingPeriod = false;
          });
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/reports/summary?month=$_selectedMonth&year=$_selectedYear');
      debugPrint('[EXECUTIVE_REPORT] Requesting URL: $uri');

      var response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('$baseUrl/manager/reports/executive-summary?month=$_selectedMonth&year=$_selectedYear');
        debugPrint('[EXECUTIVE_REPORT] 404 on summary, trying fallback URL: $fallbackUri');
        response = await http.get(
          fallbackUri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final dataMap = responseData['data'] is Map<String, dynamic>
              ? responseData['data'] as Map<String, dynamic>
              : Map<String, dynamic>.from(responseData['data']);
          final newReport = ExecutiveReportModel.fromJson(dataMap);
          if (newReport.isDistributed) {
            _processedInterestPeriods.add('$_selectedMonth-$_selectedYear');
          }
          setState(() {
            _report = newReport;
            if (_report!.shuPercentage > 0) {
              _shuAllocationPercentage = _report!.shuPercentage;
            }
            _isInitialLoading = false;
            _isChangingPeriod = false;
            _hasError = false;
          });
        } else {
          setState(() {
            _hasError = _report == null;
            _errorMessage = responseData['message'] ?? 'Gagal memuat data laporan.';
            _isInitialLoading = false;
            _isChangingPeriod = false;
          });
          if (_report != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_errorMessage ?? 'Gagal memuat data'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        setState(() {
          _hasError = _report == null;
          _errorMessage = 'Gagal memuat data (Status ${response.statusCode})';
          _isInitialLoading = false;
          _isChangingPeriod = false;
        });
        if (_report != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat data (Status ${response.statusCode})'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = _report == null;
          _errorMessage = 'Error: $e';
          _isInitialLoading = false;
          _isChangingPeriod = false;
        });
        if (_report != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  ///  1. PREVIEW PEMBAGIAN BUNGA BUKU PUTIH (BM)
  Future<void> _previewAndTriggerMonthlyInterest() async {
    if (!mounted) return;
    setState(() {
      _isTriggeringBunga = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.'))
          );
        }
        setState(() => _isTriggeringBunga = false);
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/interest/preview?month=$_selectedMonth&year=$_selectedYear');
      debugPrint('[INTEREST_PREVIEW] Requesting URL: $uri');

      var response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('$baseUrl/manager/trigger-monthly-interest/preview?month=$_selectedMonth&year=$_selectedYear');
        debugPrint('[INTEREST_PREVIEW] Trying fallback preview URL: $fallbackUri');
        response = await http.get(
          fallbackUri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 30));
      }

      if (!mounted) return;

      Map<String, dynamic> previewData = {};
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is Map) {
          previewData = Map<String, dynamic>.from(decoded['data']);
        } else if (decoded is Map) {
          previewData = Map<String, dynamic>.from(decoded);
        }
      }

      // Check if already distributed / processed
      final bool alreadyProcessed = previewData['is_distributed'] == true ||
          previewData['has_executed'] == true ||
          previewData['already_distributed'] == true ||
          previewData['already_processed'] == true ||
          previewData['has_distributed'] == true ||
          previewData['is_processed'] == true;

      if (alreadyProcessed) {
        setState(() {
          _processedInterestPeriods.add('$_selectedMonth-$_selectedYear');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bunga Buku Putih periode ${_monthsList[_selectedMonth - 1]} $_selectedYear sudah pernah dieksekusi.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF6A1B9A),
              action: SnackBarAction(
                label: 'Cetak BM',
                textColor: Colors.white,
                onPressed: _exportMemorialPdf,
              ),
            ),
          );
        }
        return;
      }

      // Display Preview Dialog
      if (mounted) {
        _showInterestPreviewDialog(previewData);
      }
    } catch (e) {
      if (mounted) {
        // In case preview endpoint fails due to offline/demo mode, show calculated preview fallback
        _showInterestPreviewDialog({});
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTriggeringBunga = false;
        });
      }
    }
  }

  static int _parseIntSafe(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim()) ?? fallback;
  }

  static double _parseDoubleSafe(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  /// 📋 2. MODAL PRATINJAU SEBELUM EKSEKUSI
  void _showInterestPreviewDialog(Map<String, dynamic> previewData) {
    final String monthName = _monthsList[_selectedMonth - 1];

    final String rawCutoff = (previewData['cutoff_date'] ??
            previewData['cut_off_date'] ??
            previewData['cutoff'] ??
            '')
        .toString()
        .trim();
    final String cutoffDate = rawCutoff.isNotEmpty
        ? (rawCutoff.toLowerCase().contains('s.d.') || rawCutoff.toLowerCase().contains('transaksi')
            ? rawCutoff
            : 'Transaksi s.d. $rawCutoff')
        : 'Transaksi s.d. 20 $monthName $_selectedYear';

// Simpan nilai default jika tidak ditemukan dipreview data
    final int eligibleMembers = _parseIntSafe(
      previewData['eligible_count'] ??
      previewData['eligible_members'] ??
      previewData['total_eligible'] ??
      previewData['active_members'] ??
      previewData['eligible_member_count'] ??
      previewData['total_eligible_members'],
      0,
    );
    final int passiveMembers = _parseIntSafe(
      previewData['passive_count'] ??
      previewData['passive_members'] ??
      previewData['zero_interest_members'] ??
      previewData['passive_member_count'] ??
      previewData['zero_members'] ??
      previewData['total_passive'],
      0,
    );
    final double totalInterest = _parseDoubleSafe(
      previewData['total_interest'] ??
      previewData['total_expense'] ??
      previewData['total_bunga'] ??
      previewData['total_interest_expense'] ??
      previewData['total_beban_bunga'] ??
      previewData['interest_amount'],
      0.0,
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate_rounded, color: Color(0xFF8E24AA), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pratinjau Pembagian Bunga Buku Putih',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      _previewInfoRow('Periode Bunga', '20 $monthName $_selectedYear', isBold: true),
                      const Divider(height: 16),
                      _previewInfoRow('Cut-off Data', cutoffDate),
                      const Divider(height: 16),
                      _previewInfoRow('Anggota Berhak Bunga', '$eligibleMembers Anggota', valueColor: const Color(0xFF16A34A)),
                      const Divider(height: 16),
                      _previewInfoRow('Anggota Pasif / Bunga Rp 0', '$passiveMembers Anggota', subtitle: '(tetap masuk di lembar cetak BM)'),
                      const Divider(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCE93D8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Beban Bunga (0,6%):',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                            ),
                            Text(
                              _formatRupiah(totalInterest),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Eksekusi ini akan langsung mengkreditkan bunga ke saldo Buku Putih masing-masing anggota dan menerbitkan Bukti Memorial (BM) ke jurnal akuntansi.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _executeMonthlyInterest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E24AA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Eksekusi Pembagian Bunga', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// 💰 Buka Modal Kalkulasi & Eksekusi Pembagian Deviden Buku Biru (SHU)
  void _openDividendDistributionDialog() {
    final String currentPeriodName = '${_monthsList[_selectedMonth - 1]} $_selectedYear';
    final double defaultPct = _shuAllocationPercentage > 0 ? _shuAllocationPercentage : 25.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DividendDistributionDialog(
        month: _selectedMonth,
        year: _selectedYear,
        periodName: currentPeriodName,
        defaultPercentage: defaultPct,
        onSuccess: () {
          _fetchReportData();
        },
      ),
    );
  }

  Widget _previewInfoRow(String label, String value, {bool isBold = false, Color? valueColor, String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.adminNavy,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// ⚡ 3. EKSEKUSI PEMBAGIAN BUNGA
  Future<void> _executeMonthlyInterest() async {
    if (!mounted) return;
    setState(() {
      _isTriggeringBunga = true;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.'))
          );
        }
        setState(() => _isTriggeringBunga = false);
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/interest/execute?month=$_selectedMonth&year=$_selectedYear');
      debugPrint('[INTEREST_EXECUTE] Requesting URL: $uri');

      var response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'month': _selectedMonth,
          'year': _selectedYear,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('$baseUrl/manager/trigger-monthly-interest');
        debugPrint('[INTEREST_EXECUTE] 404, fallback to: $fallbackUri');
        response = await http.post(
          fallbackUri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'month': _selectedMonth,
            'year': _selectedYear,
          }),
        ).timeout(const Duration(seconds: 45));
      }

      if (!mounted) return;

      Map<String, dynamic> resultData = {};
      try {
        resultData = jsonDecode(response.body);
      } catch (_) {}

      // Record successful period
      setState(() {
        _processedInterestPeriods.add('$_selectedMonth-$_selectedYear');
      });

      // Refresh report data
      _fetchReportData();

      // Show Success Modal with Print Memorial PDF button
      if (mounted) {
        _showInterestSuccessDialog(resultData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengeksekusi pembagian bunga: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTriggeringBunga = false;
        });
      }
    }
  }

  /// 🏆 4. MODAL DIALOG SETELAH EKSEKUSI & CETAK DOKUMEN
  void _showInterestSuccessDialog(Map<String, dynamic> resultData) {
    final String monthName = _monthsList[_selectedMonth - 1];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pembagian Bunga Selesai Diproses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultData['message'] ??
                      'Bunga Simpanan Buku Putih periode $monthName $_selectedYear telah berhasil dikreditkan ke seluruh saldo anggota yang berhak.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.description_rounded, color: Color(0xFF6A1B9A), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Jurnal Bukti Memorial (BM) lembar kuning resmi telah otomatis diterbitkan untuk arsip pembukuan.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF4A148C), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _exportMemorialPdf();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Cetak Bukti Memorial BM (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// 📄 5. CETAK / UNDUH BUKTI MEMORIAL BM (PDF) VIA NATIVE BROWSER DOWNLOAD
  Future<void> _exportMemorialPdf() async {
    if (_isExportingMemorialPdf) return;
    setState(() => _isExportingMemorialPdf = true);

    try {
      final authService = AuthService();
      final token = await authService.getToken();
      final String baseUrl = AuthService.staticBaseUrl;
      final String tokenParam = (token != null && token.isNotEmpty) ? '&token=$token' : '';
      final String downloadUrl = '$baseUrl/manager/interest/export-memorial-pdf?month=$_selectedMonth&year=$_selectedYear$tokenParam';

      debugPrint('[MEMORIAL_PDF] Requesting URL: $downloadUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('Menyiapkan Bukti Memorial BM PDF (${_monthsList[_selectedMonth - 1]} $_selectedYear)...'),
              ],
            ),
            backgroundColor: const Color(0xFF6A1B9A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      http.Response? response;
      try {
        response = await http.get(
          Uri.parse(downloadUrl),
          headers: {
            'Accept': 'application/pdf',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 60));
      } catch (httpError) {
        debugPrint('[MEMORIAL_PDF] HTTP client error/timeout, triggering native browser window open: $httpError');
        html.window.open(downloadUrl, '_blank');
        return;
      }

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = blobUrl
          ..download = 'bukti_memorial_bm_${_selectedMonth}_$_selectedYear.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        html.window.open(downloadUrl, '_blank');
      }
    } catch (e) {
      debugPrint('[MEMORIAL_PDF] Error triggering download: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai unduhan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingMemorialPdf = false);
      }
    }
  }

  Future<void> _updateShuPercentage(double newPercentage) async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login kembali.'))
          );
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/settings/shu-percentage');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'percentage': newPercentage,
          'shu_percentage': newPercentage,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _shuAllocationPercentage = newPercentage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Persentase Alokasi SHU berhasil diperbarui.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchReportData();
      } else {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Gagal memperbarui persentase SHU.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shuAllocationPercentage = newPercentage;
        });
        _fetchReportData();
      }
    }
  }

  void _showEditBenchmarkAndSHUDialog(ExecutiveReportModel report) {
    final netProfitController = TextEditingController(
      text: report.benchmarkNetProfit > 0 ? report.benchmarkNetProfit.toInt().toString() : '',
    );
    final pctController = TextEditingController(
      text: _shuAllocationPercentage.toStringAsFixed(0),
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15803D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF15803D), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Parameter SHU Koperasi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode: ${_monthsList[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.adminNavy, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masukkan laba bersih acuan koperasi dan persentase alokasi SHU anggota/deviden untuk periode ini:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: netProfitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Laba Bersih Acuan Koperasi (Rp)',
                        hintText: 'Contoh: 50000000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        helperText: 'Laba bersih resmi acuan manajer (bukan arus kas tunai)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pctController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Persentase Alokasi Deviden (%)',
                        hintText: 'Contoh: 25',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        helperText: 'Standar aturan koperasi: 25%',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ShuParameterScreen()),
                        ).then((_) => _fetchReportData(isPeriodChange: true));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.table_chart_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Buka Master 12 Bulan Parameter SHU',
                              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final double? parsedProfit = double.tryParse(netProfitController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
                          final double? parsedPct = double.tryParse(pctController.text);

                          if (parsedPct == null || parsedPct < 0 || parsedPct > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Persentase harus antara 0% hingga 100%!')),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isSubmitting = true);

                          try {
                            final authService = AuthService();
                            final token = await authService.getToken();
                            final fiscalYear = (_selectedMonth >= 6) ? (_selectedYear + 1) : _selectedYear;

                            if (token != null) {
                              await http.post(
                                Uri.parse('${AuthService.staticBaseUrl}/manager/coop-benchmarks/update'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Accept': 'application/json',
                                  'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({
                                  'fiscal_year': fiscalYear,
                                  'month': _selectedMonth,
                                  'net_income': parsedProfit ?? 0.0,
                                  'dividend_allocation_percent': parsedPct,
                                }),
                              ).timeout(const Duration(seconds: 10));

                              await _updateShuPercentage(parsedPct);
                            }
                          } catch (_) {}

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            setState(() {
                              _shuAllocationPercentage = parsedPct;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Parameter Laba Bersih & Alokasi SHU berhasil diperbarui.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _fetchReportData(isPeriodChange: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan Parameter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _exportReportPdf() async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('Menyiapkan Laporan Eksekutif PDF ($_selectedPeriod)...'),
              ],
            ),
            backgroundColor: AppColors.adminNavy,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final authService = AuthService();
      final token = await authService.getToken();
      
      final String baseUrl = AuthService.staticBaseUrl;
      final url = '$baseUrl/manager/reports/executive-summary/pdf?month=$_selectedMonth&year=$_selectedYear';
      debugPrint('[REPORT_PDF] Requesting URL: $url');
      
      http.Response? response;
      try {
        response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 120));
      } catch (httpError) {
        debugPrint('[REPORT_PDF] HTTP client error/timeout, triggering native browser window open: $httpError');
        final directDownloadUrl = '$baseUrl/manager/reports/executive-summary/pdf?month=$_selectedMonth&year=$_selectedYear${token != null ? "&token=$token" : ""}';
        html.window.open(directDownloadUrl, '_blank');
        return;
      }

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = blobUrl
          ..download = 'laporan_eksekutif_${_selectedMonth}_$_selectedYear.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        final directDownloadUrl = '$baseUrl/manager/reports/executive-summary/pdf?month=$_selectedMonth&year=$_selectedYear${token != null ? "&token=$token" : ""}';
        html.window.open(directDownloadUrl, '_blank');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat mengunduh PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 12.0,
            vertical: 16.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. FILTER & PERIOD HEADER SECTION (Selalu Tampil & Interaktif)
                  _buildHeaderFilterSection(isDesktop),

                  const SizedBox(height: 16),

                  // 2. KONTEN KARTU LAPORAN / ANIMATED SHIMMER SKELETON
                  if (_hasError && _report == null)
                    _buildErrorView()
                  else if (_isInitialLoading && _report == null)
                    _buildSkeletonCards(isDesktop)
                  else if (_report != null) ...[
                    if (_isChangingPeriod)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: Colors.transparent,
                          minHeight: 3,
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: _isChangingPeriod ? 0.75 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. CASHFLOW SUMMARY CARDS (3 CARDS)
                          _buildCashflowSummaryCards(isDesktop, _report!),

                          const SizedBox(height: 20),

                          // 3. ITEMIZES BREAKDOWN TABLES (KM VS KK)
                          _buildBreakdownTablesSection(isDesktop, _report!),

                          const SizedBox(height: 20),

                          // 4. REKAPITULASI TRANSAKSI ADMIN
                          _buildAdminTransactionRecapCard(isDesktop, _report!),

                          const SizedBox(height: 20),

                          // 5. FINANCIAL HEALTH METRICS (INDIKATOR KESEHATAN KEUANGAN)
                          _buildFinancialHealthMetricsCard(isDesktop, _report!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Gagal memuat data keuangan', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchReportData(isPeriodChange: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  /// 🌟 SHIMMER GRADIENT BOX
  Widget _buildShimmerBox({
    double? width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnimation.value - 1, 0),
              end: Alignment(_shimmerAnimation.value + 1, 0),
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }

  /// 🌟 DARK SHIMMER GRADIENT BOX (UNTUK KARTU KESEHATAN KEUANGAN NAVY GELAP)
  Widget _buildDarkShimmerBox({
    double? width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnimation.value - 1, 0),
              end: Alignment(_shimmerAnimation.value + 1, 0),
              colors: const [
                Color(0xFF1E293B),
                Color(0xFF334155),
                Color(0xFF1E293B),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }

  /// 💀 STRUKTUR SKELETON LENGKAP LAPORAN EKSEKUTIF
  Widget _buildSkeletonCards(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Skeleton Cashflow Summary Cards (3 Cards)
        _buildSkeletonSummaryCards(isDesktop),

        const SizedBox(height: 20),

        // 2. Skeleton Breakdown Tables (KM vs KK)
        _buildSkeletonBreakdownTables(isDesktop),

        const SizedBox(height: 20),

        // 3. Skeleton Admin Transaction Recap
        _buildSkeletonAdminRecap(isDesktop),

        const SizedBox(height: 20),

        // 4. Skeleton Financial Health Metrics
        _buildSkeletonFinancialHealth(isDesktop),
      ],
    );
  }

  Widget _buildSkeletonSummaryCards(bool isDesktop) {
    Widget singleCardSkeleton() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerBox(width: 120, height: 12),
                  const SizedBox(height: 8),
                  _buildShimmerBox(width: 170, height: 22),
                  const SizedBox(height: 6),
                  _buildShimmerBox(width: 90, height: 10),
                ],
              ),
            ),
            _buildShimmerBox(width: 42, height: 42, shape: BoxShape.circle),
          ],
        ),
      );
    }

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1050) {
            return Row(
              children: [
                Expanded(child: singleCardSkeleton()),
                const SizedBox(width: 10),
                Expanded(child: singleCardSkeleton()),
                const SizedBox(width: 10),
                Expanded(child: singleCardSkeleton()),
                const SizedBox(width: 10),
                Expanded(child: singleCardSkeleton()),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: singleCardSkeleton()),
                    const SizedBox(width: 10),
                    Expanded(child: singleCardSkeleton()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: singleCardSkeleton()),
                    const SizedBox(width: 10),
                    Expanded(child: singleCardSkeleton()),
                  ],
                ),
              ],
            );
          }
        },
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: singleCardSkeleton()),
            const SizedBox(width: 10),
            Expanded(child: singleCardSkeleton()),
          ],
        ),
        const SizedBox(height: 10),
        singleCardSkeleton(),
        const SizedBox(height: 10),
        singleCardSkeleton(),
      ],
    );
  }

  Widget _buildSkeletonBreakdownTables(bool isDesktop) {
    Widget singleTableSkeleton() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShimmerBox(width: 20, height: 20, shape: BoxShape.circle),
                const SizedBox(width: 8),
                _buildShimmerBox(width: 160, height: 16),
              ],
            ),
            const SizedBox(height: 14),
            _buildShimmerBox(height: 32, borderRadius: 6),
            const SizedBox(height: 8),
            _buildShimmerBox(height: 24, borderRadius: 4),
            const SizedBox(height: 6),
            _buildShimmerBox(height: 24, borderRadius: 4),
            const SizedBox(height: 6),
            _buildShimmerBox(height: 24, borderRadius: 4),
            const SizedBox(height: 6),
            _buildShimmerBox(height: 24, borderRadius: 4),
          ],
        ),
      );
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: singleTableSkeleton()),
          const SizedBox(width: 14),
          Expanded(child: singleTableSkeleton()),
        ],
      );
    }

    return Column(
      children: [
        singleTableSkeleton(),
        const SizedBox(height: 16),
        singleTableSkeleton(),
      ],
    );
  }

  Widget _buildSkeletonAdminRecap(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildShimmerBox(width: 20, height: 20, shape: BoxShape.circle),
              const SizedBox(width: 8),
              _buildShimmerBox(width: 280, height: 16),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 4 : 2,
            childAspectRatio: isDesktop ? 2.6 : 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: List.generate(4, (index) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    _buildShimmerBox(width: 28, height: 28, shape: BoxShape.circle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildShimmerBox(width: 80, height: 10),
                          const SizedBox(height: 4),
                          _buildShimmerBox(width: 50, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonFinancialHealth(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.adminNavy.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildDarkShimmerBox(width: 22, height: 22, shape: BoxShape.circle),
              const SizedBox(width: 8),
              _buildDarkShimmerBox(width: 320, height: 16),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 3 : 1,
            childAspectRatio: isDesktop ? 3.0 : 3.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            children: List.generate(3, (index) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    _buildDarkShimmerBox(width: 36, height: 36, shape: BoxShape.circle),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDarkShimmerBox(width: 120, height: 11),
                          const SizedBox(height: 4),
                          _buildDarkShimmerBox(width: 60, height: 16),
                          const SizedBox(height: 3),
                          _buildDarkShimmerBox(width: 140, height: 9),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 🗓️ 1. FILTER & PERIOD HEADER
  Widget _buildHeaderFilterSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.assessment_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Ringkasan Laporan Eksekutif Keuangan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Laporan Pertanggungjawaban Periode: ${_report?.period ?? _selectedPeriod} • Tanggal Rilis: ${_report?.reportDate ?? "-"}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Period Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: DropdownButton<String>(
                  value: _periodOptions.contains(_selectedPeriod) ? _selectedPeriod : _periodOptions.first,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.adminNavy),
                  items: _periodOptions.map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(period, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedPeriod) {
                      setState(() {
                        _selectedPeriod = val;
                        final parts = val.split(' ');
                        if (parts.length == 2) {
                          _selectedMonth = _monthsList.indexOf(parts[0]) + 1;
                          _selectedYear = int.tryParse(parts[1]) ?? DateTime.now().year;
                        }
                      });
                      _fetchReportData(isPeriodChange: true);
                    }
                  },
                ),
              ),

              // Export PDF Button
              ElevatedButton.icon(
                onPressed: _isExportingPdf ? null : _exportReportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.adminNavy.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  _isExportingPdf ? 'Menyiapkan PDF...' : 'Export PDF',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

              // Dynamic Interest Button: Execute or Reprint BM
              if (_isCurrentPeriodInterestProcessed)
                ElevatedButton.icon(
                  onPressed: _isExportingMemorialPdf ? null : _exportMemorialPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6A1B9A).withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExportingMemorialPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    _isExportingMemorialPdf
                        ? 'Menyiapkan PDF...'
                        : 'Cetak Ulang BM Bunga (Periode Ini)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isTriggeringBunga ? null : _previewAndTriggerMonthlyInterest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E24AA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isTriggeringBunga
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded, size: 18),
                  label: Text(
                    _isTriggeringBunga ? 'Memuat Pratinjau...' : 'Jalankan Pembagian Bunga Buku Putih',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),

              // Button: Jalankan Pembagian Deviden / SHU
              ElevatedButton.icon(
                onPressed: _openDividendDistributionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E47),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Jalankan Pembagian Deviden / SHU',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 💰 2. CASHFLOW & SHU SUMMARY CARDS (4 CARDS)
  Widget _buildCashflowSummaryCards(bool isDesktop, ExecutiveReportModel report) {
    final cardKM = _summaryCardItem(
      title: 'Total Kas Masuk (KM)',
      amount: report.totalKasMasuk,
      subtitle: '${report.kmCategories.length} Pos Kategori Penerimaan',
      icon: Icons.arrow_downward_rounded,
      color: const Color(0xFF0D9488),
      bgGradient: const [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
    );

    final cardKK = _summaryCardItem(
      title: 'Total Kas Keluar (KK)',
      amount: report.totalKasKeluar,
      subtitle: '${report.kkCategories.length} Pos Kategori Pengeluaran',
      icon: Icons.arrow_upward_rounded,
      color: const Color(0xFFE11D48),
      bgGradient: const [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
    );

    final cardNet = _summaryCardItem(
      title: 'Net Cashflow Kasir',
      amount: report.netCashflow,
      subtitle: 'Total Kas Masuk - Total Kas Keluar',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF0284C7),
      bgGradient: const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    );

    final double currentPercentage = _shuAllocationPercentage > 0
        ? _shuAllocationPercentage
        : (report.shuPercentage > 0 ? report.shuPercentage : 25.0);
    final double benchmarkProfit = report.benchmarkNetProfit;
    final double allocatedShuVal = report.allocatedShu > 0
        ? report.allocatedShu
        : (benchmarkProfit > 0 ? (benchmarkProfit * (currentPercentage / 100)) : 0.0);

    final cardSHU = _summaryCardItem(
      title: 'Alokasi SHU & Deviden',
      amount: allocatedShuVal,
      subtitle: benchmarkProfit > 0
          ? 'Acuan Laba Bersih: ${_formatRupiah(benchmarkProfit)}'
          : 'Belum Diinput di Parameter SHU',
      icon: Icons.savings_rounded,
      color: const Color(0xFF15803D),
      bgGradient: const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
      bottomExtra: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laba Bersih Acuan: ${_formatRupiah(benchmarkProfit)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _isChangingPeriod
                      ? _buildShimmerBox(width: 100, height: 14)
                      : Text(
                          'Alokasi Deviden (${currentPercentage.toStringAsFixed(0)}%): ${_formatRupiah(allocatedShuVal)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _showEditBenchmarkAndSHUDialog(report),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF15803D),
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1050) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cardKM),
                const SizedBox(width: 10),
                Expanded(child: cardKK),
                const SizedBox(width: 10),
                Expanded(child: cardNet),
                const SizedBox(width: 10),
                Expanded(child: cardSHU),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardKM),
                    const SizedBox(width: 10),
                    Expanded(child: cardKK),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardNet),
                    const SizedBox(width: 10),
                    Expanded(child: cardSHU),
                  ],
                ),
              ],
            );
          }
        },
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cardKM),
            const SizedBox(width: 10),
            Expanded(child: cardKK),
          ],
        ),
        const SizedBox(height: 10),
        cardNet,
        const SizedBox(height: 10),
        cardSHU,
      ],
    );
  }

  Widget _summaryCardItem({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> bgGradient,
    Widget? bottomExtra,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bgGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11.5, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _isChangingPeriod
                        ? _buildShimmerBox(width: 140, height: 20)
                        : Text(_formatRupiah(amount), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
            ],
          ),
          if (bottomExtra != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white38, height: 1),
            const SizedBox(height: 8),
            bottomExtra,
          ],
        ],
      ),
    );
  }

  /// 📑 3. ITEMIZED BREAKDOWN TABLES (KM VS KK SEJAJAR ATAU STACK)
  Widget _buildBreakdownTablesSection(bool isDesktop, ExecutiveReportModel report) {
    final tableKM = _categoryTableCard(
      title: 'Rincian Kas Masuk (KM)',
      icon: Icons.south_west_rounded,
      headerColor: const Color(0xFF0D9488),
      categories: report.kmCategories,
    );

    final tableKK = _categoryTableCard(
      title: 'Rincian Kas Keluar (KK)',
      icon: Icons.north_east_rounded,
      headerColor: const Color(0xFFE11D48),
      categories: report.kkCategories,
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: tableKM),
          const SizedBox(width: 14),
          Expanded(child: tableKK),
        ],
      );
    }

    return Column(
      children: [
        tableKM,
        const SizedBox(height: 16),
        tableKK,
      ],
    );
  }

  Widget _categoryTableCard({
    required String title,
    required IconData icon,
    required Color headerColor,
    required List<CategoryDetailModel> categories,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: headerColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
            ],
          ),

          const SizedBox(height: 12),

          if (categories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 32),
                  SizedBox(height: 8),
                  Text('Belum Ada Transaksi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                  Text('Rp 0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              width: 500,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder)),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(65),
                      1: FlexColumnWidth(2.5),
                      2: FixedColumnWidth(130),
                      3: FixedColumnWidth(80),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: headerColor),
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('Kode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('Pos Kategori', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('Nominal (Rp)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                          Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('Porsi (%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                      ),
                      for (int i = 0; i < categories.length; i++)
                        TableRow(
                          decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(categories[i].code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(categories[i].categoryName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(_formatRupiah(categories[i].amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: headerColor))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text('${categories[i].percentage}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 4. REKAPITULASI TRANSAKSI ADMIN
  Widget _buildAdminTransactionRecapCard(bool isDesktop, ExecutiveReportModel report) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.ballot_rounded, color: AppColors.adminNavy, size: 20),
              SizedBox(width: 8),
              Text(
                'Rekapitulasi Transaksi Input Admin & Verification Audit',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
              ),
            ],
          ),

          const SizedBox(height: 14),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 4 : 2,
            childAspectRatio: isDesktop ? 2.6 : 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _statusRecapBadge('Total Input Admin', '${report.totalInputAdmin} Mutasi', Icons.edit_note_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
              _statusRecapBadge('Auto-Approved System', '${report.autoApprovedCount} Transaksi', Icons.verified_rounded, AppColors.success, AppColors.successBg),
              _statusRecapBadge('Butuh ACC Ketua', '${report.manualApprovalPendingCount} Transaksi', Icons.pending_actions_rounded, AppColors.warning, AppColors.warningBg),
              _statusRecapBadge('Ditolak / Cancelled', '${report.rejectedCount} Transaksi', Icons.cancel_outlined, AppColors.danger, AppColors.dangerBg),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRecapBadge(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🩺 5. FINANCIAL HEALTH METRICS (RASIO KESEHATAN KEUANGAN)
  Widget _buildFinancialHealthMetricsCard(bool isDesktop, ExecutiveReportModel report) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.adminNavy.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.health_and_safety_rounded, color: AppColors.adminAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Indikator Rasio Kesehatan Keuangan Koperasi (Financial Metrics)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 14),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 3 : 1,
            childAspectRatio: isDesktop ? 3.0 : 3.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            children: [
              _metricBox('Rasio Likuiditas Kas', '${report.liquidityRatioPercentage}%', 'Status: Sangat Sehat (Target > 120%)', Icons.water_drop_rounded, AppColors.adminAccent),
              _metricBox('Rasio Cakupan Operasional', '${report.operationalCoverageRatio}x', 'Status: Aman & Efisien (Target > 2.0x)', Icons.speed_rounded, const Color(0xFF22C55E)),
              _metricBox('Kolektibilitas Piutang', '${report.loanCollectibilityPercentage}%', 'Status: Lancar (NPL < 3.0%)', Icons.fact_check_rounded, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String val, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Text(status, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
