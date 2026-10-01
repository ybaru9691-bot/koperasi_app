import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Model Data Histori Angsuran Pinjaman (Admin Portal)
class AdminInstallmentRecord {
  final int no;
  final String date;
  final String proofCode;
  final int principalPaid;
  final int remainingBalance;
  final int interestPaid;
  final int penaltyPaid;

  AdminInstallmentRecord({
    required this.no,
    required this.date,
    required this.proofCode,
    required this.principalPaid,
    required this.remainingBalance,
    required this.interestPaid,
    required this.penaltyPaid,
  });
}

/// Screen "Detail Pinjaman & Input Angsuran" khusus Admin / Kasir
class AdminLoanDetailScreen extends StatefulWidget {
  final String memberName;
  final String memberNo;
  final String suratHisabNo;
  final String church;
  final int totalLoanAmount;
  final double interestRatePercent;
  final int tenorMonths;
  final String collateral;
  final String dueDate;
  final VoidCallback? onOpenDrawer;

  const AdminLoanDetailScreen({
    super.key,
    this.memberName = 'Maria Sitindaon',
    this.memberNo = '2564',
    this.suratHisabNo = '2026/L-042',
    this.church = 'HKBP Bethania Duri',
    this.totalLoanAmount = 4000000,
    this.interestRatePercent = 2.50,
    this.tenorMonths = 12,
    this.collateral = 'BPKB Motor Honda Beat (BM 4914 DC)',
    this.dueDate = '20 Desember 2026',
    this.onOpenDrawer,
  });

  @override
  State<AdminLoanDetailScreen> createState() => _AdminLoanDetailScreenState();
}

class _AdminLoanDetailScreenState extends State<AdminLoanDetailScreen> {
  late List<AdminInstallmentRecord> _installments;

  @override
  void initState() {
    super.initState();
    // Pre-populate dummy history dengan format 4 digit angka (contoh: KM 4914, KM 5102)
    _installments = [
      AdminInstallmentRecord(
        no: 1,
        date: '15/05/2026',
        proofCode: 'KM 4914',
        principalPaid: 450000,
        remainingBalance: 3550000,
        interestPaid: 100000,
        penaltyPaid: 0,
      ),
      AdminInstallmentRecord(
        no: 2,
        date: '15/06/2026',
        proofCode: 'KM 5102',
        principalPaid: 507000,
        remainingBalance: 3043000,
        interestPaid: 88750,
        penaltyPaid: 0,
      ),
    ];
  }

  // --- KALKULASI DINAMIS ---
  int get _totalPrincipalPaid {
    return _installments.fold(0, (sum, item) => sum + item.principalPaid);
  }

  int get _currentRemainingBalance {
    final remaining = widget.totalLoanAmount - _totalPrincipalPaid;
    return remaining < 0 ? 0 : remaining;
  }

