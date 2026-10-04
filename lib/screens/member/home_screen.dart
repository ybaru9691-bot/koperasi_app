import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/navigation_utils.dart';
import '../../widgets/network_awareness_wrapper.dart';
import '../../widgets/common_state_widgets.dart';
import '../../services/auth_service.dart';
import '../../utils/whatsapp_helper.dart';
import '../../data/models/announcement_model.dart';
import 'loan_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';

// SECTION 1: DATA MODELS & CONFIGURATION
/// Model Data untuk Simpanan Koperasi
class SavingsModel {
  final String id;
  final String title;
  final String accountNumber;
  final double balance;
  final IconData icon;
  final Color themeColor;

  const SavingsModel({
    required this.id,
    required this.title,
    required this.accountNumber,
    required this.balance,
    required this.icon,
    required this.themeColor,
  });
}

/// Model Data untuk Riwayat Transaksi
class TransactionModel {
  final String id;
  final String title;
  final String date;
  final double amount;
  final bool isExpense;
  final IconData icon;
  final String type;
  final String proofNumber;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isExpense,
    required this.icon,
    required this.type,
    required this.proofNumber,
  });
}



// SECTION 2: MAIN HOME SCREEN (STATEFUL WIDGET)
/// HomeScreen merupakan layar utama setelah login yang menampilkan
/// informasi saldo, daftar simpanan, dan riwayat transaksi.
class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final dynamic member;
  const HomeScreen({super.key, this.initialIndex = 0, this.member});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentBottomNavIndex;
  bool _isBalanceVisible = true;

  // Dynamic State variables
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String _userName = '';
  String _memberNumber = '';
  double _totalBalance = 0.0;
  List<SavingsModel> _savingsList = [];
  List<TransactionModel> _transactionsList = [];
  String _memberStatus = 'active';
  double _estimatedShu = 0.0;
  List<AnnouncementModel> _announcementsList = [];
  LoanModel? _currentLoan;

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = widget.initialIndex;
    _fetchData();
  }

  ///  Mengambil data dashboard secara dinamis dari Laravel API
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

