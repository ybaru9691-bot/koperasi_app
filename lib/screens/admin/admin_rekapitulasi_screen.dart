import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Model Riwayat Transaksi Operasional Pinjaman (Pencairan & Angsuran)
class LoanTransactionRecord {
  final dynamic id;
  final String receiptNumber;
  final String transactionType; // 'DISBURSEMENT' or 'REPAYMENT'
  final String memberName;
  final String memberNumber;
  final String loanNumber;
  final int? installmentOrder;
  final num principalAmount;
  final num interestAmount;
  final num penaltyAmount;
  final num totalAmount;
  final String date;
  final String description;
  final String status;

  LoanTransactionRecord({
    this.id,
    required this.receiptNumber,
    required this.transactionType,
    required this.memberName,
    required this.memberNumber,
    required this.loanNumber,
    this.installmentOrder,
    required this.principalAmount,
    required this.interestAmount,
    required this.penaltyAmount,
    required this.totalAmount,
    required this.date,
    required this.description,
    this.status = 'approved',
  });

  bool get isDisbursement =>
      transactionType.toUpperCase() == 'DISBURSEMENT' ||
      transactionType.toUpperCase() == 'PENCAIRAN' ||
      transactionType.toUpperCase() == 'KK' ||
      transactionType.toUpperCase() == 'OUT';

  factory LoanTransactionRecord.fromJson(Map<String, dynamic> json) {
    final rawType = (json['transaction_type'] ?? json['tipe_transaksi'] ?? json['type'] ?? 'REPAYMENT').toString().toUpperCase();
    final isDisb = rawType == 'DISBURSEMENT' ||
        rawType == 'PENCAIRAN' ||
        rawType == 'KK' ||
        rawType == 'OUT' ||
        rawType == 'WITHDRAWAL' ||
        (json['description']?.toString().toLowerCase().contains('pencairan') ?? false);

    final mName = json['member_name'] ?? json['nama_anggota'] ?? json['name'] ?? 'Anggota';
    final mNo = json['member_number'] ?? json['no_anggota'] ?? json['member_no'] ?? '-';
    final shNo = json['loan_number'] ?? json['no_sh'] ?? json['loan_code'] ?? '-';
    final order = json['installment_order'] ?? json['angsuran_ke'];

    return LoanTransactionRecord(
      id: json['id'],
      receiptNumber: (json['receipt_number'] ?? json['no_bukti'] ?? json['voucher_number'] ?? (isDisb ? 'KK' : 'KM')).toString(),
      transactionType: isDisb ? 'DISBURSEMENT' : 'REPAYMENT',
      memberName: mName.toString(),
      memberNumber: mNo.toString(),
      loanNumber: shNo.toString(),
      installmentOrder: order != null ? int.tryParse(order.toString()) : null,
      principalAmount: num.tryParse((json['principal_amount'] ?? json['pokok'] ?? 0).toString()) ?? 0,
      interestAmount: num.tryParse((json['interest_amount'] ?? json['jasa'] ?? 0).toString()) ?? 0,
      penaltyAmount: num.tryParse((json['penalty_amount'] ?? json['denda'] ?? 0).toString()) ?? 0,
      totalAmount: num.tryParse((json['total_amount'] ?? json['total_bayar'] ?? json['amount'] ?? 0).toString()) ?? 0,
      date: (json['date'] ?? json['tanggal'] ?? json['transaction_date'] ?? json['created_at'] ?? '-').toString(),
      description: (json['description'] ?? json['keterangan'] ?? (isDisb ? 'Pencairan Pinjaman' : 'Angsuran Pinjaman')).toString(),
      status: (json['status'] ?? 'approved').toString(),
    );
  }
}

/// Model Ringkasan Data Operasional Pinjaman
class LoanHistorySummary {
  final num totalPlafonDicairkan;
  final num totalPokokTerbayar;
  final num sisaPiutangPinjaman;

  LoanHistorySummary({
    required this.totalPlafonDicairkan,
    required this.totalPokokTerbayar,
    required this.sisaPiutangPinjaman,
  });

  factory LoanHistorySummary.fromJson(Map<String, dynamic> json) {
    return LoanHistorySummary(
      totalPlafonDicairkan: num.tryParse((json['total_pinjaman_dicairkan'] ?? json['totalPlafonDicairkan'] ?? json['total_plafon'] ?? 0).toString()) ?? 0,
      totalPokokTerbayar: num.tryParse((json['total_pokok_diterima'] ?? json['totalPokokTerbayar'] ?? json['total_pokok'] ?? 0).toString()) ?? 0,
      sisaPiutangPinjaman: num.tryParse((json['total_sisa_pinjaman'] ?? json['sisaPiutangPinjaman'] ?? json['sisa_pokok'] ?? 0).toString()) ?? 0,
    );
  }
}

