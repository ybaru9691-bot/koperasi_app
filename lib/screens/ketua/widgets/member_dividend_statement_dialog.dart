import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/member_statement_pdf_service.dart';

/// Modal Dialog Lembar Buku Saham & Deviden Per Anggota (Individual Statement)
/// Persis Format Audit Fisik CUM Pelita HKBP Ressort Dame (12 Bulan Juni s/d Mei, Siklus 21 s/d 20)
class MemberDividendStatementDialog extends StatefulWidget {
  final int memberId;
  final String? memberName;
  final String? memberNumber;
  final int? fiscalYear;
  final int? month;
  final int? year;

  const MemberDividendStatementDialog({
    super.key,
    required this.memberId,
    this.memberName,
    this.memberNumber,
    this.fiscalYear,
    this.month,
    this.year,
  });

  @override
  State<MemberDividendStatementDialog> createState() => _MemberDividendStatementDialogState();
}

class _MemberDividendStatementDialogState extends State<MemberDividendStatementDialog> {
  final MemberStatementPdfService _pdfService = MemberStatementPdfService();
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  Map<String, dynamic> _data = {};
  Map<String, dynamic> _member = {};
  Map<String, dynamic>? _saldoAwal;
  List<Map<String, dynamic>> _monthlyRecords = [];
  List<Map<String, dynamic>> _coopBenchmarks = [];
  Map<String, dynamic> _rekapitulasi = {};

  @override
  void initState() {
    super.initState();
    _fetchStatement();
  }