//lanjutkan kode stelah berhasil mengambil data user
    try {
      final authService = AuthService();
      final user = await authService.getSavedUser(); // ambil data user yg tersimpan saat login
      final token = await authService.getToken(); // ambil token yg tersimpan saat login

      if (user == null || token == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Sesi tidak ditemukan. Silakan login kembali.';
          });
        }
        return;
      }

      final memberId = user['member_id'] ?? user['id'];
      final String baseUrl = AuthService.staticBaseUrl;
      final uri = Uri.parse('$baseUrl/members/$memberId/details');
      final annUri = Uri.parse('$baseUrl/announcements');
      final loanUri = Uri.parse('$baseUrl/user/loans');

      debugPrint('[DASHBOARD_LOG] Fetching member details from: $uri');

      // Fetch member details, announcements, and active loans in parallel
      final responses = await Future.wait([
        http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60)),
        http.get(annUri, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60)),
        http.get(loanUri, headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 60)),
      ]);

      final response = responses[0];
      final annResponse = responses[1];
      final loanResponse = responses[2];

      debugPrint('[DEBUG_JSON] Response: ${response.body}');
      debugPrint('[DASHBOARD_LOG] Response status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
       if ((responseData['status'] == 'success' || responseData['success'] == true) && responseData['data'] != null) {
          final data = responseData['data'];
          
          final String name = data['name'] ?? user['name'] ?? '-';
          final String memberNo = widget.member?.noAnggota ??
              widget.member?.noBuku ??
              data['member_number']?.toString() ??
              data['member_no']?.toString() ??
              data['no_anggota']?.toString() ??
              data['no_register']?.toString() ??
              user['no_anggota']?.toString() ??
              user['member_number']?.toString() ??
              user['nik']?.toString() ??
              '-';
          
          final simpanan = data['simpanan'] ?? {};
          final double sp = double.tryParse((simpanan['principal_savings'] ?? simpanan['simpanan_pokok'] ?? 0.0).toString()) ?? 0.0;
          final double sw = double.tryParse((simpanan['mandatory_savings'] ?? simpanan['simpanan_wajib'] ?? 0.0).toString()) ?? 0.0;
          final double ss = double.tryParse((simpanan['voluntary_savings'] ?? simpanan['simpanan_sukarela'] ?? 0.0).toString()) ?? 0.0;
          final double total = double.tryParse((simpanan['total_saldo'] ?? (sp + sw + ss)).toString()) ?? 0.0;

          final List<SavingsModel> parsedSavings = [
            SavingsModel(
              id: 's1',
              title: 'Simpanan Pokok',
              accountNumber: 'SP-$memberNo',
              balance: sp,
              icon: Icons.account_balance_wallet_outlined,
              themeColor: const Color(0xFF137A43),
            ),
            SavingsModel(
              id: 's2',
              title: 'Simpanan Wajib',
              accountNumber: 'SW-$memberNo',
              balance: sw,
              icon: Icons.savings_outlined,
              themeColor: const Color(0xFF1C7C54),
            ),
            SavingsModel(
              id: 's3',
              title: 'Simpanan Sukarela',
              accountNumber: 'SS-$memberNo',
              balance: ss,
              icon: Icons.payments_outlined,
              themeColor: const Color(0xFF2E8B57),
            ),
          ];

        final List<dynamic> txRaw = data['transactions'] ?? [];
       final List<TransactionModel> parsedTransactions = [];
       for (var item in txRaw) {
       final double amount = double.tryParse((item['amount'] ?? 0.0).toString()) ?? 0.0;
      final String type = (item['type'] ?? '').toString().toLowerCase();

    // 1. Utamakan ambil description dari Laravel API
String displayTitle = item['title']?.toString() ?? item['description']?.toString() ?? '';
     if (displayTitle.trim().isEmpty) {
      displayTitle = 'Transaksi Koperasi';
     }

     // 2. Logika deteksi Kas Keluar (Expense) / Kas Masuk (Income)
     bool isExpense = false;
     if (type == 'withdrawal' || type == 'out' || type.contains('keluar') || type.contains('tarik')) {
      isExpense = true;
    } else if (type == 'deposit' || type == 'in' || type.contains('masuk') || type.contains('setor')) {
      isExpense = false;
    } else {
      isExpense = item['is_expense'] ?? false;
     }

      final String rawReceipt = item['receipt_number']?.toString().trim() ?? '';
      final String proofCode = isExpense ? 'KK-$rawReceipt' : 'KM-$rawReceipt';

      final String rawDate = (item['date'] ?? item['created_at'] ?? '').toString();
      String formattedDate = rawDate;
      try {
        final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
        formattedDate = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(parsedDate);
      } catch (_) {}

      parsedTransactions.add(
        TransactionModel(
          id: item['id']?.toString() ?? '',
          title: displayTitle,
          date: formattedDate,
          amount: amount,
          isExpense: isExpense,
          icon: isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          type: type,
          proofNumber: proofCode,
        ),
      );
    }

          final String status = data['status']?.toString() ?? 'active';
          final double estimatedShu = double.tryParse((data['estimated_shu'] ?? 0.0).toString()) ?? 0.0;

          // Parse Loan Data
          LoanModel? parsedLoan;
          if (loanResponse.statusCode == 200) {
            try {
              final lBody = jsonDecode(loanResponse.body);
              final lData = lBody['data'] ?? lBody;
              if (lData is List && lData.isNotEmpty) {
                // 1. Prioritas 1: Pinjaman Aktif / Berjalan
                for (var item in lData) {
                  final String st = (item['status'] ?? '').toString().toUpperCase();
                  if (st == 'ACTIVE' ||
                      st == 'AKTIF' ||
                      st == 'DISBURSED' ||
                      st == 'BERJALAN' ||
                      (st == 'APPROVED' &&
                          (item['remaining_principal'] == null ||
                              (double.tryParse(item['remaining_principal'].toString()) ?? 1) > 0))) {
                    parsedLoan = LoanModel.fromJson(item is Map<String, dynamic> ? item : {});
                    break;
                  }
                }

                // 2. Prioritas 2: Pinjaman dalam proses verifikasi / persetujuan
                if (parsedLoan == null) {
                  for (var item in lData) {
                    final String st = (item['status'] ?? '').toString().toUpperCase();
                    if (st == 'PENDING_ADMIN' ||
                        st == 'WAITING_ADMIN_VERIFICATION' ||
                        st == 'PENDING' ||
                        st == 'VERIFIKASI_ADMIN' ||
                        st == 'PENDING_MANAGER' ||
                        st == 'WAITING_MANAGER_APPROVAL' ||
                        st == 'MENUNGGU_KETUA' ||
                        st == 'MENUNGGU_MANAJER' ||
                        st == 'APPROVED_BY_MANAGER' ||
                        st == 'DISETUJUI_MANAJER') {
                      parsedLoan = LoanModel.fromJson(item is Map<String, dynamic> ? item : {});
                      break;
                    }
                  }
                }

                // 3. Prioritas 3: Pinjaman lainnya non-lunas/non-tolak jika ada
                if (parsedLoan == null) {
                  final first = lData.first;
                  final firstSt = (first['status'] ?? '').toString().toUpperCase();
                  if (firstSt != 'PAID_OFF' && firstSt != 'LUNAS' && firstSt != 'REJECTED') {
                    parsedLoan = LoanModel.fromJson(first is Map<String, dynamic> ? first : {});
                  }
                }
              } else if (lData is Map<String, dynamic>) {
                if (lData['active_loan'] != null) {
                  parsedLoan = LoanModel.fromJson(lData['active_loan']);
                } else if (lData['pending_loan'] != null) {
                  parsedLoan = LoanModel.fromJson(lData['pending_loan']);
                } else if (lData['current_loan'] != null) {
                  parsedLoan = LoanModel.fromJson(lData['current_loan']);
                } else if (lData['loan'] != null) {
                  parsedLoan = LoanModel.fromJson(lData['loan']);
                } else if (lData['id'] != null || lData['loan_code'] != null || lData['no_kontrak'] != null) {
                  parsedLoan = LoanModel.fromJson(lData);
                }
              }
            } catch (e) {
              debugPrint('[DASHBOARD_LOAN_ERROR] Error parsing loan: $e');
            }
          }

          // Fallback: check current_loan from details response
          if (parsedLoan == null && data != null && data['current_loan'] != null && data['current_loan'] is Map<String, dynamic>) {
            parsedLoan = LoanModel.fromJson(data['current_loan']);
          }

          setState(() {
            _userName = name;
            _memberNumber = 'ANGGOTA #$memberNo';
            _totalBalance = total;
            _savingsList = parsedSavings;
            _transactionsList = parsedTransactions;
            _memberStatus = status;
            _estimatedShu = estimatedShu;
            _currentLoan = parsedLoan;
          });

          // Handle Announcements response
          if (annResponse.statusCode == 200) {
            final annBody = jsonDecode(annResponse.body);
            if (annBody['success'] == true) {
              final List<dynamic> rawAnn = annBody['data'] ?? [];
              setState(() {
                _announcementsList = rawAnn.map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>)).toList();
              });
            }
          }
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = responseData['message'] ?? 'Gagal memuat data dashboard.';
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Gagal memuat data (Status ${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('[DASHBOARD_ERROR] Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Gagal terhubung ke server API: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  /// Membuka dialog pilihan WhatsApp kontak Admin & Manajer Koperasi
  Future<void> _openWhatsAppAdmin() async {
    final rawNumber = _memberNumber.replaceFirst('ANGGOTA #', '').trim();
    await WhatsAppHelper.showContactBottomSheet(
      context,
      memberName: _userName.isNotEmpty ? _userName : null,
      memberNumber: rawNumber.isNotEmpty ? rawNumber : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NetworkAwarenessWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        body: NotificationListener<TabSwitchNotification>(
          onNotification: (notification) {
            setState(() {
              _currentBottomNavIndex = notification.index;
            });
            return true;
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentBottomNavIndex),
              child: IndexedStack(
                index: _currentBottomNavIndex,
                children: [
                  _buildHomeTabContent(),
                  const SavingsScreen(),
                  const LoanScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  /// Membangun Konten Utama Tab Beranda / Home
  Widget _buildHomeTabContent() {
    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Terjadi kesalahan saat memuat data dashboard.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137A43),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFF137A43),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _buildGreeting(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width > 900 ? 16 : 0,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(),
                        if (_currentLoan != null) ...[
                          const SizedBox(height: 18),
                          _buildLoanSummaryCard(),
                        ],
                        const SizedBox(height: 24),
                        _buildSavingsList(),
                        const SizedBox(height: 28),
                        _buildPromoBanner(),
                        const SizedBox(height: 28),
                        _buildRecentTransactions(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // SECTION 3: MODULAR BUILD METHODS


  /// Membangun Custom AppBar dengan Logo Koperasi dan Notifikasi
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF137A43),
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/logo_koperasi.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.account_balance_rounded,
                  size: 20,
                  color: Color(0xFF137A43),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CUM PELITA HKBP DAME',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
          tooltip: 'Notifikasi',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Belum ada notifikasi baru'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.headset_mic_outlined, color: Colors.white),
          tooltip: 'Hubungi Admin via WhatsApp',
          onPressed: _openWhatsAppAdmin,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Membangun Salam Pengguna di bagian atas
  Widget _buildGreeting() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF137A43),
      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat Datang,',
                      style: TextStyle(
                        color: Color(0xD8FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: ShimmerLoadingWidget(width: 140, height: 16),
                          )
                        : Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _isLoading
                  ? const ShimmerLoadingWidget(width: 110, height: 22, borderRadius: 12)
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                         color: Colors.white.withValues(alpha: 0.18),
                         borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _memberNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun Card Utama Saldo Total Koperasi
  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF137A43), Color(0xFF0B4E2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF137A43).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Saldo Simpanan',
                  style: TextStyle(
                    color: Color(0xD8FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!_isLoading)
                  InkWell(
                    onTap: _toggleBalanceVisibility,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _isBalanceVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: ShimmerLoadingWidget(width: 180, height: 26, borderRadius: 8),
                  )
                : Text(
                    _isBalanceVisible
                        ? 'Rp ${_formatCurrency(_totalBalance)}'
                        : 'Rp ••••••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isLoading
                      ? 'Status: ...'
                      : (_memberStatus.toLowerCase() == 'inactive' || _memberStatus.toLowerCase() == 'pasif'
                          ? 'Status: Pasif'
                          : 'Status Anggota: Aktif'),
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _isLoading
                      ? 'SHU: ...'
                      : (_memberStatus.toLowerCase() == 'inactive' || _memberStatus.toLowerCase() == 'pasif'
                          ? 'SHU Terestimasi: Rp 0 (Anggota Pasif)'
                          : 'SHU 2026 Terestimasi: Rp ${_formatCurrency(_estimatedShu)}'),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun Card Ringkasan Pinjaman Koperasi
  Widget _buildLoanSummaryCard() {
    final loan = _currentLoan;
    if (loan == null) return const SizedBox.shrink();

    final String status = loan.status.trim().toUpperCase();

    // Tentukan badge visual berdasarkan status pinjaman
    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    if (status == 'APPROVED_BY_MANAGER' || status == 'DISETUJUI_MANAJER') {
      badgeBg = const Color(0xFFECFDF5);
      badgeBorder = const Color(0xFF10B981);
      badgeText = const Color(0xFF065F46);
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Disetujui Manajer – Siap Dicairkan';
    } else if (status == 'DISBURSED' ||
        status == 'ACTIVE' ||
        status == 'AKTIF' ||
        status == 'APPROVED' ||
        status == 'BERJALAN') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF15803D);
      badgeIcon = Icons.credit_card_rounded;
      badgeLabel = 'Pinjaman Aktif';
    } else if (status == 'PENDING_ADMIN' ||
        status == 'WAITING_ADMIN_VERIFICATION' ||
        status == 'PENDING' ||
        status == 'VERIFIKASI_ADMIN') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFF59E0B);
      badgeText = const Color(0xFF92400E);
      badgeIcon = Icons.hourglass_top_rounded;
      badgeLabel = 'Menunggu Verifikasi Admin';
    } else if (status == 'WAITING_MANAGER_APPROVAL' ||
        status == 'PENDING_MANAGER' ||
        status == 'MENUNGGU_KETUA' ||
        status == 'MENUNGGU_MANAJER') {
      badgeBg = const Color(0xFFEEF2FF);
      badgeBorder = const Color(0xFF6366F1);
      badgeText = const Color(0xFF3730A3);
      badgeIcon = Icons.supervisor_account_rounded;
      badgeLabel = 'Menunggu ACC Manajer';
    } else if (status == 'REJECTED' || status == 'DECLINED' || status == 'DITOLAK') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeBorder = const Color(0xFFEF4444);
      badgeText = const Color(0xFF991B1B);
      badgeIcon = Icons.cancel_rounded;
      badgeLabel = 'Pengajuan Ditolak';
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeBorder = const Color(0xFFCBD5E1);
      badgeText = const Color(0xFF475569);
      badgeIcon = Icons.info_outline_rounded;
      badgeLabel = loan.status;
    }

    final bool isActive = status == 'DISBURSED' ||
        status == 'ACTIVE' ||
        status == 'AKTIF' ||
        status == 'APPROVED' ||
        status == 'BERJALAN';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentBottomNavIndex = 2;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Baris: Ikon, Judul, & Tombol Navigasi
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF137A43).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF137A43),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pinjaman Koperasi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Badge Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorder.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeText),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sisa Pokok / Plafon Pinjaman
                Text(
                  isActive ? 'Sisa Pokok Pinjaman' : 'Plafon Pinjaman',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? 'Rp ${_formatCurrency(loan.remainingBalance)}'
                      : 'Rp ${_formatCurrency(loan.totalLoanAmount)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFFDC2626) : const Color(0xFF137A43),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Rincian Angsuran & Tenor
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Angsuran Bulan Ini',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatCurrency(loan.monthlyInstallment)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Progres Angsuran',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${loan.paidMonths} / ${loan.totalAngsuran} Bulan',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF137A43),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (isActive && loan.totalAngsuran > 0) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: loan.progressPercentage,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF137A43)),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Lihat Rincian Pinjaman',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Membangun Daftar Kartu Simpanan Koperasi (Horizontal Scroll)
  Widget _buildSavingsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rincian Simpanan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2533),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentBottomNavIndex = 1;
                  });
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: Color(0xFF137A43),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: _isLoading
              ? ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return const ShimmerLoadingWidget(width: 220, height: 140, borderRadius: 16);
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _savingsList.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final savings = _savingsList[index];
                    return _SavingsCard(
                      savings: savings,
                      isBalanceVisible: _isBalanceVisible,
                      formatCurrency: _formatCurrency,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Membangun Banner Promo / Pengumuman Koperasi
  Widget _buildPromoBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Informasi & Promo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2533),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 125,
          child: _isLoading
              ? ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return const ShimmerLoadingWidget(width: 270, height: 125, borderRadius: 16);
                  },
                )
              : _announcementsList.isEmpty
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada pengumuman / promo terbaru.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _announcementsList.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final ann = _announcementsList[index];
                        return _AnnouncementCard(
                          announcement: ann,
                          onTap: () => _showAnnouncementDetails(ann),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Membangun Daftar Transaksi Terakhir
  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaksi Terakhir',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2533),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentBottomNavIndex = 1;
                  });
                },
                child: const Text(
                  'Lihat Mutasi',
                  style: TextStyle(
                    color: Color(0xFF137A43),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: ShimmerLoadingWidget(width: double.infinity, height: 48, borderRadius: 8),
                      );
                    },
                  )
                : _transactionsList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        child: Center(
                          child: Text(
                            'Belum ada riwayat transaksi.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactionsList.length,
                        itemBuilder: (context, index) {
                          final tx = _transactionsList[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TransactionTile(
                                transaction: tx,
                                formatCurrency: _formatCurrency,
                              ),
                              if (index < _transactionsList.length - 1)
                                const Divider(height: 1, indent: 64),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }


  // SECTION 4: NAVIGATION & FAB BUILDERS


  /// Membangun Bottom Navigation Bar dengan Haptic Feedback & Indikator Aktif Animatif
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          // Getaran sentuhan responsif (Haptic Feedback)
          HapticFeedback.lightImpact();
          NavigationUtils.safeCloseOverlays(context);
          setState(() {
            _currentBottomNavIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF137A43),
        unselectedItemColor: const Color(0xFF8E9BAE),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        items: [
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(Icons.home_outlined, Icons.home_rounded, 0),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet_rounded,
              1,
            ),
            label: 'Simpanan',
          ),
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              Icons.description_outlined,
              Icons.description_rounded,
              2,
            ),
            label: 'Pinjaman',
          ),
          BottomNavigationBarItem(
            icon: _buildNavItemIcon(
              Icons.person_outline_rounded,
              Icons.person_rounded,
              3,
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  /// Helper ikon tab navigasi dengan animasi scale & kapsul indikator aktif
  Widget _buildNavItemIcon(IconData icon, IconData activeIcon, int index) {
    final bool isSelected = _currentBottomNavIndex == index;
    return AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF137A43).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF137A43) : const Color(0xFF8E9BAE),
          size: 22,
        ),
      ),
    );
  }

  String _formatCurrency(double? amount) {
    final double safeAmount = amount ?? 0.0;
    final String priceString = safeAmount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceString.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  void _showAnnouncementDetails(AnnouncementModel ann) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final String cat = ann.category.toUpperCase();
        final bool isPenting = cat == 'PENTING';
        final bool isPromo = cat == 'PROMO';
        
        final Color tagColor = isPenting
            ? const Color(0xFFEF4444)
            : isPromo
                ? const Color(0xFF16A34A)
                : const Color(0xFF3B82F6);
        final Color tagBg = isPenting
            ? const Color(0xFFFEF2F2)
            : isPromo
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFEFF6FF);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        cat,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tagColor),
                      ),
                    ),
                    Text(
                      ann.date,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  ann.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      ann.content,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137A43),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// SECTION 5: REUSABLE SUB-WIDGETS

