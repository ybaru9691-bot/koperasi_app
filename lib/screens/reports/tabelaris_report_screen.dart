import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../../services/auth_service.dart';
import '../../widgets/reports/tabelaris_table_view.dart';

export '../../widgets/reports/tabelaris_table_view.dart' show TabelarisRow, TabelarisAccumulator, TabelarisTableView;

class TabelarisReportScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const TabelarisReportScreen({super.key, this.onOpenDrawer});

  @override
  State<TabelarisReportScreen> createState() => _TabelarisReportScreenState();
}

class _TabelarisReportScreenState extends State<TabelarisReportScreen> {
  bool _isLoading = false;
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;
  String? _errorMessage;
  List<TabelarisRow> _rows = [];
  Map<String, dynamic>? _summary;
  TabelarisAccumulator? _saldoHalLalu;
  TabelarisAccumulator? _jumlahSdHalIni;
  Map<String, dynamic>? _posisiKeuangan;
  final ScrollController _hScroll = ScrollController();

  // ─── Paginasi Viewport ──────────────────────────────────────────────────────
  int _currentPage = 1;
  int _pageSize = 50;

  DateTime _startDate = DateTime.now(), _endDate = DateTime.now();
  String _selectedMode = 'harian';
  String _selectedWeek = 'M1';
  String _selectedMonth = DateTime.now().month.toString().padLeft(2, '0');
  String _selectedYear = DateTime.now().year.toString();

  static const List<String> _months = [
    '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'
  ];
  static const Map<String, String> _monthNames = {
    '01': 'Januari',
    '02': 'Februari',
    '03': 'Maret',
    '04': 'April',
    '05': 'Mei',
    '06': 'Juni',
    '07': 'Juli',
    '08': 'Agustus',
    '09': 'September',
    '10': 'Oktober',
    '11': 'November',
    '12': 'Desember'
  };

