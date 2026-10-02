import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';
import '../../data/dummy/ketua_dummy_data.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_utils.dart';
import 'announcement_screen.dart';
import 'executive_report_screen.dart';
import 'member_list_screen.dart';
import 'period_management_screen.dart';
import 'system_settings_screen.dart';
import 'shu_parameter_screen.dart';
import 'shu_distribution_screen.dart';
import 'transaction_approval_screen.dart';
import 'widgets/ketua_approval_table.dart';
import 'widgets/ketua_header.dart';
import 'widgets/ketua_stat_cards.dart';
import 'widgets/adjust_balance_dialog.dart';

///  DASHBOARD MANAJER KOPERASI CUM PELITA (MODULAR WITH NAV & ACTION SYSTEM)
class DashboardKetuaScreen extends StatefulWidget {
  const DashboardKetuaScreen({super.key});

  @override
  State<DashboardKetuaScreen> createState() => _DashboardKetuaScreenState();
}

class _DashboardKetuaScreenState extends State<DashboardKetuaScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ExecutiveReportScreenState> _executiveReportKey = GlobalKey<ExecutiveReportScreenState>();
  bool _isSidebarOpen = true;
  bool _isRefreshing = false;
  int _selectedNavIndex = 0; // 0: Beranda, 1: Laporan, 2: ACC, 3: Anggota, 4: Pengumuman, 5: Pengaturan, 6: Periode
  String _approvalFilter = 'semua'; // 'semua', 'pinjaman', 'kas_keluar'

  // Model Data Pengajuan Persetujuan (ACC) - Menggunakan Repository KetuaDummyData
  late List<ApprovalDataModel> _approvalRequests;

  List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double _totalKasBank = 0.0;
  double _kasLaci = 0.0;
  double _kasBank = 0.0;
  double _totalSahamTetap = 0.0;
  double _simpananSukarela = 0.0;
  double _tabunganHarian = 0.0;
  double _danaDukaSosial = 0.0;
  double _totalKasMasuk = 0.0;
  double _totalKasKeluar = 0.0;
  List<dynamic> _monthlyChartData = [];
  final Set<String> _loadingApprovals = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboardSummary();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return;

      final uri = Uri.parse('${AuthService.staticBaseUrl}/notifications');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _notifications = List<Map<String, dynamic>>.from(data['data'].map((item) => {
                'id': (item['id'] ?? '').toString(),
                'title': (item['title'] ?? item['message'] ?? 'Notifikasi Baru').toString(),
                'time': (item['created_at_human'] ?? item['created_at'] ?? 'Baru saja').toString(),
                'isRead': item['is_read'] == 1 || item['is_read'] == true,
              }));
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch notifikasi: $e");
    }
  }

  Future<void> _markAsRead([String? id]) async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return;

      final uri = Uri.parse('${AuthService.staticBaseUrl}/notifications/mark-as-read');
      final body = id != null ? jsonEncode({'id': id}) : jsonEncode({});

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        // Refresh lokal
        if (mounted) {
          setState(() {
            if (id != null) {
              for (var n in _notifications) {
                if (n['id'] == id) n['isRead'] = true;
              }
            } else {
              for (var n in _notifications) {
                n['isRead'] = true;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mark as read: $e");
    }
  }

  Future<void> _fetchDashboardSummary() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
            _isLoading = false;
          });
        }
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/manager/dashboard-summary');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          final List<dynamic> pendingRaw = data['pending_approvals'] ?? [];
          setState(() {
            _totalKasBank = double.tryParse((data['total_kas_bank'] ?? 0.0).toString()) ?? 0.0;
            _kasLaci = double.tryParse((data['kas_laci'] ?? 0.0).toString()) ?? 0.0;
            _kasBank = double.tryParse((data['kas_bank'] ?? 0.0).toString()) ?? 0.0;
            _totalSahamTetap = double.tryParse((data['total_saham_tetap'] ?? data['saham_tetap'] ?? ((data['total_principal'] ?? 0) + (data['total_mandatory'] ?? 0)) ?? 0.0).toString()) ?? 0.0;
            _simpananSukarela = double.tryParse((data['total_simpanan_sukarela'] ?? data['simpanan_sukarela'] ?? data['total_voluntary'] ?? 0.0).toString()) ?? 0.0;
            _tabunganHarian = double.tryParse((data['total_tabungan_harian'] ?? data['tabungan_harian'] ?? data['total_daily_savings'] ?? data['total_daily'] ?? data['simpanan_bisa_ditarik'] ?? 0.0).toString()) ?? 0.0;
            _danaDukaSosial = double.tryParse((data['dana_duka_sosial'] ?? 0.0).toString()) ?? 0.0;
            _totalKasMasuk = double.tryParse((data['total_kas_masuk'] ?? 0.0).toString()) ?? 0.0;
            _totalKasKeluar = double.tryParse((data['total_kas_keluar'] ?? 0.0).toString()) ?? 0.0;
            _monthlyChartData = data['cashflow_chart'] ?? [];
            _approvalRequests = ApprovalDataModel.fromJsonList(pendingRaw);
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = responseData['message'] ?? 'Gagal memuat data ringkasan.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Gagal memuat data (Status ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _updateStatus(String id, String status) async {
    setState(() {
      _loadingApprovals.add(id);
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
        setState(() {
          _loadingApprovals.remove(id);
        });
        return;
      }

      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/transactions/$id/status');

      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status == 'approved' ? 'approved' : 'rejected',
          'description': status == 'approved' ? 'Disetujui oleh Ketua Koperasi' : 'Ditolak oleh Ketua Koperasi',
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'approved'
                  ? 'Pengajuan berhasil disetujui'
                  : 'Pengajuan telah ditolak'),
              backgroundColor: status == 'approved' ? AppColors.success : AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _fetchDashboardSummary();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Gagal memperbarui status.'))
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error server (Status ${response.statusCode})'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingApprovals.remove(id);
        });
      }
    }
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  static String _formatRupiahCompact(num val) {
    if (val == 0) return "0";
    if (val >= 1000000000) return "${(val / 1000000000).toStringAsFixed(1).replaceAll('.0', '')} M";
    if (val >= 1000000) return "${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')} Jt";
    if (val >= 1000) return "${(val / 1000).toStringAsFixed(1).replaceAll('.0', '')} Rb";
    return val.toStringAsFixed(0);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  /// 🔄 1. FUNGSI REFRESH DATA KETUA
  Future<void> _handleRefreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _fetchDashboardSummary();

    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Data berhasil diperbarui.'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAdjustBalanceDialog(bool isExpense) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdjustBalanceFormDialog(
        isExpense: isExpense,
      ),
    );

    if (result == true) {
      _fetchDashboardSummary();
      _executiveReportKey.currentState?.fetchReportData();
    }
  }

  ///  2. FUNGSI NOTIFIKASI KETUA (DIALOG / POPOVER NOTIFIKASI)
  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int unreadCount = _notifications.where((n) => n['isRead'] == false).length;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text('Notifikasi Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount Baru',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Tidak ada notifikasi.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      for (int i = 0; i < _notifications.length; i++) ...[
                        InkWell(
                          onTap: () {
                            _markAsRead(_notifications[i]['id']);
                            setDialogState(() {
                              _notifications[i]['isRead'] = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _notifications[i]['isRead'] == false
                                  ? AppColors.primaryBackground.withValues(alpha: 0.5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _notifications[i]['isRead'] == false
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _notifications[i]['isRead'] == false
                                      ? Icons.mark_email_unread_rounded
                                      : Icons.mark_email_read_rounded,
                                  color: _notifications[i]['isRead'] == false
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _notifications[i]['title'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _notifications[i]['isRead'] == false
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: AppColors.adminNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _notifications[i]['time'],
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i < _notifications.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      _markAsRead();
                      setDialogState(() {
                        for (var n in _notifications) {
                          n['isRead'] = true;
                        }
                      });
                    },
                    child: const Text('Tandai Semua Dibaca', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                ElevatedButton(
                  onPressed: () => NavigationUtils.safePop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  /// Dialog Konfirmasi ACC (Setujui / Tolak)
  void _showApprovalDialog(BuildContext context, ApprovalDataModel item, bool isApprove) {
    final String actionText = isApprove ? 'MENSETUJUI' : 'MENOLAK';
    final Color actionColor = isApprove ? AppColors.success : AppColors.danger;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: actionColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                'Konfirmasi $actionText',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda yakin ingin $actionText pengajuan ${item.id}?',
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pemohon: ${item.applicant} (No. ${item.memberNo})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Kategori: ${item.category}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Nominal: ${_formatRupiah(item.amount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: actionColor)),
                  ],
                ),
              ),
              if (!isApprove) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Penolakan (Wajib)',
                    hintText: 'Masukkan alasan...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                NavigationUtils.safePop(dialogContext);
                _updateStatus(item.id, isApprove ? 'approved' : 'rejected');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isApprove ? 'Setujui Pengajuan' : 'Tolak Pengajuan'),
            ),
          ],
        );
      },
    );
  }


  /// Dialog Konfirmasi Logout
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.danger, size: 24),
              SizedBox(width: 10),
              Text('Konfirmasi Keluar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari Sesi Ketua Koperasi CUM Pelita?',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationUtils.safePop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                NavigationUtils.safePop(dialogContext);
                AuthService.handleLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final int unreadNotificationsCount = _notifications.where((n) => n['isRead'] == false).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.adminCanvas,
          drawer: _buildKetuaDrawer(context),
          appBar: KetuaHeaderWidget(
            isDesktop: isDesktop,
            isSidebarOpen: _isSidebarOpen,
            isRefreshing: _isRefreshing,
            unreadNotificationsCount: unreadNotificationsCount,
            onToggleSidebar: () {
              if (isDesktop) {
                _toggleSidebar();
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            onRefresh: _handleRefreshData,
            onOpenNotifications: _showNotificationDialog,
          ),
          body: Row(
            children: [
              // Sidebar khusus Desktop (Collapsible 270px -> 0px)
              if (isDesktop)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _isSidebarOpen ? 270.0 : 0.0,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 270.0,
                      maxWidth: 270.0,
                      alignment: Alignment.topLeft,
                      child: _buildKetuaDrawer(context),
                    ),
                  ),
                ),

              // Main Body Content Area (Terhubung ke _selectedNavIndex)
              Expanded(
                child: _buildSelectedNavContent(isDesktop),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedNavContent(bool isDesktop) {
    if (_selectedNavIndex == 1) {
      return ExecutiveReportScreen(key: _executiveReportKey);
    }
    if (_selectedNavIndex == 2) {
      return const TransactionApprovalScreen();
    }
    if (_selectedNavIndex == 3) {
      return const MemberListScreen();
    }
    if (_selectedNavIndex == 4) {
      return const AnnouncementScreen();
    }
    if (_selectedNavIndex == 5) {
      return const SystemSettingsScreen();
    }
    if (_selectedNavIndex == 6) {
      return const PeriodManagementScreen();
    }
    if (_selectedNavIndex == 9) {
      return const ShuParameterScreen();
    }
    if (_selectedNavIndex == 10) {
      return const ShuDistributionScreen();
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(80.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Gagal memuat ringkasan dashboard', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDashboardSummary,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

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
              // 0. QUICK ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAdjustBalanceDialog(false),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('+ Tambah Saldo / Pemasukan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAdjustBalanceDialog(true),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      label: const Text('- Catat Beban / Pengeluaran'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. MODULAR STAT CARDS WIDGET
              KetuaStatCardsWidget(
                isDesktop: isDesktop,
                cards: [
                  StatCardModel(
                    title: 'Total Kas & Bank',
                    value: _formatRupiah(_totalKasBank),
                    subtitle: 'Laci: ${_formatRupiah(_kasLaci)} | BRI: ${_formatRupiah(_kasBank)}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF16A34A),
                    bgGradient: const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
                  ),
                  StatCardModel(
                    title: 'Modal Permanen (SP & SW)',
                    value: _formatRupiah(_totalSahamTetap),
                    subtitle: 'Simpanan Pokok & Wajib Terkunci',
                    icon: Icons.pie_chart_rounded,
                    color: const Color(0xFF0284C7),
                    bgGradient: const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                  ),
                  StatCardModel(
                    title: 'Simpanan Sukarela (SS)',
                    value: _formatRupiah(_simpananSukarela),
                    subtitle: 'Saham Buku Biru (Bisa Ditarik)',
                    icon: Icons.monetization_on_rounded,
                    color: const Color(0xFF0891B2),
                    bgGradient: const [Color(0xFFCFFAFE), Color(0xFFA5F3FC)],
                  ),
                  StatCardModel(
                    title: 'Tabungan Harian',
                    value: _formatRupiah(_tabunganHarian),
                    subtitle: 'Buku Putih (Kewajiban Kasir)',
                    icon: Icons.savings_rounded,
                    color: const Color(0xFFD97706),
                    bgGradient: const [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  StatCardModel(
                    title: 'Cadangan Dana Duka & Sosial',
                    value: _formatRupiah(_danaDukaSosial),
                    subtitle: 'Penyaluran Klaim Duka',
                    icon: Icons.health_and_safety_rounded,
                    color: const Color(0xFF9333EA),
                    bgGradient: const [Color(0xFFF3E8FF), Color(0xFFE9D5FF)],
                  ),
                  StatCardModel(
                    title: 'Total Kas Masuk',
                    value: _formatRupiah(_totalKasMasuk),
                    subtitle: 'Arus Kas Masuk (KM)',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF0D9488),
                    bgGradient: const [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
                  ),
                  StatCardModel(
                    title: 'Total Kas Keluar',
                    value: _formatRupiah(_totalKasKeluar),
                    subtitle: 'Arus Kas Keluar (KK)',
                    icon: Icons.trending_down_rounded,
                    color: const Color(0xFFE11D48),
                    bgGradient: const [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. GRAFIK PERFORMA ARUS KAS
              _buildCashFlowChartCard(isDesktop),

              const SizedBox(height: 20),

              // 3. MODULAR APPROVAL TABLE WIDGET
              KetuaApprovalTableWidget(
                isDesktop: isDesktop,
                requests: _approvalRequests,
                approvalFilter: _approvalFilter,
                loadingIds: _loadingApprovals,
                onFilterChanged: (filter) => setState(() => _approvalFilter = filter),
                onApprove: (item) => _showApprovalDialog(context, item, true),
                onReject: (item) => _showApprovalDialog(context, item, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. VISUAL CHART / GRAFIK PERFORMA ARUS KAS
  Widget _buildCashFlowChartCard(bool isDesktop) {
    final List<String> months = _monthlyChartData.map((e) => (e['label'] ?? e['month'] ?? '').toString()).toList();

    final List<FlSpot> spotsKM = [];
    final List<FlSpot> spotsKK = [];

    for (int i = 0; i < _monthlyChartData.length; i++) {
      final item = _monthlyChartData[i];
      final double kmVal = (double.tryParse((item['kas_masuk'] ?? 0.0).toString()) ?? 0.0);
      final double kkVal = (double.tryParse((item['kas_keluar'] ?? 0.0).toString()) ?? 0.0);
      spotsKM.add(FlSpot(i.toDouble(), kmVal));
      spotsKK.add(FlSpot(i.toDouble(), kkVal));
    }

    double maxVal = 0.0;
    for (var spot in spotsKM) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    for (var spot in spotsKK) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    if (maxVal == 0) maxVal = 10000000.0;

    double interval;
    if (maxVal <= 20000000) {
      interval = 5000000;
    } else if (maxVal <= 50000000) {
      interval = 10000000;
    } else if (maxVal <= 100000000) {
      interval = 20000000;
    } else if (maxVal <= 250000000) {
      interval = 50000000;
    } else {
      interval = (maxVal * 1.25 / 4).roundToDouble();
      if (interval == 0) interval = 10000000;
    }

    final double maxYVal = ((maxVal * 1.25) / interval).ceil() * interval;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grafik Performa Arus Kas (6 Bulan)',
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adminNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tren Kas Masuk (KM) vs Kas Keluar (KK)',
                    style: TextStyle(fontSize: isDesktop ? 11.5 : 10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chartLegendBadge('Kas Masuk (KM)', const Color(0xFF0D9488)),
                  const SizedBox(width: 12),
                  _chartLegendBadge('Kas Keluar (KK)', const Color(0xFFE11D48)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // LineChart Component FL_Chart dengan SizedBox Height Eksplisit
          SizedBox(
            height: isDesktop ? 280.0 : 200.0,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.cardBorder,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: interval,
                      getTitlesWidget: (val, meta) {
                        final double remainder = (val % interval).abs();
                        final double epsilon = interval * 0.001;
                        if (remainder > epsilon && (interval - remainder).abs() > epsilon) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            _formatRupiahCompact(val),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= months.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            months[value.toInt()],
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (months.length - 1).toDouble(),
                minY: 0,
                maxY: maxYVal,
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsKM,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF0D9488),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: spotsKK,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFFE11D48),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegendBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// 🚪 Sidebar Drawer khusus Ketua
  Widget _buildKetuaDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.adminNavy,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 48, bottom: 20, left: 20, right: 20),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.adminAccent, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_koperasi.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield_rounded, color: AppColors.adminNavy, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'CUM PELITA',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                      Text(
                        'Dashboard Manajer',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _drawerMenuItem(Icons.dashboard_rounded, 'Beranda', _selectedNavIndex == 0, () {
                  setState(() => _selectedNavIndex = 0);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.assessment_rounded, 'Ringkasan Laporan', _selectedNavIndex == 1, () {
                  setState(() => _selectedNavIndex = 1);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.rule_rounded, 'Persetujuan ACC (4)', _selectedNavIndex == 2, () {
                  setState(() => _selectedNavIndex = 2);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.people_alt_rounded, 'Data Anggota', _selectedNavIndex == 3, () {
                  setState(() => _selectedNavIndex = 3);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.campaign_outlined, 'Pengumuman & Berita', _selectedNavIndex == 4, () {
                  setState(() => _selectedNavIndex = 4);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                // _drawerMenuItem(Icons.settings_rounded, 'Pengaturan Sistem', _selectedNavIndex == 5, () {
                //   setState(() => _selectedNavIndex = 5);
                //   if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                // }),
                _drawerMenuItem(Icons.lock_clock_rounded, 'Manajemen Periode', _selectedNavIndex == 6, () {
                  setState(() => _selectedNavIndex = 6);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.bar_chart_rounded, 'Parameter SHU Koperasi', _selectedNavIndex == 9, () {
                  setState(() => _selectedNavIndex = 9);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
                _drawerMenuItem(Icons.pie_chart_rounded, 'Distribusi SHU & Deviden', _selectedNavIndex == 10, () {
                  setState(() => _selectedNavIndex = 10);
                  if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                }),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              onTap: () => _showLogoutDialog(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: AppColors.danger.withValues(alpha: 0.15),
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerMenuItem(IconData icon, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(icon, color: isActive ? AppColors.adminAccent : Colors.white70, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
