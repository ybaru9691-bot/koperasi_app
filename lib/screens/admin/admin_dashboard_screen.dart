import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_stat_model.dart';
import '../../models/transaction_data_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_financial_chart_widget.dart';
import '../../widgets/admin_dashboard_chart_widget.dart';
import 'input_transaksi_screen.dart';
import 'migration_screen.dart';
import 'widgets/admin_header.dart';
import 'widgets/admin_stat_cards.dart';
import 'widgets/admin_table.dart';
import '../../widgets/receipt_voucher_dialog.dart';

/// Screen utama Admin Koperasi (Role: 'admin') - Modular & Integrated with AppColors & AppTextStyles
class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AdminDashboardScreen({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _adminName = "Admin Koperasi";

  List<AdminStatModel> _statCards = [];
  List<TransactionDataModel> _recentTransactions = [];
  List<MonthlyFinancialData> _chartData = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminDashboardData();
  }

  String _formatRupiah(double value) {
    final String valStr = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = valStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(valStr[i]);
      count++;
    }
    return "Rp ${buffer.toString().split('').reversed.join('')}";
  }

  bool _isFetchingSummary = false;

  Future<void> _fetchAdminDashboardData() async {
    if (_isFetchingSummary) return;
    _isFetchingSummary = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService().getToken();

      if (token != null && token.isNotEmpty) {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        // Ambil nama admin dari penyimpanan sesi lokal (tanpa memicu request network /api/me)
        final savedUser = await AuthService().getSavedUser();
        if (mounted && savedUser != null && savedUser['name'] != null) {
          _adminName = savedUser['name'].toString();
        }

        // HANYA panggil /dashboard-summary dengan timeout 30 detik
        final summaryResponse = await http
            .get(
              Uri.parse('${AuthService.staticBaseUrl}/dashboard-summary'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 60));

        if (summaryResponse.statusCode == 200) {
          final resData = jsonDecode(summaryResponse.body);
          if (resData['success'] == true && resData['data'] != null) {
            final data = resData['data'];

            final double totalKasBank = (data['total_kas_bank'] as num?)?.toDouble() ?? 0.0;
            final double kasLaci = (data['kas_laci'] as num?)?.toDouble() ?? 0.0;
            final double kasBank = (data['kas_bank'] as num?)?.toDouble() ?? 0.0;
            final double totalSahamTetap = (data['total_saham_tetap'] ?? data['saham_tetap'] ?? ((data['total_principal'] ?? 0) + (data['total_mandatory'] ?? 0)) as num?)?.toDouble() ?? 0.0;
            final double simpananSukarela = (data['total_simpanan_sukarela'] ?? data['simpanan_sukarela'] ?? data['total_voluntary'] as num?)?.toDouble() ?? 0.0;
            final double tabunganHarian = (data['total_tabungan_harian'] ?? data['tabungan_harian'] ?? data['total_daily_savings'] ?? data['total_daily'] ?? data['simpanan_bisa_ditarik'] as num?)?.toDouble() ?? 0.0;
            final double danaDukaSosial = (data['dana_duka_sosial'] as num?)?.toDouble() ?? 0.0;
            final double totalKasMasuk = (data['total_kas_masuk'] as num?)?.toDouble() ?? 0.0;
            final double totalKasKeluar = (data['total_kas_keluar'] as num?)?.toDouble() ?? 0.0;

            final List<AdminStatModel> fetchedCards = [
              AdminStatModel(
                title: "Total Kas & Bank",
                value: _formatRupiah(totalKasBank),
                subtitle: "Laci: ${_formatRupiah(kasLaci)} | BRI: ${_formatRupiah(kasBank)}",
                icon: Icons.account_balance_wallet_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                totalKasBank: totalKasBank,
              ),
              AdminStatModel(
                title: "Modal Permanen (SP & SW)",
                value: _formatRupiah(totalSahamTetap),
                subtitle: "Simpanan Pokok & Wajib Terkunci",
                icon: Icons.pie_chart_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                totalSahamTetap: totalSahamTetap,
              ),
              AdminStatModel(
                title: "Simpanan Sukarela (SS)",
                value: _formatRupiah(simpananSukarela),
                subtitle: "Saham Buku Biru (Bisa Ditarik)",
                icon: Icons.monetization_on_rounded,
                iconBg: const Color(0xFFCFFAFE),
                iconColor: const Color(0xFF0891B2),
                totalSimpananSukarela: simpananSukarela,
              ),
              AdminStatModel(
                title: "Tabungan Harian",
                value: _formatRupiah(tabunganHarian),
                subtitle: "Buku Putih (Kewajiban Kasir)",
                icon: Icons.savings_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                totalTabunganHarian: tabunganHarian,
              ),
              AdminStatModel(
                title: "Cadangan Dana Duka & Sosial",
                value: _formatRupiah(danaDukaSosial),
                subtitle: "Penyaluran Klaim Duka",
                icon: Icons.health_and_safety_rounded,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
              ),
              AdminStatModel(
                title: "Total Kas Masuk",
                value: _formatRupiah(totalKasMasuk),
                subtitle: "Arus Kas Masuk (KM)",
                icon: Icons.trending_up_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
              ),
              AdminStatModel(
                title: "Total Kas Keluar",
                value: _formatRupiah(totalKasKeluar),
                subtitle: "Arus Kas Keluar (KK)",
                icon: Icons.trending_down_rounded,
                iconBg: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFE11D48),
              ),
            ];

            // 1. Ekstraksi aman latest_transactions (tangani _JsonMap pagination { data: [...] } maupun List)
            List<dynamic> trxsRaw = [];
            final dynamic rawTrxs = data['latest_transactions'];
            if (rawTrxs is List) {
              trxsRaw = rawTrxs;
            } else if (rawTrxs is Map) {
              if (rawTrxs['data'] is List) {
                trxsRaw = rawTrxs['data'] as List;
              } else if (rawTrxs['transactions'] is List) {
                trxsRaw = rawTrxs['transactions'] as List;
              }
            }

            final Map<String, TransactionDataModel> groupedTrxs = {};
            for (var trx in trxsRaw) {
              if (trx is! Map) continue;
              final bool isIncome = trx['isIncome'] ?? trx['is_income'] ?? true;
              final String rawKm = (trx['formatted_receipt_no'] ?? trx['transaction_number'] ?? trx['receipt_number'] ?? trx['kmCode'] ?? '').toString();
              final String kmCode = ReceiptVoucherDialog.deduplicateProofNumber(rawKm, isIncome: isIncome);
              final String rawDate = (trx['date'] ?? trx['created_at'] ?? trx['transaction_date'] ?? '').toString();
              final String dateFormatted = ReceiptVoucherDialog.formatToWibDateTime(rawDate);
              final String category = (trx['description'] ?? 'Transaksi').toString();
              final double amount = (trx['amount'] as num?)?.toDouble() ?? 0.0;
              
              final String paymentRaw = (trx['payment_method'] ?? 'cash').toString().toLowerCase();
              final String paymentMethod = (paymentRaw.contains('bank') || paymentRaw.contains('transfer'))
                  ? '🏦 Transfer / Bank'
                  : '💵 Tunai / Cash';

              if (groupedTrxs.containsKey(kmCode)) {
                var existing = groupedTrxs[kmCode]!;
                List<Map<String, dynamic>> newSubItems = List.from(existing.subItems);
                newSubItems.add({
                  'category': category,
                  'amount': amount,
                });
                groupedTrxs[kmCode] = TransactionDataModel(
                  id: existing.id,
                  date: existing.date,
                  kmCode: existing.kmCode,
                  memberName: existing.memberName,
                  memberNo: existing.memberNo,
                  category: '${newSubItems[0]['category']} +${newSubItems.length - 1} Pos',
                  isIncome: existing.isIncome,
                  amount: existing.amount + amount,
                  paymentMethod: existing.paymentMethod,
                  operator: existing.operator,
                  subItems: newSubItems,
                );
              } else {
                groupedTrxs[kmCode] = TransactionDataModel(
                  id: (trx['id'] ?? '').toString(),
                  date: dateFormatted,
                  kmCode: kmCode,
                  memberName: (trx['member']?['full_name'] ?? trx['member']?['name'] ?? 'Anggota Umum').toString(),
                  memberNo: (trx['member']?['member_number'] ?? 'No. Anggota').toString(),
                  category: category,
                  isIncome: isIncome,
                  amount: amount,
                  paymentMethod: paymentMethod,
                  operator: (trx['operator'] ?? 'Teller Admin').toString(),
                  subItems: [
                    {
                      'category': category,
                      'amount': amount,
                    }
                  ],
                );
              }
            }
            final List<TransactionDataModel> parsedTrxs = groupedTrxs.values.toList();

            // 2. Ekstraksi aman cashflow_chart (tangani _JsonMap pagination maupun List)
            List<dynamic> chartRaw = [];
            final dynamic rawChart = data['cashflow_chart'];
            if (rawChart is List) {
              chartRaw = rawChart;
            } else if (rawChart is Map && rawChart['data'] is List) {
              chartRaw = rawChart['data'] as List;
            }
            final List<MonthlyFinancialData> parsedChart = [];
            for (var item in chartRaw) {
              if (item is! Map) continue;
              String label = (item['label'] ?? '').toString();
              String shortMonth = label.split(' ')[0];
              if (shortMonth.length > 3) {
                shortMonth = shortMonth.substring(0, 3);
              }
              parsedChart.add(MonthlyFinancialData(
                month: shortMonth,
                kasMasuk: (item['kas_masuk'] as num?)?.toDouble() ?? 0.0,
                kasKeluar: (item['kas_keluar'] as num?)?.toDouble() ?? 0.0,
              ));
            }

            if (mounted) {
              setState(() {
                _statCards = fetchedCards;
                _recentTransactions = parsedTrxs;
                _chartData = parsedChart;
                _isLoading = false;
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard summary: $e");
    } finally {
      _isFetchingSummary = false;
    }

    // Fallback jika request gagal
    setState(() {
      _statCards = [];
      _recentTransactions = [];
      _chartData = [];
      _isLoading = false;
      _errorMessage = "Gagal memuat data dari server.";
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.dangerAccent),
              SizedBox(width: 10),
              Text(
                'Logout Admin?',
                style: AppTextStyles.heading2,
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar (logout) dari akun Admin Koperasi?',
            style: AppTextStyles.bodyText,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await AuthService.handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: AppColors.adminCanvas,
          appBar: AdminHeaderWidget(
            adminName: _adminName,
            onOpenDrawer: widget.onOpenDrawer,
            onRefresh: _fetchAdminDashboardData,
            onLogout: _handleLogout,
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.adminNavy),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: AppTextStyles.bodyText,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchAdminDashboardData,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24.0 : 14.0,
                        vertical: 16.0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. MODULAR STAT CARDS SECTION (RESPONSIF)
                              AdminStatCardsWidget(
                                isDesktop: isDesktop,
                                statCards: _statCards,
                              ),

                              const SizedBox(height: 20),

                              // 2. GRAFIK TREN KEUANGAN BULANAN (KM VS KK)
                              MonthlyTrendChartWidget(
                                monthlyData: _chartData.map((d) => {
                                  'month': d.month,
                                  'total_km': d.kasMasuk,
                                  'total_kk': d.kasKeluar,
                                }).toList(),
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: 24),

                              // 3. MODULAR TRANSACTION TABLE WIDGET (BEBAS OVERFLOW)
                              AdminTableWidget(
                                isDesktop: isDesktop,
                                transactions: _recentTransactions,
                                onImportExcel: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MigrationScreen(),
                                    ),
                                  );
                                },
                                onInputTransaction: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const InputTransaksiScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
