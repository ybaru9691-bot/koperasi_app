import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

///  Halaman Parameter SHU Koperasi — input SHU bulanan 12 bulan siklus Jun–Mei
class ShuParameterScreen extends StatefulWidget {
  const ShuParameterScreen({super.key});

  @override
  State<ShuParameterScreen> createState() => _ShuParameterScreenState();
}

class _ShuParameterScreenState extends State<ShuParameterScreen> {
  bool _isLoading = true;
  bool _isSavingAll = false;
  String? _errorMessage;

  int _selectedFiscalYear = DateTime.now().year;
  String _fiscalPeriodLabel = '';

  List<Map<String, dynamic>> _benchmarks = [];
  final List<TextEditingController> _shuControllers = [];
  final List<TextEditingController> _pctControllers = [];
  final List<bool> _isDirty = [];
  final List<bool> _isSavingRow = [];

  static const _pageTitle = 'Parameter SHU Koperasi';

  @override
  void initState() {
    super.initState();
    _selectedFiscalYear = DateTime.now().year;
    _fetchBenchmarks();
  }

  @override
  void dispose() {
    for (final c in _shuControllers) { c.dispose(); }
    for (final c in _pctControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _fetchBenchmarks() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    for (final c in _shuControllers) { c.dispose(); }
    for (final c in _pctControllers) { c.dispose(); }
    _shuControllers.clear();
    _pctControllers.clear();
    _isDirty.clear();
    _isSavingRow.clear();

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final uri = Uri.parse(
        '${AuthService.staticBaseUrl}/manager/coop-benchmarks?fiscal_year=$_selectedFiscalYear',
      );
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          final List<dynamic> raw = data['benchmarks'] ?? data['months'] ?? [];
          _fiscalPeriodLabel = data['fiscal_period_label'] ?? '';
          _benchmarks = raw.map((e) => Map<String, dynamic>.from(e)).toList();

          for (final b in _benchmarks) {
            final netIncome = (b['net_income'] as num?)?.toDouble() ?? 0.0;
            final pct = (b['dividend_allocation_percent'] as num?)?.toDouble() ?? 25.0;
            _shuControllers.add(TextEditingController(text: _formatRaw(netIncome.toInt())));
            _pctControllers.add(TextEditingController(text: pct.toStringAsFixed(0)));
            _isDirty.add(false);
            _isSavingRow.add(false);
          }

          for (var i = 0; i < _benchmarks.length; i++) {
            final idx = i;
            _shuControllers[idx].addListener(() => _onFieldChanged(idx));
            _pctControllers[idx].addListener(() => _onFieldChanged(idx));
          }

          setState(() => _isLoading = false);
        } else {
          throw Exception(body['message'] ?? 'Gagal memuat data');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Gagal memuat parameter SHU: $e'; });
    }
  }

  void _onFieldChanged(int idx) {
    if (!mounted) return;
    setState(() => _isDirty[idx] = true);
  }