  @override
  void initState() {
    super.initState();
    _currentPage = 1;
    _fetchData();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, String> _buildQueryParams() {
    if (_selectedMode == 'harian') {
      return {'start_date': _fmt(_startDate), 'end_date': _fmt(_startDate)};
    }
    if (_selectedMode == 'rentang') {
      return {'start_date': _fmt(_startDate), 'end_date': _fmt(_endDate)};
    }
    return {
      'month': _selectedMonth,
      'year': _selectedYear,
      'week': _selectedWeek,
    };
  }

  String get _periodLabel {
    if (_selectedMode == 'harian') {
      return '${_startDate.day.toString().padLeft(2, '0')} ${_monthNames[_startDate.month.toString().padLeft(2, '0')]} ${_startDate.year}';
    }
    if (_selectedMode == 'rentang') {
      return '${_fmt(_startDate)} s/d ${_fmt(_endDate)}';
    }
    return '$_selectedWeek ${_monthNames[_selectedMonth]} $_selectedYear';
  }

  int get _totalPages {
    if (_rows.isEmpty) return 1;
    final count = (_rows.length / _pageSize).ceil();
    return count < 1 ? 1 : count;
  }

  static String _fmtCurrency(double val) {
    if (val == 0 || val.abs() < 0.0001) return 'Rp 0';
    final formatted = val
        .abs()
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return val < 0 ? '-Rp $formatted' : 'Rp $formatted';
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService().getToken();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/v1/tabelaris')
          .replace(queryParameters: _buildQueryParams());
      final resp = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token'
        },
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final rowsJson = (data?['rows'] as List?) ?? [];
        final summaryJson = data?['summary'] as Map<String, dynamic>?;

        // 1. Ekstraksi saldo_hal_lalu
        TabelarisAccumulator? parsedSaldoHalLalu;
        final rawSaldoLalu = data?['saldo_hal_lalu'] ?? summaryJson?['saldo_hal_lalu'];
        if (rawSaldoLalu is Map) {
          parsedSaldoHalLalu = TabelarisAccumulator.fromJson(Map<String, dynamic>.from(rawSaldoLalu));
        }

        // 2. Ekstraksi jumlah_sd_hal_ini
        TabelarisAccumulator? parsedJumlahSdHalIni;
        final rawJumlahSd = data?['jumlah_sd_hal_ini'] ?? summaryJson?['jumlah_sd_hal_ini'];
        if (rawJumlahSd is Map) {
          parsedJumlahSdHalIni = TabelarisAccumulator.fromJson(Map<String, dynamic>.from(rawJumlahSd));
        }

        // 3. Ekstraksi objek posisi_keuangan
        Map<String, dynamic>? parsedPosisiKeuangan;
        final rawPosisi = data?['posisi_keuangan'] ?? summaryJson?['posisi_keuangan'];
        if (rawPosisi is Map) {
          parsedPosisiKeuangan = Map<String, dynamic>.from(rawPosisi);
        }

        if (mounted) {
          setState(() {
            _rows = rowsJson
                .whereType<Map>()
                .map((e) => TabelarisRow.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            _summary = summaryJson;
            _saldoHalLalu = parsedSaldoHalLalu;
            _jumlahSdHalIni = parsedJumlahSdHalIni;
            _posisiKeuangan = parsedPosisiKeuangan;
            _currentPage = 1;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal memuat data (HTTP ${resp.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Kesalahan koneksi: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// ─── EXPORT EXCEL ────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    setState(() => _isExportingExcel = true);
    try {
      final token = await AuthService().getToken();
      final params = _buildQueryParams();
      final uri = Uri.parse('${AuthService.staticBaseUrl}/v1/tabelaris/export-excel')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final filename = 'Jurnal_Tabelaris_${_periodLabel.replaceAll(' ', '_')}.xlsx';
        final blob = html.Blob(
          [response.bodyBytes],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
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
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export Excel: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  /// ─── EXPORT PDF (LANDSCAPE A3 / FOLIO) ────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final token = await AuthService().getToken();
      final params = Map<String, String>.from(_buildQueryParams());
      params['orientation'] = 'landscape';
      params['paper_size'] = 'a3';
      params['format'] = 'pdf';

      // Coba endpoint export-pdf tabelaris
      Uri uri = Uri.parse('${AuthService.staticBaseUrl}/v1/tabelaris/export-pdf')
          .replace(queryParameters: params);

      var response = await http.get(
        uri,
        headers: {
          'Accept': 'application/pdf, application/octet-stream',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      // Fallback jika endpoint belum menggunakan v1 prefix
      if (response.statusCode == 404) {
        uri = Uri.parse('${AuthService.staticBaseUrl}/reports/tabelaris/export/pdf')
            .replace(queryParameters: params);
        response = await http.get(
          uri,
          headers: {
            'Accept': 'application/pdf, application/octet-stream',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 60));
      }

      if (response.statusCode == 200) {
        final filename = 'Jurnal_Tabelaris_Landscape_A3_${_periodLabel.replaceAll(' ', '_')}.pdf';
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
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
              content: Text('Berhasil mengunduh dokumen Landscape A3: $filename'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export PDF Landscape: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jurnal Tabelaris',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Format 29 Kolom Presisi Manual Koperasi',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          // Tombol Unduh PDF Landscape A3
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ElevatedButton.icon(
              onPressed: (_isExportingPdf || _isLoading) ? null : _exportPdf,
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                _isExportingPdf ? 'Mencetak...' : 'Unduh PDF (A3)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          // Tombol Export Excel
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: (_isExportingExcel || _isLoading) ? null : _exportExcel,
              icon: _isExportingExcel
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                _isExportingExcel ? 'Mengunduh...' : 'Export Excel',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_errorMessage != null) _buildErrorBanner(),
          if (!_isLoading && _rows.isNotEmpty) ...[
            _buildBalanceCheckerBanner(),
            _buildPaginationBar(),
          ],
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2563EB)),
                        SizedBox(height: 16),
                        Text(
                          'Memuat Jurnal Tabelaris 29 Kolom...',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : _buildTableContent(),
          ),
          if (!_isLoading && _rows.isNotEmpty) _buildSummaryCards(),
        ],
      ),
    );
  }

  /// ─── FILTER BAR ──────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              _modeChip('harian', 'Harian'),
              const SizedBox(width: 6),
              _modeChip('rentang', 'Rentang Tanggal'),
              const SizedBox(width: 6),
              _modeChip('mingguan', 'Mingguan (M1-M5)'),
              const Spacer(),
              TextButton.icon(
                onPressed: _isLoading ? null : _fetchData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                label: const Text('Segarkan', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedMode == 'harian') _buildHarianFilter(),
          if (_selectedMode == 'rentang') _buildRentangFilter(),
          if (_selectedMode == 'mingguan') _buildMingguanFilter(),
        ],
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final bool sel = _selectedMode == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF2563EB) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? const Color(0xFF2563EB) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.white60,
            fontSize: 11.5,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _dateBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white60, size: 13),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _showBtn() => ElevatedButton(
        onPressed: _fetchData,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Tampilkan', style: TextStyle(fontSize: 12)),
      );

  Widget _buildHarianFilter() => Row(
        children: [
          const Text('Tanggal:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          _dateBtn(_fmt(_startDate), () => _pickDate(isStart: true)),
          const SizedBox(width: 8),
          _showBtn(),
        ],
      );

  Widget _buildRentangFilter() => Row(
        children: [
          const Text('Dari:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          _dateBtn(_fmt(_startDate), () => _pickDate(isStart: true)),
          const SizedBox(width: 8),
          const Text('s/d:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 6),
          _dateBtn(_fmt(_endDate), () => _pickDate(isStart: false)),
          const SizedBox(width: 8),
          _showBtn(),
        ],
      );

  Widget _buildMingguanFilter() {
    final years = List.generate(5, (i) => (DateTime.now().year - 2 + i).toString());
    return Row(
      children: [
        DropdownButton<String>(
          value: _selectedWeek,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          underline: Container(height: 1, color: Colors.white30),
          items: ['M1', 'M2', 'M3', 'M4', 'M5']
              .map((w) => DropdownMenuItem(value: w, child: Text(w)))
              .toList(),
          onChanged: (v) => setState(() => _selectedWeek = v!),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedMonth,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          underline: Container(height: 1, color: Colors.white30),
          items: _months
              .map((m) => DropdownMenuItem(value: m, child: Text(_monthNames[m]!)))
              .toList(),
          onChanged: (v) => setState(() => _selectedMonth = v!),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedYear,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          underline: Container(height: 1, color: Colors.white30),
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text(y)))
              .toList(),
          onChanged: (v) => setState(() => _selectedYear = v!),
        ),
        const SizedBox(width: 10),
        _showBtn(),
      ],
    );
  }

  Widget _buildErrorBanner() => Container(
        color: const Color(0xFFFEF2F2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      );

  /// ─── 2. INDIKATOR KESEIMBANGAN (BALANCE CHECKER / ZERO DIFFERENCE GUARD) ───
  Widget _buildBalanceCheckerBanner() {
    final s = _summary;
    final pos = _posisiKeuangan;

    double totalKasDebet = (s?['total_kas_debet'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.kasDebet);
    double totalKasKredit = (s?['total_kas_kredit'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.kasKredit);

    double totalPengeluaran = (s?['total_pengeluaran'] as num?)?.toDouble() ??
        _rows.fold(
            0.0,
            (sum, r) =>
                sum +
                r.piutang +
                r.penarikanSw +
                r.penarikanSs +
                r.penarikanSp +
                r.penarikanSh +
                r.penarikanSd +
                r.inventaris +
                r.bankKeluar +
                r.biaya);

    double totalPemasukan = (s?['total_pemasukan'] as num?)?.toDouble() ??
        _rows.fold(
            0.0,
            (sum, r) =>
                sum +
                r.danaDana +
                r.uangPangkal +
                r.simpananSp +
                r.simpananSw +
                r.simpananSs +
                r.simpananSh +
                r.simpananSd +
                r.angsuranPokok +
                r.jasaPinjaman +
                r.dendaPenalti +
                r.provisiPinjaman +
                r.asuransi +
                r.lainLain +
                r.bankMasuk);

    // Keseimbangan sisi Debet dan Kredit
    final double grandTotalDebet = (pos?['total_debet'] ??
            pos?['grand_total_debet'] ??
            s?['grand_total_debit'] ??
            s?['grand_total_debet'] ??
            s?['total_debit'] ??
            s?['total_debet'] as num?)
        ?.toDouble() ??
        (totalKasDebet + totalPengeluaran);

    final double grandTotalKredit = (pos?['total_kredit'] ??
            pos?['grand_total_kredit'] ??
            s?['grand_total_credit'] ??
            s?['grand_total_kredit'] ??
            s?['total_credit'] ??
            s?['total_kredit'] as num?)
        ?.toDouble() ??
        (totalKasKredit + totalPemasukan);

    final double rawDiff = (grandTotalDebet - grandTotalKredit).abs();
    // Zero Difference Guard
    final bool isBalanced = (s?['is_balanced'] == true) || (pos?['is_balanced'] == true) || (rawDiff < 1.0);
    final double diff = isBalanced ? 0.0 : rawDiff;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isBalanced ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBalanced ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBalanced ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBalanced
                      ? 'Jurnal Seimbang (Balance)'
                      : 'Jurnal Tidak Seimbang: Selisih ${TabelarisTableView.formatNum(diff)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Sisi Debet: Rp ${TabelarisTableView.formatNum(grandTotalDebet)}  |  Total Sisi Kredit: Rp ${TabelarisTableView.formatNum(grandTotalKredit)}  |  Periode: $_periodLabel',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isBalanced ? const Color(0xFF166534) : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isBalanced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBalanced ? 'STATUS: OK' : 'STATUS: UNBALANCED',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ─── PAGINATION BAR ────────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    final int totalPages = _totalPages;
    final int safePage = _currentPage.clamp(1, totalPages);
    final int totalItems = _rows.length;
    final int startItem = totalItems == 0 ? 0 : (safePage - 1) * _pageSize + 1;
    final int endItem = (safePage * _pageSize > totalItems) ? totalItems : safePage * _pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 680;
          if (isNarrow) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Data $startItem-$endItem dari $totalItems transaksi',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    _pageSizeDropdown(),
                  ],
                ),
                const SizedBox(height: 6),
                _paginationButtons(),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Menampilkan $startItem - $endItem dari $totalItems transaksi',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 14),
                  const Text('Baris per hal:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  _pageSizeDropdown(),
                ],
              ),
              _paginationButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _pageSizeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _pageSize,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: 25, child: Text('25 baris')),
            DropdownMenuItem(value: 50, child: Text('50 baris')),
            DropdownMenuItem(value: 100, child: Text('100 baris')),
            DropdownMenuItem(value: 200, child: Text('200 baris')),
          ],
          onChanged: (newSize) {
            if (newSize != null && newSize > 0) {
              setState(() {
                _pageSize = newSize;
                _currentPage = 1;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _paginationButtons() {
    final int totalPages = _totalPages;
    final int safePage = _currentPage.clamp(1, totalPages);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageNavBtn(
          icon: Icons.first_page_rounded,
          tooltip: 'Halaman Pertama',
          enabled: safePage > 1,
          onPressed: () => setState(() => _currentPage = 1),
        ),
        const SizedBox(width: 4),
        _pageNavBtn(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Halaman Sebelumnya',
          enabled: safePage > 1,
          onPressed: () => setState(() => _currentPage = (_currentPage - 1).clamp(1, totalPages)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Halaman $safePage dari $totalPages',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ),
        const SizedBox(width: 8),
        _pageNavBtn(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Halaman Selanjutnya',
          enabled: safePage < totalPages,
          onPressed: () => setState(() => _currentPage = (_currentPage + 1).clamp(1, totalPages)),
        ),
        const SizedBox(width: 4),
        _pageNavBtn(
          icon: Icons.last_page_rounded,
          tooltip: 'Halaman Terakhir',
          enabled: safePage < totalPages,
          onPressed: () => setState(() => _currentPage = totalPages),
        ),
      ],
    );
  }

  Widget _pageNavBtn({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  /// ─── 1. TABLE CONTENT ────────────────────────────────────────────────────
  Widget _buildTableContent() {
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_view_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Tidak ada transaksi pada periode ini', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Muat Ulang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final int totalPages = _totalPages;
    final int safePage = _currentPage.clamp(1, totalPages);

    int startIndex = (safePage - 1) * _pageSize;
    if (startIndex < 0) startIndex = 0;
    if (startIndex > _rows.length) startIndex = _rows.length;

    int endIndex = startIndex + _pageSize;
    if (endIndex > _rows.length) endIndex = _rows.length;
    if (endIndex < startIndex) endIndex = startIndex;

    final List<TabelarisRow> pageRows = _rows.sublist(startIndex, endIndex);

    return TabelarisTableView(
      allRows: _rows,
      pageRows: pageRows,
      startIndex: startIndex,
      horizontalScrollController: _hScroll,
      apiSaldoHalLalu: _saldoHalLalu,
      apiJumlahSdHalIni: _jumlahSdHalIni,
    );
  }

  /// ─── 3. KOTAK SALDO / CARD RINGKASAN DI BAWAH TABEL (POSISI KEUANGAN) ─────
  Widget _buildSummaryCards() {
    final s = _summary;
    final pos = _posisiKeuangan;

    // 1. Saldo Piutang (Pinjaman Aktif Riil dari posisi_keuangan)
    final double piutangCair = (s?['total_piutang'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.piutang);
    final double angsuranPokok = (s?['total_angsuran_pokok'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.angsuranPokok);
    final double saldoPiutang = (pos?['saldo_piutang'] ??
            pos?['piutang'] ??
            pos?['total_piutang_pinjaman'] ??
            s?['saldo_piutang'] as num?)
        ?.toDouble() ??
        (piutangCair - angsuranPokok);

    // 2. Saldo Bank BRI (Rekening Riil dari posisi_keuangan)
    final double bankMasuk = (s?['total_bank_masuk'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.bankMasuk);
    final double bankKeluar = (s?['total_bank_keluar'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.bankKeluar);
    final double saldoBankBri = (pos?['saldo_bank_bri'] ??
            pos?['saldo_bank'] ??
            pos?['bank_bri'] ??
            s?['saldo_bank_bri'] ??
            s?['saldo_bank'] as num?)
        ?.toDouble() ??
        (bankMasuk - bankKeluar);

    // 3. Total Simpanan (SP, SW, SS Riil dari posisi_keuangan)
    final double sp = ((s?['total_simpanan_sp'] ?? 0) - (s?['total_penarikan_sp'] ?? 0) as num).toDouble();
    final double sw = ((s?['total_simpanan_sw'] ?? 0) - (s?['total_penarikan_sw'] ?? 0) as num).toDouble();
    final double ss = ((s?['total_simpanan_ss'] ?? 0) - (s?['total_penarikan_ss'] ?? 0) as num).toDouble();
    final double totalSimpanan = (pos?['total_simpanan'] ??
            pos?['simpanan'] ??
            pos?['simpanan_anggota'] ??
            s?['total_simpanan'] as num?)
        ?.toDouble() ??
        (sp + sw + ss == 0
            ? _rows.fold(0.0, (sum, r) => sum + (r.simpananSp - r.penarikanSp) + (r.simpananSw - r.penarikanSw) + (r.simpananSs - r.penarikanSs))
            : (sp + sw + ss));

    // 4. Saldo Kas Brankas (Kas Riil dari posisi_keuangan)
    final double kasDebet = (s?['total_kas_debet'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.kasDebet);
    final double kasKredit = (s?['total_kas_kredit'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.kasKredit);
    final double saldoKasBrankas = (pos?['saldo_kas_brankas'] ??
            pos?['saldo_kas'] ??
            pos?['kas_brankas'] ??
            pos?['kas_laci'] ??
            s?['saldo_kas_brankas'] ??
            s?['saldo_kas'] as num?)
        ?.toDouble() ??
        (kasDebet - kasKredit);

    // 5. Estimasi SHU (Laba Riil Berjalan dari posisi_keuangan)
    final double pendapatan = ((s?['total_jasa_pinjaman'] ?? 0) +
        (s?['total_provisi_pinjaman'] ?? 0) +
        (s?['total_denda_penalti'] ?? 0) +
        (s?['total_uang_pangkal'] ?? 0) +
        (s?['total_lain_lain'] ?? 0) as num).toDouble();
    final double biaya = (s?['total_biaya'] as num?)?.toDouble() ??
        _rows.fold(0.0, (sum, r) => sum + r.biaya);
    final double estimasiShu = (pos?['estimasi_shu'] ??
            pos?['shu'] ??
            pos?['shu_berjalan'] ??
            pos?['laba_berjalan'] ??
            s?['estimasi_shu'] as num?)
        ?.toDouble() ??
        (pendapatan > 0
            ? (pendapatan - biaya)
            : _rows.fold(
                0.0,
                (sum, r) =>
                    sum +
                    (r.jasaPinjaman + r.provisiPinjaman + r.dendaPenalti + r.uangPangkal + r.lainLain) -
                    r.biaya));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryCard(
                  title: 'Saldo Piutang',
                  value: _fmtCurrency(saldoPiutang),
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Saldo Bank BRI',
                  value: _fmtCurrency(saldoBankBri),
                  icon: Icons.account_balance_rounded,
                  accentColor: const Color(0xFF0284C7),
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Total Simpanan (SP, SW, SS)',
                  value: _fmtCurrency(totalSimpanan),
                  icon: Icons.savings_outlined,
                  accentColor: const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Saldo Kas Brankas',
                  value: _fmtCurrency(saldoKasBrankas),
                  icon: Icons.payments_outlined,
                  accentColor: const Color(0xFF059669),
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Estimasi SHU',
                  value: _fmtCurrency(estimasiShu),
                  icon: Icons.trending_up_rounded,
                  accentColor: const Color(0xFFD97706),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
