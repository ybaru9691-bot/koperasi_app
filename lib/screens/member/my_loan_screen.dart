import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Model Data Histori Angsuran Pinjaman (Portal Anggota)
class MemberInstallmentRecord {
  final int no;
  final String date;
  final String proofCode;
  final int principalPaid;
  final int remainingBalance;
  final int interestPaid;
  final int penaltyPaid;
  final bool isPaid;

  MemberInstallmentRecord({
    required this.no,
    required this.date,
    required this.proofCode,
    required this.principalPaid,
    required this.remainingBalance,
    required this.interestPaid,
    required this.penaltyPaid,
    required this.isPaid,
  });
}

/// Screen "Pinjaman Saya" khusus Portal Anggota / User (Strict Read-Only)
class MyLoanScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const MyLoanScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<MyLoanScreen> createState() => _MyLoanScreenState();
}

class _MyLoanScreenState extends State<MyLoanScreen> {
  // Data Ringkasan Pinjaman Anggota (Logged-In User) - Mutable State
  final String _memberName = 'Maria Sitindaon';
  final String _memberNo = '2564';
  final String _suratHisabNo = '2026/L-042';
  final String _church = 'HKBP';
  int _totalLoanAmount = 4000000; // Rp 4.000.000
  final double _interestRatePercent = 2.50; // 2.50% / bulan
  int _tenorMonths = 12; // 12 Bulan
  String _collateral = 'BPKB Motor Honda Beat (BM 4914 DC)';
  String _loanPurpose = 'Modal Usaha Toko Kelontong';
  final String _dueDate = '20 Desember 2026';
  final int _monthlyInstallmentTarget = 433333; // ~Rp 433.333 / bulan

  // List Histori Angsuran Anggota (Termasuk Angsuran Sudah Terbayar & Belum Dibayar)
  final List<MemberInstallmentRecord> _installments = [
    MemberInstallmentRecord(
      no: 1,
      date: '15/05/2026',
      proofCode: 'KM 4914',
      principalPaid: 450000,
      remainingBalance: 3550000,
      interestPaid: 100000,
      penaltyPaid: 0,
      isPaid: true,
    ),
    MemberInstallmentRecord(
      no: 2,
      date: '15/06/2026',
      proofCode: 'KM 5102',
      principalPaid: 507000,
      remainingBalance: 3043000,
      interestPaid: 88750,
      penaltyPaid: 0,
      isPaid: true,
    ),
    MemberInstallmentRecord(
      no: 3,
      date: '15/07/2026',
      proofCode: '-',
      principalPaid: 0,
      remainingBalance: 3043000,
      interestPaid: 0,
      penaltyPaid: 0,
      isPaid: false,
    ),
    MemberInstallmentRecord(
      no: 4,
      date: '15/08/2026',
      proofCode: '-',
      principalPaid: 0,
      remainingBalance: 3043000,
      interestPaid: 0,
      penaltyPaid: 0,
      isPaid: false,
    ),
  ];

  // --- KALKULASI DINAMIS ---
  int get _totalPrincipalPaid {
    return _installments
        .where((item) => item.isPaid)
        .fold(0, (sum, item) => sum + item.principalPaid);
  }

  int get _currentRemainingBalance {
    final remaining = _totalLoanAmount - _totalPrincipalPaid;
    return remaining < 0 ? 0 : remaining;
  }