  Future<void> _saveRow(int idx) async {
    if (!mounted || _isSavingRow[idx]) return;
    final b = _benchmarks[idx];
    final rawShu = _parseRawInput(_shuControllers[idx].text);
    final pct = double.tryParse(_pctControllers[idx].text) ?? 25.0;

    setState(() => _isSavingRow[idx] = true);
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/coop-benchmarks/update');
      final response = await http.post(uri,
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token' },
        body: jsonEncode({ 'fiscal_year': _selectedFiscalYear, 'month': b['month'], 'net_income': rawShu, 'dividend_allocation_percent': pct }),
      );

      if (!mounted) return;
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        setState(() { _isDirty[idx] = false; _isSavingRow[idx] = false; });
        _showSnack('${b['month_name']} berhasil disimpan ✓', isError: false);
        _fetchBenchmarks();
      } else {
        throw Exception(body['message'] ?? 'Gagal menyimpan');
      }
    } catch (e) {
      if (mounted) { setState(() => _isSavingRow[idx] = false); _showSnack('Gagal simpan: $e', isError: true); }
    }
  }

  Future<void> _saveAll() async {
    if (!mounted || _isSavingAll) return;
    setState(() => _isSavingAll = true);

    final batchItems = List.generate(_benchmarks.length, (i) => {
      'month': _benchmarks[i]['month'],
      'net_income': _parseRawInput(_shuControllers[i].text),
      'dividend_allocation_percent': double.tryParse(_pctControllers[i].text) ?? 25.0,
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/coop-benchmarks/update');
      final response = await http.post(uri,
        headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token' },
        body: jsonEncode({ 'fiscal_year': _selectedFiscalYear, 'benchmarks': batchItems }),
      );

      if (!mounted) return;
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        _showSnack('Semua parameter berhasil disimpan ✓', isError: false);
        _fetchBenchmarks();
      } else {
        throw Exception(body['message'] ?? 'Gagal menyimpan');
      }
    } catch (e) {
      if (mounted) _showSnack('Gagal simpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingAll = false);
    }
  }

  double _parseRawInput(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0.0;
  }

  String _formatRaw(int value) {
    if (value == 0) return '';
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.',
    );
  }

  Map<String, double> _computePreview(int idx) {
    final rawShu = _parseRawInput(_shuControllers[idx].text);
    final pct = double.tryParse(_pctControllers[idx].text) ?? 25.0;
    final b = _benchmarks[idx];
    final totalShares = (b['total_coop_shares'] as num?)?.toDouble() ?? 0.0;
    final lembar = totalShares / 1000.0;
    final danaDev = rawShu * (pct / 100.0);
    final perLembar = lembar > 0 ? danaDev / lembar : 0.0;
    return { 'dana_deviden': danaDev, 'per_lembar': perLembar };
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _fmtCurrency(double v) {
    if (v <= 0) return 'Rp 0';
    return 'Rp ${v.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _shortDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length < 3) return isoDate;
      const monthNames = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      final m = int.tryParse(parts[1]) ?? 0;
      final y = parts[0].substring(2);
      return '${parts[2]} ${monthNames[m]} $y';
    } catch (_) { return isoDate; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Text(_pageTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.surface,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedFiscalYear,
                    items: List.generate(5, (i) {
                      final y = DateTime.now().year - 1 + i;
                      return DropdownMenuItem(value: y, child: Text('Tahun Buku $y', style: const TextStyle(fontSize: 13)));
                    }),
                    onChanged: (v) {
                      if (v != null && v != _selectedFiscalYear) {
                        setState(() => _selectedFiscalYear = v);
                        _fetchBenchmarks();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSavingAll ? null : _saveAll,
                icon: _isSavingAll
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Simpan Semua'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_fiscalPeriodLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Periode: $_fiscalPeriodLabel  •  Siklus cut-off tanggal 21 s/d 20 setiap bulan',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Terjadi kesalahan', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchBenchmarks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildTable(),
          const SizedBox(height: 24),
          _buildFooterNote(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    double totalShu = 0, totalDev = 0;
    for (var i = 0; i < _benchmarks.length; i++) {
      totalShu += _parseRawInput(_shuControllers[i].text);
      totalDev += _computePreview(i)['dana_deviden']!;
    }
    return Row(children: [
      _summaryCard('Total SHU Tahun Buku', totalShu, AppColors.info, Icons.account_balance_rounded),
      const SizedBox(width: 12),
      _summaryCard('Total Alokasi Deviden', totalDev, AppColors.success, Icons.pie_chart_rounded),
      const SizedBox(width: 12),
      _infoCard('Siklus', 'Jun ${_selectedFiscalYear - 1} – Mei $_selectedFiscalYear', Icons.calendar_month_rounded, AppColors.primary),
    ]);
  }

  Widget _summaryCard(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(_fmtCurrency(value), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ])),
        ]),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ]),
      ]),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.adminCanvas),
            headingTextStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 72,
            columnSpacing: 16,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: SizedBox(width: 80,  child: Text('Bulan'))),
              DataColumn(label: SizedBox(width: 145, child: Text('Rentang Cut-off'))),
              DataColumn(label: SizedBox(width: 200, child: Text('SHU Bersih Koperasi (Rp)'))),
              DataColumn(label: SizedBox(width: 90,  child: Text('Alokasi (%)'))),
              DataColumn(label: SizedBox(width: 155, child: Text('Alokasi Deviden'))),
              DataColumn(label: SizedBox(width: 155, child: Text('Est. Nilai Per Lembar'))),
              DataColumn(label: SizedBox(width: 80,  child: Text('Aksi'))),
            ],
            rows: List.generate(_benchmarks.length, _buildRow),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(int idx) {
    final b = _benchmarks[idx];
    final preview = _computePreview(idx);
    final isLocked = b['is_locked'] == true;
    final isDirty = _isDirty[idx];
    final isSaving = _isSavingRow[idx];
    final isManual = b['is_manual_override'] == true;

    final cycleStart = b['cycle_start_date'] ?? '';
    final cycleEnd = b['cycle_end_date'] ?? '';
    final cycleLabel = (cycleStart.isNotEmpty && cycleEnd.isNotEmpty)
        ? '${_shortDate(cycleStart)} – ${_shortDate(cycleEnd)}'
        : '–';

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (isDirty) return AppColors.warningBg.withValues(alpha: 0.5);
        return null;
      }),
      cells: [
        // Bulan
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(b['month_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
          ),
          if (isManual) ...[const SizedBox(width: 4), Tooltip(message: 'Nilai manual (override)', child: Icon(Icons.edit_note_rounded, size: 14, color: AppColors.warning))],
          if (isLocked) ...[const SizedBox(width: 4), const Tooltip(message: 'Periode terkunci', child: Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted))],
        ])),

        // Cut-off
        DataCell(Text(cycleLabel, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),

        // Input SHU
        DataCell(SizedBox(width: 190, child: TextField(
          controller: _shuControllers[idx],
          enabled: !isLocked,
          keyboardType: TextInputType.number,
          inputFormatters: [_ThousandSeparatorFormatter()],
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            filled: true,
            fillColor: isLocked ? AppColors.adminCanvas : AppColors.surface,
          ),
        ))),

        // Alokasi %
        DataCell(SizedBox(width: 80, child: TextField(
          controller: _pctControllers[idx],
          enabled: !isLocked,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]')), LengthLimitingTextInputFormatter(5)],
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            suffixText: '%',
            suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            filled: true,
            fillColor: isLocked ? AppColors.adminCanvas : AppColors.surface,
          ),
        ))),

        // Preview Alokasi Deviden
        DataCell(_previewChip(
          _fmtCurrency(preview['dana_deviden']!),
          isDirty ? AppColors.warningBg : AppColors.successBg,
          isDirty ? AppColors.warning : AppColors.success,
        )),

        // Preview Per Lembar
        DataCell(_previewChip(
          _fmtCurrency(preview['per_lembar']!),
          isDirty ? AppColors.warningBg : AppColors.infoBg,
          isDirty ? AppColors.warning : AppColors.info,
        )),

        // Aksi
        DataCell(isLocked
            ? const Tooltip(message: 'Periode dikunci', child: Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 20))
            : SizedBox(width: 72, child: TextButton.icon(
                onPressed: isDirty && !isSaving ? () => _saveRow(idx) : null,
                icon: isSaving
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary))
                    : Icon(isDirty ? Icons.save_rounded : Icons.check_circle_rounded, size: 15, color: isDirty ? AppColors.primary : AppColors.success),
                label: Text(
                  isSaving ? '...' : isDirty ? 'Simpan' : 'Tersimpan',
                  style: TextStyle(fontSize: 11.5, color: isDirty ? AppColors.primary : AppColors.success),
                ),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
              ))),
      ],
    );
  }

  Widget _previewChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text(
            'Nilai SHU yang dimasukkan di sini akan digunakan sebagai patokan resmi kalkulasi Deviden dan Jasa Saham anggota Buku Biru. '
            'Kolom "Alokasi Deviden" dan "Est. Nilai Per Lembar" diperbarui secara otomatis saat Anda mengubah angka SHU atau persentase. '
            'Klik [Simpan] pada setiap baris untuk menyimpan per bulan, atau [Simpan Semua] untuk menyimpan 12 bulan sekaligus.',
            style: TextStyle(fontSize: 11.5, color: AppColors.info, height: 1.5),
          )),
        ],
      ),
    );
  }
}

/// Custom formatter: auto tambahkan titik sebagai pemisah ribuan
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '').replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.',
    );
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