  String _formatRupiah(num? amount, {bool showDashIfZero = false}) {
    if (amount == null || (amount == 0 && showDashIfZero)) return '-';
    if (amount == 0) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatNumber(num? amount, {bool showBlankIfZero = false}) {
    if (amount == null || (amount == 0 && showBlankIfZero)) return '';
    return NumberFormat.decimalPattern('id_ID').format(amount);
  }

  Future<void> _fetchStatement() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _pdfService.fetchStatement(
        widget.memberId,
        fiscalYear: widget.fiscalYear,
        month: widget.month,
        year: widget.year,
      );

      if (!mounted) return;

      setState(() {
        _data = Map<String, dynamic>.from(data);
        _member = Map<String, dynamic>.from(data['member'] ?? {});
        _saldoAwal = data['saldo_awal'] != null ? Map<String, dynamic>.from(data['saldo_awal']) : null;
        _monthlyRecords = List<Map<String, dynamic>>.from(data['monthly_records'] ?? []);
        _coopBenchmarks = List<Map<String, dynamic>>.from(data['coop_benchmarks'] ?? []);
        _rekapitulasi = Map<String, dynamic>.from(data['rekapitulasi'] ?? {});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat lembar buku saham: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final String memberName = _member['name'] ?? widget.memberName ?? 'Anggota';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Mengunduh Slip Buku Saham & Deviden ($memberName)...'),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      await _pdfService.exportPdf(
        widget.memberId,
        fiscalYear: widget.fiscalYear,
        month: widget.month,
        year: widget.year,
        memberName: memberName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai unduhan PDF: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String memberName = _member['name'] ?? widget.memberName ?? 'Anggota';
    final String memberNumber = _member['member_number'] ?? widget.memberNumber ?? '-';
    final String periodLabel = _data['fiscal_period_label'] ?? 'Tahun Buku';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1020,
          maxHeight: 880,
        ),
        child: Column(
          children: [
            // 1. HEADER DIALOG
            _buildHeader(memberName, memberNumber, periodLabel),

            // 2. MAIN BODY
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF0D6E47)),
                          SizedBox(height: 12),
                          Text(
                            'Memuat lembar kerja buku saham & deviden anggota...',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchStatement,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kop & Identitas Anggota
                              _buildPaperHeader(),

                              const SizedBox(height: 10),

                              // Tabel 12 Baris Mutasi Bulanan
                              _buildMonthlyTable(),

                              const SizedBox(height: 12),

                              // Bagian Bawah: Patokan Koperasi (Kiri) & Rekapitulasi (Kanan)
                              _buildBottomSection(),
                            ],
                          ),
                        ),
            ),

            // 3. FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String memberName, String memberNumber, String periodLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.description_outlined, color: Color(0xFF1D4ED8), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lembar Buku Saham & Deviden: $memberName ($memberNumber)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  'CUM Pelita HKBP Ressort Dame • Periode Cut-off (21 s/d 20): $periodLabel',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }

  Widget _buildPaperHeader() {
    final String name = _member['name'] ?? '-';
    final String no = _member['member_number'] ?? '-';
    final String address = _member['address'] ?? _member['alamat'] ?? 'Jl.';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KOP Kiri
          const Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CREDO UNION MODIFIKASI PELITA',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Text(
                  'HKBP RESSORT DAME',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Data Anggota Kanan
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldRow('Nama', name.toUpperCase(), isBold: true),
                _buildFieldRow('No.Anggota', no, isBold: true),
                _buildFieldRow('Alamat', address),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black87),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTable() {
    final double totJasa = (_rekapitulasi['total_jasa_saham'] as num?)?.toDouble() ?? 0.0;
    final double totDev = (_rekapitulasi['total_deviden'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris 1: Group Kolom
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: const Row(
              children: [
                SizedBox(width: 58, child: Text('Tanggal', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                SizedBox(width: 52, child: Text('No. Bukti', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('SETORAN', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('PENARIKAN', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('SALDO', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('TOTAL SAHAM', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                SizedBox(width: 52, child: Text('JASA', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                SizedBox(width: 52, child: Text('DEVIDEN', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black54),

          // Header Baris 2: Sub-Kolom (SW | SS | SP)
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: const Row(
              children: [
                SizedBox(width: 58),
                SizedBox(width: 52),
                // SETORAN
                Expanded(flex: 1, child: Text('SW', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SP', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                // PENARIKAN
                Expanded(flex: 1, child: Text('SW', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SP', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                // SALDO
                Expanded(flex: 1, child: Text('SW', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SS', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('SP', textAlign: TextAlign.right, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold))),
                // TOTAL, JASA, DEVIDEN
                Expanded(flex: 2, child: SizedBox()),
                SizedBox(width: 52),
                SizedBox(width: 52),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black),

          // Baris Saldo Awal (sebelum Juni / per 20 Mei)
          if (_saldoAwal != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: 58),
                  const SizedBox(width: 52),
                  // SETORAN
                  const Expanded(flex: 1, child: SizedBox()),
                  const Expanded(flex: 1, child: SizedBox()),
                  const Expanded(flex: 1, child: SizedBox()),
                  // PENARIKAN
                  const Expanded(flex: 1, child: SizedBox()),
                  const Expanded(flex: 1, child: SizedBox()),
                  const Expanded(flex: 1, child: SizedBox()),
                  // SALDO
                  Expanded(flex: 1, child: Text(_formatNumber(_saldoAwal!['saldo_sw']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                  Expanded(flex: 1, child: Text(_formatNumber(_saldoAwal!['saldo_ss']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                  Expanded(flex: 1, child: Text(_formatNumber((_saldoAwal!['saldo_sp'] as num? ?? 0) > 0 ? _saldoAwal!['saldo_sp'] : 200000), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                  Expanded(flex: 2, child: Text(_formatNumber(_saldoAwal!['total_saham']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 52),
                  const SizedBox(width: 52),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black12),
          ],

          // Baris-baris Mutasi 12 Bulan
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _monthlyRecords.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.black12),
            itemBuilder: (ctx, idx) {
              final r = _monthlyRecords[idx];
              final bool isAwal = r['is_saldo_awal'] == true;
              if (isAwal) return const SizedBox.shrink();

              final String tgl = (r['transaction_date'] ?? r['tgl'] ?? r['date'] ?? '').toString();
              final String noBukti = (r['voucher_no'] ?? r['no_bukti'] ?? '').toString();
              final double swIn = ((r['setoran_sw'] ?? r['setor_sw']) as num?)?.toDouble() ?? 0.0;
              final double ssIn = ((r['setoran_ss'] ?? r['setor_ss']) as num?)?.toDouble() ?? 0.0;
              final double spIn = ((r['setoran_sp'] ?? r['setor_sp']) as num?)?.toDouble() ?? 0.0;
              final double swOut = ((r['penarikan_sw'] ?? r['tarik_sw']) as num?)?.toDouble() ?? 0.0;
              final double ssOut = ((r['penarikan_ss'] ?? r['tarik_ss']) as num?)?.toDouble() ?? 0.0;
              final double spOut = ((r['penarikan_sp'] ?? r['tarik_sp']) as num?)?.toDouble() ?? 0.0;
              final double swBal = ((r['saldo']?['sw'] ?? r['saldo_sw']) as num?)?.toDouble() ?? 0.0;
              final double ssBal = ((r['saldo']?['ss'] ?? r['saldo_ss']) as num?)?.toDouble() ?? 0.0;
              final double rawSpBal = ((r['saldo']?['sp'] ?? r['saldo_sp']) as num?)?.toDouble() ?? 0.0;
              final double spBal = rawSpBal > 0 ? rawSpBal : 200000.0;
              final double totSaham = (r['total_saham'] as num?)?.toDouble() ?? (swBal + ssBal + spBal);
              final double jasa = ((r['jasa_saham'] ?? r['jasa']) as num?)?.toDouble() ?? 0.0;
              final double dev = (r['deviden'] as num?)?.toDouble() ?? 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                color: idx.isEven ? Colors.white : const Color(0xFFFAFAFA),
                child: Row(
                  children: [
                    SizedBox(width: 58, child: Text(tgl, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600))),
                    SizedBox(width: 52, child: Text(noBukti, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
                    // SETORAN
                    Expanded(flex: 1, child: Text(_formatNumber(swIn, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(ssIn, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(spIn, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    // PENARIKAN
                    Expanded(flex: 1, child: Text(_formatNumber(swOut, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(ssOut, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(spOut, showBlankIfZero: true), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    // SALDO
                    Expanded(flex: 1, child: Text(_formatNumber(swBal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(ssBal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    Expanded(flex: 1, child: Text(_formatNumber(spBal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
                    // TOTAL SAHAM, JASA, DEVIDEN
                    Expanded(flex: 2, child: Text(_formatNumber(totSaham), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(width: 52, child: Text(_formatNumber(jasa, showBlankIfZero: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Color(0xFF0369A1)))),
                    SizedBox(width: 52, child: Text(_formatNumber(dev, showBlankIfZero: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0D6E47)))),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1, color: Colors.black),
          // Footer Total Row
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Spacer(),
                const Text('TOTAL: ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                SizedBox(width: 52, child: Text(_formatNumber(totJasa), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)))),
                SizedBox(width: 52, child: Text(_formatNumber(totDev), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0D6E47)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final double totJasa = (_rekapitulasi['total_jasa_saham'] as num?)?.toDouble() ?? 0.0;
    final double totDev = (_rekapitulasi['total_deviden'] as num?)?.toDouble() ?? 0.0;
    final double duka = (_rekapitulasi['potongan_duka'] as num?)?.toDouble() ?? 20000.0;
    final double tunggakanSw = (_rekapitulasi['potongan_tunggakan_sw'] as num?)?.toDouble() ?? 0.0;
    final double netPenerimaan = (_rekapitulasi['total_penerimaan_bersih'] as num?)?.toDouble() ?? 0.0;
    final String memberName = _member['name'] ?? widget.memberName ?? 'Anggota';

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kiri: Tabel Patokan Koperasi (12 Bulan)
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tabel Patokan Perhitungan Koperasi (12 Bulan):',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.0),
                        1: FlexColumnWidth(2.2),
                        2: FlexColumnWidth(2.6),
                        3: FlexColumnWidth(1.6),
                        4: FlexColumnWidth(1.9),
                        5: FlexColumnWidth(1.4),
                      },
                      border: TableBorder.all(color: Colors.black26, width: 0.5),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            Padding(padding: EdgeInsets.all(2), child: Text('Bulan', textAlign: TextAlign.center, style: TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(2), child: Text('Total Saham', textAlign: TextAlign.right, style: TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(2), child: Text('SHU setelah dikurangi biaya tiap thn', textAlign: TextAlign.right, style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(2), child: Text('25% SHU', textAlign: TextAlign.right, style: TextStyle(fontSize: 7.0, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(2), child: Text('Harga Saham (Total Saham/1000)', textAlign: TextAlign.right, style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(2), child: Text('Harga Saham E30xD30', textAlign: TextAlign.center, style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ..._coopBenchmarks.map((b) {
                          final double shu = (b['shu_bersih_koperasi'] as num?)?.toDouble() ?? 0.0;
                          final double saham = (b['total_saham_koperasi'] as num?)?.toDouble() ?? 0.0;
                          final double lembar = (b['jumlah_lembar_koperasi'] as num?)?.toDouble() ?? (saham / 1000.0);
                          final double dana25 = (b['dana_deviden_25'] as num?)?.toDouble() ?? (shu * 0.25);
                          final int rateDisplay = (b['harga_saham_display'] as num?)?.toInt() ?? ((b['harga_deviden_per_lembar'] as num?)?.toInt() ?? 0);

                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(2), child: Text(b['month_name'] ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 7.5))),
                              Padding(padding: const EdgeInsets.all(2), child: Text(_formatNumber(saham), textAlign: TextAlign.right, style: const TextStyle(fontSize: 7.5))),
                              Padding(padding: const EdgeInsets.all(2), child: Text(_formatNumber(shu), textAlign: TextAlign.right, style: const TextStyle(fontSize: 7.5))),
                              Padding(padding: const EdgeInsets.all(2), child: Text(_formatNumber(dana25), textAlign: TextAlign.right, style: const TextStyle(fontSize: 7.5))),
                              Padding(padding: const EdgeInsets.all(2), child: Text(_formatNumber(lembar), textAlign: TextAlign.right, style: const TextStyle(fontSize: 7.5))),
                              Padding(padding: const EdgeInsets.all(2), child: Text('$rateDisplay', textAlign: TextAlign.center, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Kanan: Kotak Rekapitulasi Akhir
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRekapLine('Jasa Saham', _formatRupiah(totJasa)),
                    _buildRekapLine('Deviden', _formatRupiah(totDev)),
                    _buildRekapLine('DANA DUKA', _formatRupiah(duka)),
                    _buildRekapLine('Tunggakan Sw', tunggakanSw > 0 ? _formatRupiah(tunggakanSw) : '0'),
                    const Divider(height: 10, color: Colors.black),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Penerimaan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text(
                          _formatRupiah(netPenerimaan),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Pengesahan / Lembar Tanda Tangan 3 Kolom
        _buildSignatureSection(memberName),
      ],
    );
  }

  Widget _buildSignatureSection(String memberName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Diterima Oleh (Anggota),', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                Text('( ${memberName.toUpperCase()} )', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Pembukuan / Kasir,', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                const Text('( .................................................. )', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Manager CUM Pelita,', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                const Text('( .................................................. )', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRekapLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: (_isLoading || _isExporting) ? null : _exportPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(
              _isExporting ? 'Menyiapkan PDF...' : 'Export PDF Slip Anggota',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