  double get _repaymentProgressRatio {
    if (_totalLoanAmount <= 0) return 0.0;
    final ratio = _totalPrincipalPaid / _totalLoanAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // --- MODAL BOTTOMSHEET PENGAJUAN PINJAMAN BARU (INTERAKTIF & JAMINAN/AGUNAN) ---
  void _showApplyLoanModal() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final collateralController = TextEditingController();
    final purposeController = TextEditingController();
    int selectedTenor = 12;

    num parseNum(String text) {
      final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
      return clean.isEmpty ? 0 : num.parse(clean);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 20,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Header Modal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBackground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pengajuan Pinjaman Baru',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    'Koperasi Credit Union CUM Pelita',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),

                      const Divider(height: 24, color: AppColors.cardBorder),

                      // 1. Jumlah Pinjaman (Rp)
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          final numVal = parseNum(val ?? '');
                          if (numVal <= 0) return 'Nominal pinjaman wajib diisi';
                          if (numVal < 500000) return 'Minimal pengajuan pinjaman Rp 500.000';
                          return null;
                        },
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Jumlah Pinjaman (Rp)',
                          hintText: 'Contoh: 5.000.000',
                          isDense: true,
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2. Jangka Waktu / Tenor (Bulan)
                      DropdownButtonFormField<int>(
                        initialValue: selectedTenor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Jangka Waktu (Tenor)',
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 6, child: Text('6 Bulan')),
                          DropdownMenuItem(value: 12, child: Text('12 Bulan (1 Tahun)')),
                          DropdownMenuItem(value: 18, child: Text('18 Bulan')),
                          DropdownMenuItem(value: 24, child: Text('24 Bulan (2 Tahun)')),
                          DropdownMenuItem(value: 36, child: Text('36 Bulan (3 Tahun)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedTenor = val;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // 3. Jaminan / Agunan (Mandatory Master Data Field)
                      TextFormField(
                        controller: collateralController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Jaminan / Agunan wajib diisi' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Jaminan / Agunan',
                          hintText: 'BPKB Motor / Sertifikat Tanah / BPKB Mobil / dll',
                          isDense: true,
                          prefixIcon: Icon(Icons.security_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4. Tujuan Pinjaman
                      TextFormField(
                        controller: purposeController,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Tujuan pinjaman wajib diisi' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Tujuan Pinjaman',
                          hintText: 'Modal Usaha / Pendidikan Anak / Renovasi / dll',
                          isDense: true,
                          prefixIcon: Icon(Icons.center_focus_strong_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tombol Kirim Pengajuan Pinjaman
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final int newAmount = parseNum(amountController.text).toInt();
                              final String newCollateral = collateralController.text.trim();
                              final String newPurpose = purposeController.text.trim();

                              setState(() {
                                _totalLoanAmount = newAmount;
                                _tenorMonths = selectedTenor;
                                _collateral = newCollateral;
                                _loanPurpose = newPurpose;
                              });

                              Navigator.pop(modalContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Pengajuan Pinjaman "$newPurpose" (${_formatRupiah(newAmount)}) dengan Jaminan: "$newCollateral" BERHASIL DIKIRIM!',
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text(
                            'Kirim Pengajuan Pinjaman',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: widget.onOpenDrawer,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Pinjaman Saya',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KARTU FISIK RINGKASAN PINJAMAN (STRICT READ-ONLY)
            _buildMemberLoanCardHeader(),

            const SizedBox(height: 14),

            // TOMBOL AKSI CEPAT ANGGOTA: "Lihat Tagihan Angsuran" & "Ajukan Baru"
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tagihan Angsuran Ke-3 Jatuh Tempo: $_dueDate (${_formatRupiah(_monthlyInstallmentTarget)})',
                          ),
                          backgroundColor: AppColors.info,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBackground,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.primary, width: 1),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text(
                      'Lihat Tagihan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showApplyLoanModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text(
                      'Ajukan Baru',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. HEADER SECTION HISTORI ANGSURAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat Pembayaran Angsuran',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_installments.where((e) => e.isPaid).length} Terbayar',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 3. TABEL HISTORI ANGSURAN (STRICT READ-ONLY)
            _buildInstallmentHistoryTable(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET KARTU FISIK PINJAMAN ANGGOTA ---
  Widget _buildMemberLoanCardHeader() {
    final progressPercent = (_repaymentProgressRatio * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu Fisik
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_koperasi.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KARTU PINJAMAN CUM PELITA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _church,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  'SH: $_suratHisabNo',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),

          const Divider(height: 24, color: Colors.white24),

          // Highlighting Sisa Saldo Pokok & Total Nominal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SISA SALDO POKOK PINJAMAN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRupiah(_currentRemainingBalance),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL PINJAMAN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRupiah(_totalLoanAmount),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar Pelunasan Pinjaman
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progres Pelunasan ($progressPercent%)',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                  Text(
                    'Terbayar: ${_formatRupiah(_totalPrincipalPaid)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _repaymentProgressRatio,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Grid Info Detail (Angsuran per Bulan, Tenor, Jasa, Jatuh Tempo, Agunan)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMemberDetailItem('Nama Anggota', '$_memberName (Reg $_memberNo)'),
                    _buildMemberDetailItem('Angsuran / Bln', _formatRupiah(_monthlyInstallmentTarget)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMemberDetailItem('Tenor / Jangka', '$_tenorMonths Bulan'),
                    _buildMemberDetailItem('Jasa Pinjaman', '$_interestRatePercent% / bln'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMemberDetailItem('Tujuan Pinjaman', _loanPurpose),
                    _buildMemberDetailItem('Agunan / Jaminan', _collateral),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDetailItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        const SizedBox(height: 1),
        Text(
          val,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- WIDGET TABEL HISTORI ANGSURAN (STRICT READ-ONLY) ---
  Widget _buildInstallmentHistoryTable() {
    if (_installments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text('Belum ada riwayat pembayaran angsuran.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryBackground),
            columnSpacing: 22,
            horizontalMargin: 16,
            headingRowHeight: 46,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('No. Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Angsuran Pokok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Saldo Sisa Pokok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Jasa / Bunga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
              DataColumn(label: Text('Denda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
            ],
            rows: _installments.map((rec) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Ke-${rec.no}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                    ),
                  ),
                  // STATIK UNCLICKABLE BADGE: LUNAS vs BELUM DIBAYAR
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rec.isPaid ? AppColors.successBg : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: rec.isPaid ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        rec.isPaid ? 'LUNAS' : 'BELUM DIBAYAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: rec.isPaid ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(rec.date, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      rec.isPaid ? rec.proofCode : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: rec.isPaid ? FontWeight.bold : FontWeight.normal,
                        color: rec.isPaid ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      rec.isPaid ? _formatRupiah(rec.principalPaid) : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: rec.isPaid ? FontWeight.bold : FontWeight.normal,
                        color: rec.isPaid ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatRupiah(rec.remainingBalance),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      rec.isPaid ? _formatRupiah(rec.interestPaid) : '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: rec.isPaid ? AppColors.textSecondary : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      rec.isPaid ? (rec.penaltyPaid > 0 ? _formatRupiah(rec.penaltyPaid) : 'Rp 0') : '-',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: rec.penaltyPaid > 0 ? FontWeight.bold : FontWeight.normal,
                        color: rec.penaltyPaid > 0 ? AppColors.danger : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
