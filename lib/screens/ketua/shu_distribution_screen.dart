import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import 'shu_parameter_screen.dart';
import 'widgets/dividend_distribution_dialog.dart';

/// Layar Manajemen & Eksekusi Distribusi SHU / Deviden Buku Biru Koperasi CUM Pelita
/// Mengelola siklus 12 bulan pembagian deviden (Juni s/d Mei, Cut-Off 21 s/d 20)
class ShuDistributionScreen extends StatefulWidget {
  const ShuDistributionScreen({super.key});

  @override
  State<ShuDistributionScreen> createState() => _ShuDistributionScreenState();
}

class _ShuDistributionScreenState extends State<ShuDistributionScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOpeningDialog = false;
  String? _errorMessage;

  int _selectedFiscalYear = DateTime.now().year;
  String _fiscalPeriodLabel = '';
  num _totalNetProfit = 0;
  num _totalDistributedAmount = 0;
  int _totalDistributedMonths = 0;
  int _totalPendingMonths = 0;
  List<Map<String, dynamic>> _months = [];

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final NumberFormat _decimalFormatter = NumberFormat.decimalPattern('id_ID');

  @override
  void initState() {
    super.initState();
    _selectedFiscalYear = DateTime.now().year;
    _fetchMonthlyStatus();
  }

  String _formatRupiah(num? val) {
    if (val == null) return 'Rp 0';
    return _currencyFormatter.format(val);
  }

  Future<void> _fetchMonthlyStatus({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Sesi login telah berakhir');

      final uri = Uri.parse(
        '${AuthService.staticBaseUrl}/shu/monthly-status?year=$_selectedFiscalYear',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'] ?? {};
          final List<dynamic> rawMonths = data['months'] ?? data['benchmarks'] ?? [];

          setState(() {
            _fiscalPeriodLabel = data['fiscal_period_label'] ?? 'Tahun Buku $_selectedFiscalYear';
            _totalNetProfit = (data['total_net_profit'] ?? 0) as num;
            _totalDistributedAmount = (data['total_distributed_amount'] ?? 0) as num;
            _totalDistributedMonths = (data['total_distributed_months'] ?? 0) as int;
            _totalPendingMonths = (data['total_pending_months'] ?? 0) as int;
            _months = rawMonths.map((m) => Map<String, dynamic>.from(m)).toList();
            _isLoading = false;
            _isRefreshing = false;
          });
        } else {
          throw Exception(body['message'] ?? 'Gagal memuat status pembagian SHU');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _openDistributionDialogForMonth(Map<String, dynamic> monthItem) async {
    if (_isOpeningDialog) return;
    _isOpeningDialog = true;

    final int m = monthItem['month'] ?? DateTime.now().month;
    final int y = monthItem['calendar_year'] ?? _selectedFiscalYear;
    final String periodName = monthItem['month_label'] ?? '${monthItem['month_name']} $y';
    final double defaultPct = ((monthItem['percentage'] ?? monthItem['dividend_allocation_percent'] ?? 25.0) as num).toDouble();
    final double netProfit = ((monthItem['net_profit'] ?? monthItem['net_income'] ?? 0) as num).toDouble();

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DividendDistributionDialog(
          month: m,
          year: y,
          fiscalYear: _selectedFiscalYear,
          periodName: periodName,
          defaultPercentage: defaultPct > 0 ? defaultPct : 25.0,
          initialNetProfit: netProfit > 0 ? netProfit : null,
          onSuccess: () {
            _fetchMonthlyStatus(isRefresh: true);
          },
        ),
      );
    } finally {
      if (mounted) {
        _isOpeningDialog = false;
      }
    }
  }

  Future<void> _openCurrentPeriodDialog() async {
    if (_isOpeningDialog) return;
    _isOpeningDialog = true;

    final now = DateTime.now();
    final String periodName = DateFormat('MMMM yyyy', 'id_ID').format(now);

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DividendDistributionDialog(
          month: now.month,
          year: now.year,
          fiscalYear: _selectedFiscalYear,
          periodName: periodName,
          defaultPercentage: 25.0,
          onSuccess: () {
            _fetchMonthlyStatus(isRefresh: true);
          },
        ),
      );
    } finally {
      if (mounted) {
        _isOpeningDialog = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24.0 : 16.0,
        vertical: 20.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Toolbar
              _buildHeader(isDesktop),

              const SizedBox(height: 20),

              // 2. Error Banner jika ada
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _fetchMonthlyStatus(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. Loading State
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // 4. Kartu Ringkasan Status SHU
                _buildSummaryCards(isDesktop),

                const SizedBox(height: 24),

                // 5. Tabel Siklus 12 Bulan Distribusi Deviden
                _buildMonthlyStatusTable(isDesktop),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distribusi SHU & Deviden Buku Biru',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monitoring & Eksekusi Pembagian Deviden 12 Bulan Siklus Juni s/d Mei (Cut-off 21 s/d 20)',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                _buildYearDropdown(),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isRefreshing ? null : () => _fetchMonthlyStatus(isRefresh: true),
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  tooltip: 'Refresh Status',
                ),
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildYearDropdown()),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isRefreshing ? null : () => _fetchMonthlyStatus(isRefresh: true),
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _openCurrentPeriodDialog,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Eksekusi SHU Periode Berjalan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Parameter SHU Koperasi'),
                          backgroundColor: AppColors.adminNavy,
                          foregroundColor: Colors.white,
                        ),
                        body: const ShuParameterScreen(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Kelola Parameter SHU'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    final currentYear = DateTime.now().year;
    final List<int> years = [currentYear + 1, currentYear, currentYear - 1, currentYear - 2];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedFiscalYear,
          isDense: true,
          icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
          items: years.map((y) {
            return DropdownMenuItem<int>(
              value: y,
              child: Text(
                'Tahun Buku $y (${y - 1}/$y)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _selectedFiscalYear) {
              setState(() => _selectedFiscalYear = val);
              _fetchMonthlyStatus();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width >= 900 ? 4 : (width >= 550 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: isDesktop ? 2.3 : 2.6,
          children: [
            _cardItem(
              'Total Laba Bersih (SHU)',
              _formatRupiah(_totalNetProfit),
              _fiscalPeriodLabel,
              Icons.account_balance_wallet_rounded,
              const Color(0xFF0D9488),
              const Color(0xFFCCFBF1),
            ),
            _cardItem(
              'Deviden Terdistribusi',
              _formatRupiah(_totalDistributedAmount),
              'Alokasi 25% Buku Biru',
              Icons.pie_chart_rounded,
              const Color(0xFF0284C7),
              const Color(0xFFE0F2FE),
            ),
            _cardItem(
              'Bulan Selesai',
              '$_totalDistributedMonths / 12 Bulan',
              'Status Terdistribusi',
              Icons.check_circle_rounded,
              const Color(0xFF16A34A),
              const Color(0xFFDCFCE7),
            ),
            _cardItem(
              'Bulan Tertunda',
              '$_totalPendingMonths Bulan',
              'Menunggu Eksekusi',
              Icons.pending_actions_rounded,
              const Color(0xFFD97706),
              const Color(0xFFFEF3C7),
            ),
          ],
        );
      },
    );
  }

  Widget _cardItem(String title, String value, String subtitle, IconData icon, Color color, Color bgLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgLight, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatusTable(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Tabel Siklus 12 Bulan (Juni - Mei) — $_fiscalPeriodLabel',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '12 Bulan Buku',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_months.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: Text('Belum ada data periode untuk tahun buku ini.', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 20,
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
                columns: const [
                  DataColumn(label: Text('Bulan Buku')),
                  DataColumn(label: Text('Siklus Cut-Off')),
                  DataColumn(label: Text('Laba Bersih (SHU)')),
                  DataColumn(label: Text('Alokasi (25%)')),
                  DataColumn(label: Text('Total Saham')),
                  DataColumn(label: Text('Lembar Saham')),
                  DataColumn(label: Text('Deviden / Lbr')),
                  DataColumn(label: Text('No. Memorial (BM)')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: _months.map((item) {
                  final String monthName = (item['month_name'] ?? '').toString();
                  final int calendarYear = (item['calendar_year'] ?? _selectedFiscalYear) as int;
                  final String cycle = '${item['cycle_start_date'] ?? '21'} s/d ${item['cycle_end_date'] ?? '20'}';
                  final num netProfit = (item['net_profit'] ?? item['net_income'] ?? 0) as num;
                  final num divPool = (item['shu_25_percent'] ?? item['dividend_pool'] ?? 0) as num;
                  final num totalShares = (item['total_coop_shares'] ?? 0) as num;
                  final num lembar = (item['lembar_saham'] ?? item['total_lembar_koperasi'] ?? 0) as num;
                  final num sharePrice = (item['harga_deviden_per_lembar'] ?? item['share_price'] ?? 0) as num;
                  final String voucherNo = (item['voucher_no'] ?? '-').toString();
                  final bool isDistributed = item['is_distributed'] == true;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDistributed ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$monthName $calendarYear',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(cycle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                      DataCell(Text(_formatRupiah(netProfit), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(
                        Text(
                          _formatRupiah(divPool),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ),
                      DataCell(Text(_formatRupiah(totalShares), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_decimalFormatter.format(lembar), style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Text(
                          'Rp ${sharePrice.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                        ),
                      ),
                      DataCell(
                        Text(
                          voucherNo,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: isDistributed ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDistributed ? AppColors.successBg : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDistributed ? 'Selesai' : 'Belum Diproses',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDistributed ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          onPressed: () => _openDistributionDialogForMonth(item),
                          icon: Icon(isDistributed ? Icons.refresh_rounded : Icons.bolt_rounded, size: 14),
                          label: Text(isDistributed ? 'Hitung Ulang' : 'Bagi Deviden'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDistributed ? const Color(0xFFF1F5F9) : AppColors.primary,
                            foregroundColor: isDistributed ? AppColors.textPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