/// Widget Kartu Item Simpanan (Horizontal)
class _SavingsCard extends StatelessWidget {
  final SavingsModel savings;
  final bool isBalanceVisible;
  final String Function(double) formatCurrency;

  const _SavingsCard({
    required this.savings,
    required this.isBalanceVisible,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: savings.themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(savings.icon, color: savings.themeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savings.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      savings.accountNumber,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isBalanceVisible
                    ? 'Rp ${formatCurrency(savings.balance)}'
                    : 'Rp •••••••',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: savings.themeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Widget Banner Item Pengumuman (Dynamic API)
class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.announcement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String cat = announcement.category.toUpperCase();
    final bool isPenting = cat == 'PENTING';
    final bool isPromo = cat == 'PROMO';
    
    // Background based on category
    final Color bgColor = isPenting
        ? const Color(0xFFB91C1C) // Merah untuk penting
        : isPromo
            ? const Color(0xFF15803D) // Hijau terang untuk promo
            : const Color(0xFF1E3A8A); // Biru untuk informasi biasa

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cat,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.87),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget Tile Item Riwayat Transaksi
class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String Function(double) formatCurrency;

  const _TransactionTile({
    required this.transaction,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWithdrawal = transaction.isExpense;
    final Color iconBgColor = isWithdrawal
        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
        : const Color(0xFF10B981).withValues(alpha: 0.1);

    final Color iconColor = isWithdrawal
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
          child: Icon(
            isWithdrawal ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          '${transaction.proofNumber} • ${transaction.date}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        trailing: Text(
          '${isWithdrawal ? "-" : "+"} Rp ${formatCurrency(transaction.amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isWithdrawal
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981),
          ),
        ),
      ),
    );
  }
}

class TabSwitchNotification extends Notification {
  final int index;
  const TabSwitchNotification(this.index);
}
