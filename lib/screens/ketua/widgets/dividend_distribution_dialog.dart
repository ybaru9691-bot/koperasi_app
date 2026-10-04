import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/auth_service.dart';
import 'member_dividend_statement_dialog.dart';

/// Modal Dialog Kalkulasi & Eksekusi Pembagian Deviden Buku Biru (SHU)
class DividendDistributionDialog extends StatefulWidget {
  final int month;
  final int year;
  final int? fiscalYear;
  final String periodName;
  final double defaultPercentage;
  final double? initialNetProfit;
  final VoidCallback? onSuccess;

  const DividendDistributionDialog({
    super.key,
    required this.month,
    required this.year,
    this.fiscalYear,
    required this.periodName,
    this.defaultPercentage = 25.0,
    this.initialNetProfit,
    this.onSuccess,
  });

  @override
  State<DividendDistributionDialog> createState() => _DividendDistributionDialogState();
}

class _DividendDistributionDialogState extends State<DividendDistributionDialog> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isExportingPdf = false;
  String? _errorMessage;

  late TextEditingController _percentageController;
  late TextEditingController _voucherNoController;
  late TextEditingController _notesController;
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _members = [];
  String _searchQuery = '';
  String? _voucherErrorText;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _percentageController = TextEditingController(
      text: widget.defaultPercentage.toStringAsFixed(0),
    );
    _voucherNoController = TextEditingController(
      text: 'BM-DIV-${widget.year}${widget.month.toString().padLeft(2, '0')}',
    );
    _notesController = TextEditingController();
    _fetchPreview();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _percentageController.dispose();
    _voucherNoController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  /// 📡 1. Fetch Preview Kalkulasi Deviden dari Backend
  Future<void> _fetchPreview() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Sesi login tidak valid. Silakan login kembali.';
          _isLoading = false;
        });
        return;
      }

      final double percentage = double.tryParse(_percentageController.text.trim()) ?? widget.defaultPercentage;
      final uri = Uri.parse(
        '${AuthService.staticBaseUrl}/manager/dividends/preview?month=${widget.month}&year=${widget.year}&percentage=$percentage',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        final summary = Map<String, dynamic>.from(data['summary'] ?? {});
        final rawMembers = data['members'] ?? data['details'] ?? [];
        
        List<Map<String, dynamic>> parsedMembers = [];
        if (rawMembers is List) {
          parsedMembers = rawMembers.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        setState(() {
          _summary = summary;
          _members = parsedMembers;
          if (_voucherNoController.text.isEmpty && summary['default_voucher_no'] != null) {
            _voucherNoController.text = summary['default_voucher_no'].toString();
          }
          _isLoading = false;
        });
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _errorMessage = body['message'] ?? 'Gagal memuat pratinjau deviden (HTTP ${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat data: $e';
        _isLoading = false;
      });
    }
  }

  /// 📄 2. Unduh / Export Cetak Dokumen PDF Laporan Deviden Resmi
  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final token = await AuthService().getToken();
      final double percentage = double.tryParse(_percentageController.text.trim()) ?? widget.defaultPercentage;
      final String baseUrl = AuthService.staticBaseUrl;
      final String tokenParam = (token != null && token.isNotEmpty) ? '&token=$token' : '';
      final String downloadUrl = '$baseUrl/manager/dividends/export-pdf?month=${widget.month}&year=${widget.year}&percentage=$percentage$tokenParam';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Mengunduh Laporan Deviden PDF (${widget.periodName})...'),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      html.window.open(downloadUrl, '_blank');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai unduhan PDF: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  /// 📖 Buka Modal Lembar Buku Saham & Deviden Anggota (12 Bulan Siklus 21-20)
  void _openMemberStatement(Map<String, dynamic> member) {
    final int? memberId = member['member_id'] ?? member['id'];
    if (memberId == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MemberDividendStatementDialog(
        memberId: memberId,
        memberName: member['name']?.toString(),
        memberNumber: member['member_number']?.toString(),
        fiscalYear: widget.fiscalYear,
        month: widget.month,
        year: widget.year,
      ),
    );
  }

  /// 🚀 3. Eksekusi Distribusi Deviden ke Simpanan Sukarela
  Future<void> _submitDistribution() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String voucherNo = _voucherNoController.text.trim();
    if (voucherNo.isEmpty) {
      setState(() {
        _voucherErrorText = 'Nomor bukti wajib diisi.';
      });
      return;
    }

    // Modal Konfirmasi Eksekusi
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final int eligibleCount = _summary['eligible_members_count'] ?? 0;
        final double totalDist = (_summary['total_distributed_dividend'] as num?)?.toDouble() ?? 0.0;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF0D6E47), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Konfirmasi Pembagian Deviden',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deviden sebesar ${_formatRupiah(totalDist)} akan otomatis ditambahkan ke saldo Simpanan Sukarela (SS) seluruh anggota Buku Biru yang berhak ($eligibleCount anggota) untuk periode ${widget.periodName}.',
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.adminNavy),
                    const SizedBox(width: 8),
                    Text(
                      'No. Bukti: $voucherNo',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tindakan ini akan membuat mutasi saldo simpanan dan mencatat Jurnal Bukti Memorial. Lanjutkan?',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6E47),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Eksekusi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _voucherErrorText = null;
    });

    try {
      final token = await AuthService().getToken();
      final double percentage = double.tryParse(_percentageController.text.trim()) ?? widget.defaultPercentage;

      final uri = Uri.parse('${AuthService.staticBaseUrl}/manager/dividends/distribute');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'month': widget.month,
          'year': widget.year,
          'percentage': percentage,
          'voucher_no': voucherNo,
          'notes': _notesController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && (body['success'] == true || body['status'] == 'success')) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] ?? 'Deviden Buku Biru periode ${widget.periodName} berhasil didistribusikan!',
            ),
            backgroundColor: const Color(0xFF0D6E47),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 422) {
        final errorMsg = body['message'] ?? 'Validasi gagal.';
        setState(() {
          _voucherErrorText = errorMsg;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Gagal mendistribusikan deviden (HTTP ${response.statusCode}).'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan jaringan: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAlreadyDistributed = _summary['is_already_distributed'] == true;

    // Filter members list based on search query
    final filteredMembers = _members.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (m['name'] ?? '').toString().toLowerCase();
      final no = (m['member_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || no.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 920,
          maxHeight: 760,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. HEADER DIALOG
              _buildHeader(isAlreadyDistributed),

              // 2. MAIN CONTENT SCROLLABLE
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0D6E47)),
                            SizedBox(height: 12),
                            Text(
                              'Menghitung kalkulasi deviden Buku Biru...',
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
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _fetchPreview,
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Coba Lagi'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.adminNavy,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Warning Banner If Already Distributed
                                if (isAlreadyDistributed)
                                  _buildAlreadyDistributedBanner(),

                                // Voucher & Notes Input Row
                                _buildVoucherInputs(),

                                const SizedBox(height: 16),

                                // Member Table Section with Virtualized ListView.builder
                                _buildMemberTableSection(filteredMembers),
                              ],
                            ),
                          ),
              ),

              // 3. FOOTER ACTIONS (Includes Export PDF Button)
              _buildFooterActions(isAlreadyDistributed),
            ],
          ),
        ),
      ),
    );
  }

  /// 🏆 1. Header Dialog
  Widget _buildHeader(bool isAlreadyDistributed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D6E47), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pembagian Deviden Anggota (Buku Biru)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Periode Laporan: ${widget.periodName} • Penyaluran Langsung ke Simpanan Sukarela (SS)',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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

  /// ⚠️ Banner Peringatan Sudah Pernah Dieksekusi
  Widget _buildAlreadyDistributedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deviden Periode Ini Sudah Pernah Didistribusikan',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mutasi simpanan sukarela dan Bukti Memorial (${_summary['default_voucher_no'] ?? '-'}) sudah tercatat di sistem.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// 📝 3. Voucher & Notes Inputs
  Widget _buildVoucherInputs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Nomor Bukti
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Nomor Bukti Transaksi (BM)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                    ),
                    SizedBox(width: 4),
                    Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _voucherNoController,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Cth: BM-DIV-202609',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: _voucherErrorText,
                    prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.adminNavy),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nomor bukti transaksi wajib diisi.';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_voucherErrorText != null) {
                      setState(() => _voucherErrorText = null);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Field Catatan
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catatan Distribusi (Opsional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Cth: Distribusi Deviden SHU Buku Biru Periode ${widget.periodName}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 👥 4. Member Table Section with Lazy Virtualization (itemExtent 48.0)
  Widget _buildMemberTableSection(List<Map<String, dynamic>> filteredMembers) {
    final int totalCount = _members.length;
    final int eligibleCount = _summary['eligible_members_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar & Search with 300ms Debounce
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Anggota Buku Biru ($totalCount Anggota, $eligibleCount Berhak)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Hanya anggota dengan rekening Buku Biru dan bebas tunggakan SW ≥ 6 bulan yang berhak menerima deviden.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Cari no/nama anggota...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text('No. Anggota', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Nama Anggota', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Total Saham (SP+SW+SS)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Status SW / Kelayakan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Estimasi Deviden', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Virtualized Lazy Table Rows (itemExtent: 48.0 with bounded height 380)
          if (filteredMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Tidak ada anggota yang cocok.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 380,
              child: ListView.builder(
                itemCount: filteredMembers.length,
                itemExtent: 48.0,
                itemBuilder: (context, index) {
                  final m = filteredMembers[index];
                  final String no = m['member_number']?.toString() ?? '-';
                  final String name = m['name']?.toString() ?? 'Anggota';
                  final double totalSaham = (m['total_saham'] as num?)?.toDouble() ?? 0.0;
                  final double devAmount = (m['deviden_amount'] as num?)?.toDouble() ?? 0.0;
                  final bool isEligible = m['is_eligible'] == true;
                  final bool isSwArrears = m['is_sw_arrears'] == true;
                  final String? reason = m['ineligibility_reason'];
                  final double sharePct = (m['share_percentage'] as num?)?.toDouble() ?? 0.0;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openMemberStatement(m),
                      hoverColor: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 48.0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
                          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // No. Anggota (80px)
                            SizedBox(
                              width: 80,
                              child: Text(
                                no,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                              ),
                            ),
                            // Nama Anggota (Flex 3)
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Text('Buku Biru', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                  ),
                                ],
                              ),
                            ),
                            // Total Saham (Flex 3)
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatRupiah(totalSaham),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  if (isEligible && sharePct > 0)
                                    Text(
                                      'Porsi: ${sharePct.toStringAsFixed(3)}%',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            // Status SW / Kelayakan (Flex 3)
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: isSwArrears
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDD5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFED7AA)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.cancel_rounded, size: 12, color: Color(0xFFC2410C)),
                                            SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Gugur Hak SHU (SW ≥ 6 Bln)',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : !isEligible
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.cardBorder),
                                            ),
                                            child: Text(
                                              reason ?? 'Tidak Berhak',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFBBF7D0)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF15803D)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Berhak Deviden',
                                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                                ),
                                              ],
                                            ),
                                          ),
                              ),
                            ),
                            // Estimasi Deviden (Flex 2)
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  isEligible ? _formatRupiah(devAmount) : 'Rp 0',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isEligible ? const Color(0xFF0D6E47) : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 🔘 5. Footer Actions (Includes Export PDF Laporan Button)
  Widget _buildFooterActions(bool isAlreadyDistributed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          // 📄 Tombol Sekunder: Export PDF Laporan (Tetap aktif meski sudah terdistribusi)
          OutlinedButton.icon(
            onPressed: (_isLoading || _isExportingPdf) ? null : _exportPdf,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              side: const BorderSide(color: Color(0xFF475569), width: 1.5),
              foregroundColor: const Color(0xFF334155),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isExportingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Color(0xFF334155), strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF334155)),
            label: const Text(
              'Export PDF Laporan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)),
            ),
          ),

          const Spacer(),

          // Tombol Batal
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 10),

          // Tombol Eksekusi
          ElevatedButton.icon(
            onPressed: (_isSubmitting || _isLoading || isAlreadyDistributed) ? null : _submitDistribution,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6E47),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_rounded, size: 18),
            label: Text(
              _isSubmitting ? 'Memproses Deviden...' : 'Proses & Masukkan ke Simpanan Sukarela',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