  double get _repaymentProgressRatio {
    if (widget.totalLoanAmount <= 0) return 0.0;
    final ratio = _totalPrincipalPaid / widget.totalLoanAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // --- MODAL DIALOG INPUT ANGSURAN BARU (KHUSUS ADMIN) ---
  void _showInputAngsuranModal() {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    
    // Auto-generate No. Bukti format 4 digit angka (contoh: KM 5238)
    final nextProofNum = 5235 + _installments.length + 1;
    final proofController = TextEditingController(text: 'KM $nextProofNum');
    
    final principalController = TextEditingController();
    final interestController = TextEditingController();
    final penaltyController = TextEditingController();

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
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pPaid = parseNum(principalController.text);
            final iPaid = parseNum(interestController.text);
            final penPaid = parseNum(penaltyController.text);
            final grandTotalPayment = pPaid + iPaid + penPaid;

            final String formattedDateStr =
                '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';

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
                                child: const Icon(Icons.post_add_rounded, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Input Angsuran Pinjaman',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                  ),
                                  Text(
                                    'Angsuran Ke-${_installments.length + 1} • ${widget.memberName}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

                      // Row 1: Tanggal & No. Bukti (Format 4 Digit: KM 5238)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Tanggal Pembayaran',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                child: Text(formattedDateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: proofController,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'No. Bukti (KM 4 Digit)',
                                isDense: true,
                                prefixIcon: Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Input Angsuran Pokok
                      TextFormField(
                        controller: principalController,
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setModalState(() {}),
                        validator: (val) {
                          final numVal = parseNum(val ?? '');
                          if (numVal <= 0) return 'Nominal angsuran pokok wajib diisi';
                          if (numVal > _currentRemainingBalance) {
                            return 'Nominal melebihi sisa saldo pokok (${_formatRupiah(_currentRemainingBalance)})';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Angsuran Pokok (Rp)',
                          isDense: true,
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Row 2: Jasa / Bunga & Denda (Opsional)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: interestController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setModalState(() {}),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Jasa / Bunga (Rp)',
                                isDense: true,
                                prefixText: 'Rp ',
                                prefixIcon: Icon(Icons.percent_rounded, color: AppColors.primary, size: 18),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: penaltyController,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => setModalState(() {}),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Denda',
                                isDense: true,
                                prefixText: 'Rp ',
                                prefixIcon: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Banner Total Pembayaran Angsuran
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.adminNavy,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL BAYAR ANGSURAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                                SizedBox(height: 2),
                                Text('Pokok + Jasa + Denda', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                            Text(
                              _formatRupiah(grandTotalPayment),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.adminAccent),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Tombol Simpan Transaksi
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final int pNum = pPaid.toInt();
                              final int iNum = iPaid.toInt();
                              final int penNum = penPaid.toInt();
                              final int newRemaining = _currentRemainingBalance - pNum;

                              setState(() {
                                _installments.add(
                                  AdminInstallmentRecord(
                                    no: _installments.length + 1,
                                    date: formattedDateStr,
                                    proofCode: proofController.text.trim(),
                                    principalPaid: pNum,
                                    remainingBalance: newRemaining < 0 ? 0 : newRemaining,
                                    interestPaid: iNum,
                                    penaltyPaid: penNum,
                                  ),
                                );
                              });

                              Navigator.pop(modalContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Angsuran Ke-${_installments.length} (${proofController.text}) BERHASIL DISIMPAN!',
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: const Text('Simpan Transaksi Angsuran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                tooltip: 'Menu Admin',
                onPressed: widget.onOpenDrawer,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Pinjaman Anggota',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.memberName} • Reg ${widget.memberNo}',
              style: const TextStyle(color: AppColors.adminAccent, fontSize: 11),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KARTU RINGKASAN PINJAMAN (ADMIN CARD)
            _buildAdminLoanCardHeader(),

            const SizedBox(height: 18),

            // 2. HEADER SECTION HISTORI ANGSURAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: AppColors.adminNavy, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Riwayat Angsuran',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_installments.length} Transaksi',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showInputAngsuranModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Input Angsuran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 3. TABEL HISTORI ANGSURAN (ADMIN VIEW)
            _buildInstallmentHistoryTable(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET KARTU FISIK PINJAMAN ADMIN ---
  Widget _buildAdminLoanCardHeader() {
    final progressPercent = (_repaymentProgressRatio * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.adminNavy, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu
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
                        'KARTU PINJAMAN ANGGOTA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'CUM PELITA • ${widget.church}',
                        style: const TextStyle(fontSize: 10, color: AppColors.adminAccent),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.adminAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'SH: ${widget.suratHisabNo}',
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
                    'SISA SALDO POKOK',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRupiah(_currentRemainingBalance),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.adminAccent,
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
                    _formatRupiah(widget.totalLoanAmount),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.adminAccent),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Grid Details Info (Tenor, Jasa, Agunan, Jatuh Tempo)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAdminDetailItem('Nama Anggota', '${widget.memberName} (Reg ${widget.memberNo})'),
                    _buildAdminDetailItem('Tenor / Jangka', '${widget.tenorMonths} Bulan'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAdminDetailItem('Jasa / Bunga', '${widget.interestRatePercent}% / bln'),
                    _buildAdminDetailItem('Jatuh Tempo', widget.dueDate),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAdminDetailItem('Jaminan / Agunan', widget.collateral),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDetailItem(String label, String val) {
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

  // --- WIDGET TABEL HISTORI ANGSURAN ---
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
            headingRowColor: WidgetStateProperty.all(AppColors.adminNavy.withValues(alpha: 0.05)),
            columnSpacing: 22,
            horizontalMargin: 16,
            headingRowHeight: 46,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('No. Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('Angsuran Pokok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('Saldo Sisa Pokok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('Jasa / Bunga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
              DataColumn(label: Text('Denda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.adminNavy))),
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
                  DataCell(Text(rec.date, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      rec.proofCode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatRupiah(rec.principalPaid),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
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
                      _formatRupiah(rec.interestPaid),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  DataCell(
                    Text(
                      rec.penaltyPaid > 0 ? _formatRupiah(rec.penaltyPaid) : 'Rp 0',
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