class LoanHistoryResponse {
  final LoanHistorySummary summary;
  final List<LoanTransactionRecord> transactions;

  LoanHistoryResponse({
    required this.summary,
    required this.transactions,
  });
}

/// Screen "Riwayat Transaksi Pinjaman" Khusus Admin Koperasi CUM Pelita
class AdminRekapitulasiScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AdminRekapitulasiScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<AdminRekapitulasiScreen> createState() => _AdminRekapitulasiScreenState();
}

class _AdminRekapitulasiScreenState extends State<AdminRekapitulasiScreen> {
  late Future<LoanHistoryResponse> _historyFuture;
  String _filterType = 'ALL'; // 'ALL', 'DISBURSEMENT', 'REPAYMENT'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static final List<String> _monthsIndo = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchLoanTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<LoanHistoryResponse> _fetchLoanTransactions() async {
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse('${AuthService.staticBaseUrl}/loans/transactions-history?per_page=100');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return _parseResponse(body);
      }

      // Fallback: /admin/loans/transactions-history
      final uri2 = Uri.parse('${AuthService.staticBaseUrl}/admin/loans/transactions-history?per_page=100');
      final response2 = await http.get(uri2, headers: headers).timeout(const Duration(seconds: 25));
      if (response2.statusCode == 200) {
        final body = jsonDecode(response2.body);
        return _parseResponse(body);
      }

      throw 'Gagal memuat data transaksi pinjaman (HTTP ${response.statusCode})';
    } catch (e) {
      debugPrint('[LOAN_HISTORY] Error fetching history: $e');
      rethrow;
    }
  }

  LoanHistoryResponse _parseResponse(dynamic body) {
    final summaryRaw = body['summary'] ?? (body['data'] is Map ? body['data']['summary'] : null) ?? {};
    final summary = LoanHistorySummary.fromJson(summaryRaw is Map<String, dynamic> ? summaryRaw : {});

    dynamic listRaw = body['data'];
    if (listRaw is Map && listRaw.containsKey('data')) {
      listRaw = listRaw['data'];
    }

    List<LoanTransactionRecord> trxs = [];
    if (listRaw is List) {
      trxs = listRaw.whereType<Map<String, dynamic>>().map((j) => LoanTransactionRecord.fromJson(j)).toList();
    }

    // Jika summary kosong dari backend, kalkulasikan secara lokal dari list
    num plafon = summary.totalPlafonDicairkan;
    num pokok = summary.totalPokokTerbayar;
    num sisa = summary.sisaPiutangPinjaman;

    if (plafon == 0 && trxs.isNotEmpty) {
      for (final t in trxs) {
        if (t.isDisbursement) {
          plafon += t.totalAmount;
        } else {
          pokok += t.principalAmount > 0 ? t.principalAmount : t.totalAmount;
        }
      }
      sisa = (plafon - pokok) > 0 ? (plafon - pokok) : 0;
    }

    return LoanHistoryResponse(
      summary: LoanHistorySummary(
        totalPlafonDicairkan: plafon,
        totalPokokTerbayar: pokok,
        sisaPiutangPinjaman: sisa,
      ),
      transactions: trxs,
    );
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  static String _formatDateIndo(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        final monthName = _monthsIndo[parsed.month];
        return '${parsed.day} $monthName ${parsed.year}';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: Builder(
          builder: (btnContext) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              tooltip: 'Menu Admin',
              onPressed: widget.onOpenDrawer ?? () {
                try {
                  Scaffold.of(btnContext).openDrawer();
                } catch (_) {}
              },
            );
          },
        ),
        title: const Text(
          'Riwayat Transaksi Pinjaman',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Segarkan Data',
            onPressed: () {
              setState(() {
                _historyFuture = _fetchLoanTransactions();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<LoanHistoryResponse>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Memuat Riwayat Transaksi Pinjaman...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat transaksi pinjaman:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _historyFuture = _fetchLoanTransactions();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final resp = snapshot.data ??
              LoanHistoryResponse(
                summary: LoanHistorySummary(totalPlafonDicairkan: 0, totalPokokTerbayar: 0, sisaPiutangPinjaman: 0),
                transactions: [],
              );

          return _buildContent(resp);
        },
      ),
    );
  }

  Widget _buildContent(LoanHistoryResponse resp) {
    final filteredTrxs = resp.transactions.where((item) {
      if (_filterType == 'DISBURSEMENT' && !item.isDisbursement) return false;
      if (_filterType == 'REPAYMENT' && item.isDisbursement) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchMember = item.memberName.toLowerCase().contains(q) || item.memberNumber.toLowerCase().contains(q);
        final matchSh = item.loanNumber.toLowerCase().contains(q);
        final matchReceipt = item.receiptNumber.toLowerCase().contains(q);
        return matchMember || matchSh || matchReceipt;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _historyFuture = _fetchLoanTransactions();
        });
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 3 KARTU RINGKASAN PINJAMAN ──
            _buildSummaryCards(resp.summary),

            const SizedBox(height: 20),

            // ── 2. SEARCH & FILTER TIPE TRANSAKSI ──
            _buildFilterBar(),

            const SizedBox(height: 16),

            // ── 3. HEADER DAFTAR TRANSAKSI ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Transaksi Pinjaman & Angsuran',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminNavy,
                  ),
                ),
                Text(
                  '${filteredTrxs.length} Transaksi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 4. LISTVIEW RIWAYAT TRANSAKSI PINJAMAN ──
            if (filteredTrxs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada riwayat transaksi pinjaman',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Transaksi pencairan atau angsuran akan muncul di sini secara otomatis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTrxs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.cardBorder),
                  itemBuilder: (context, index) {
                    final item = filteredTrxs[index];
                    final bool isDisb = item.isDisbursement;

                    // Format Subtitle
                    String subtitleText;
                    if (isDisb) {
                      final shText = item.loanNumber.isNotEmpty && item.loanNumber != '-'
                          ? ' ${item.loanNumber}'
                          : '';
                      subtitleText = 'Pencairan Pinjaman$shText • ${_formatDateIndo(item.date)}';
                    } else {
                      final angKeText = item.installmentOrder != null
                          ? 'Angsuran Ke-${item.installmentOrder}'
                          : 'Angsuran Pinjaman';
                      final pokokStr = _formatRupiah(item.principalAmount);
                      final jasaStr = _formatRupiah(item.interestAmount);
                      subtitleText = '$angKeText • Pokok: $pokokStr | Jasa: $jasaStr • ${_formatDateIndo(item.date)}';
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDisb ? AppColors.dangerBg : AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDisb ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Text(
                          isDisb ? 'KK' : 'KM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDisb ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ),
                      title: Text(
                        '${item.memberName} (No. ${item.memberNumber})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitleText,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                      trailing: Text(
                        '${isDisb ? '-' : '+'} ${_formatRupiah(item.totalAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDisb ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 3 KARTU RINGKASAN PINJAMAN ──
  Widget _buildSummaryCards(LoanHistorySummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cards = [
          _buildStatCard(
            title: 'Total Plafon Dicairkan',
            value: _formatRupiah(summary.totalPlafonDicairkan),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.info,
            bgColor: const Color(0xFFEFF6FF),
          ),
          _buildStatCard(
            title: 'Total Pokok Terbayar',
            value: _formatRupiah(summary.totalPokokTerbayar),
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            bgColor: const Color(0xFFECFDF5),
          ),
          _buildStatCard(
            title: 'Sisa Piutang Pinjaman',
            value: _formatRupiah(summary.sisaPiutangPinjaman),
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH & FILTER TABS ──
  Widget _buildFilterBar() {
    return Column(
      children: [
        // Search TextField
        TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari Nama Anggota / No. SH / No. Bukti...',
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _filterType == 'ALL',
                onSelected: (val) => setState(() => _filterType = 'ALL'),
                selectedColor: AppColors.adminNavy,
                labelStyle: TextStyle(
                  color: _filterType == 'ALL' ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Pencairan (KK)'),
                selected: _filterType == 'DISBURSEMENT',
                onSelected: (val) => setState(() => _filterType = 'DISBURSEMENT'),
                selectedColor: AppColors.danger,
                labelStyle: TextStyle(
                  color: _filterType == 'DISBURSEMENT' ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Angsuran (KM)'),
                selected: _filterType == 'REPAYMENT',
                onSelected: (val) => setState(() => _filterType = 'REPAYMENT'),
                selectedColor: AppColors.success,
                labelStyle: TextStyle(
                  color: _filterType == 'REPAYMENT' ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


