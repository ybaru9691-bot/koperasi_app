import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'home_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/whatsapp_helper.dart';

// SECTION 1: DATA MODELS
// Halaman untuk model pinjaman 
class LoanModel {
  final String id;
  final String loanNumber;
  final String loanType;
  final double totalLoanAmount; // plafon
  final double remainingBalance; // sisa pokok
  final double monthlyInstallment; // angsuran bulanan
  final double totalKewajiban; // total kewajiban
  final double totalDibayar; // total sudah dibayar
  final double totalPaidPrincipal;
  final double totalPaidInterest;
  final int tenorMonths;
  final int paidMonths; // angsuran selesai
  final int angsuranTersisa;
  final int totalAngsuran;
  final String nextDueDate;
  final double interestRatePercent;
  final String status;
  final String? rejectionReason;
  final String? applicationDate;
  final String? disbursementDate;
  final String interestMethod;
  final String collateral;
  final String purpose;
  final List<LoanInstallmentItemModel> installments;

  const LoanModel({
    required this.id,
    required this.loanNumber,
    required this.loanType,
    required this.totalLoanAmount,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.totalKewajiban,
    required this.totalDibayar,
    required this.totalPaidPrincipal,
    required this.totalPaidInterest,
    required this.tenorMonths,
    required this.paidMonths,
    required this.angsuranTersisa,
    required this.totalAngsuran,
    required this.nextDueDate,
    required this.interestRatePercent,
    required this.status,
    this.rejectionReason,
    this.applicationDate,
    this.disbursementDate,
    required this.interestMethod,
    required this.collateral,
    required this.purpose,
    required this.installments,
  });

  /// Persentase pelunasan (0.0 sampai 1.0)
  double get progressPercentage {
    if (totalAngsuran > 0) {
      return (paidMonths / totalAngsuran).clamp(0.0, 1.0);
    }
    if (totalLoanAmount <= 0) return 0.0;
    final double paidAmount = totalLoanAmount - remainingBalance;
    return (paidAmount / totalLoanAmount).clamp(0.0, 1.0);
  }

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      return double.tryParse(val.toString()) ?? 0.0;
    }
    int parseInt(dynamic val) {
      if (val == null) return 0;
      return int.tryParse(val.toString()) ?? 0;
    }

    final double plafon = parseDouble(json['plafon'] ?? json['plafon_disetujui'] ?? json['amount'] ?? json['total_loan_amount']);
    final double sisa = parseDouble(json['remaining_principal'] ?? json['sisa_pokok'] ?? json['remaining_amount'] ?? json['remaining_balance'] ?? json['amount']);
    final int tenor = parseInt(json['tenor_months'] ?? json['tenor_waktu'] ?? json['duration_months'] ?? json['tenor'] ?? 12);
    final double rate = parseDouble(json['interest_rate'] ?? json['suku_bunga'] ?? json['interest_rate_percent'] ?? json['bunga_persen'] ?? 2.5);

    double installment = parseDouble(json['monthly_installment'] ?? json['angsuran_bulanan'] ?? json['estimasi_angsuran']);
    if (installment <= 0 && plafon > 0 && tenor > 0) {
      final pokok = (plafon / tenor).ceilToDouble();
      final jasa = (plafon * (rate / 100.0)).roundToDouble();
      installment = pokok + jasa;
    }

    final double kewajiban = parseDouble(json['total_kewajiban'] ?? json['total_harus_dibayar'] ?? (installment * tenor));
    final double dibayar = parseDouble(json['total_dibayar'] ?? json['total_paid'] ?? 0);
    final double paidPrinc = parseDouble(json['total_paid_principal'] ?? 0);
    final double paidInt = parseDouble(json['total_paid_interest'] ?? 0);

    final int selesai = parseInt(json['angsuran_selesai'] ?? json['paid_months'] ?? json['angsuran_ke'] ?? 0);
    final int tersisa = parseInt(json['angsuran_tersisa'] ?? (tenor - selesai));
    final int totalAngs = parseInt(json['total_angsuran'] ?? tenor);

    List<LoanInstallmentItemModel> instList = [];
    if (json['installments'] != null && json['installments'] is List) {
      instList = (json['installments'] as List)
          .map((i) => LoanInstallmentItemModel.fromJson(i is Map<String, dynamic> ? i : {}))
          .toList();
    }

    return LoanModel(
      id: json['id']?.toString() ?? '',
      loanNumber: json['loan_code'] ?? json['no_kontrak'] ?? json['no_sh'] ?? json['loan_number'] ?? '',
      loanType: json['purpose'] ?? json['loan_type'] ?? json['jenis_pinjaman'] ?? 'Pinjaman Anggota',
      totalLoanAmount: plafon,
      remainingBalance: sisa,
      monthlyInstallment: installment,
      totalKewajiban: kewajiban > 0 ? kewajiban : (installment * tenor),
      totalDibayar: dibayar,
      totalPaidPrincipal: paidPrinc,
      totalPaidInterest: paidInt,
      tenorMonths: tenor > 0 ? tenor : 12,
      paidMonths: selesai,
      angsuranTersisa: tersisa >= 0 ? tersisa : 0,
      totalAngsuran: totalAngs > 0 ? totalAngs : tenor,
      nextDueDate: json['due_date'] ?? json['next_due_date'] ?? json['tgl_jatuh_tempo'] ?? '',
      interestRatePercent: rate,
      status: json['status']?.toString() ?? '',
      rejectionReason: json['rejection_notes'] ?? json['rejection_reason'] ?? json['notes'],
      applicationDate: json['application_date']?.toString() ?? json['created_at']?.toString(),
      disbursementDate: json['disbursement_date']?.toString(),
      interestMethod: json['interest_method']?.toString() ?? 'declining_balance',
      collateral: json['collateral']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? json['notes']?.toString() ?? '',
      installments: instList,
    );
  }
}

/// Model Data Item Jadwal & Riwayat Angsuran Bulanan
class LoanInstallmentItemModel {
  final String id;
  final int angsuranKe;
  final String dueDate;
  final String? paidAt;
  final double principalAmount;
  final double interestAmount;
  final double penaltyAmount;
  final double totalAmount;
  final double beginningBalance;
  final double endingBalance;
  final String status;
  final bool isPaid;

  const LoanInstallmentItemModel({
    required this.id,
    required this.angsuranKe,
    required this.dueDate,
    this.paidAt,
    required this.principalAmount,
    required this.interestAmount,
    required this.penaltyAmount,
    required this.totalAmount,
    required this.beginningBalance,
    required this.endingBalance,
    required this.status,
    required this.isPaid,
  });

  factory LoanInstallmentItemModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      return double.tryParse(val.toString()) ?? 0.0;
    }
    int parseInt(dynamic val) {
      if (val == null) return 0;
      return int.tryParse(val.toString()) ?? 0;
    }

    final rawStatus = (json['status'] ?? '').toString().toLowerCase();
    final bool paid = json['is_paid'] == true || rawStatus == 'paid' || rawStatus == 'lunas';

    return LoanInstallmentItemModel(
      id: json['id']?.toString() ?? '',
      angsuranKe: parseInt(json['angsuran_ke'] ?? json['installment_number'] ?? json['period_text'] ?? 0),
      dueDate: json['due_date']?.toString() ?? json['tgl_jatuh_tempo']?.toString() ?? '',
      paidAt: (json['paid_at'] != null && json['paid_at'].toString().isNotEmpty && json['paid_at'].toString() != 'null')
          ? json['paid_at'].toString()
          : ((json['payment_date'] != null && json['payment_date'].toString().isNotEmpty && json['payment_date'].toString() != 'null') ? json['payment_date'].toString() : null),
      principalAmount: parseDouble(json['principal_amount'] ?? json['angsuran_pokok']),
      interestAmount: parseDouble(json['interest_amount'] ?? json['jasa_pinjaman']),
      penaltyAmount: parseDouble(json['penalty_amount'] ?? json['denda']),
      totalAmount: parseDouble(json['total_amount'] ?? json['total_bayar'] ?? json['amount']),
      beginningBalance: parseDouble(json['beginning_balance'] ?? json['sisa_pokok_awal']),
      endingBalance: parseDouble(json['ending_balance'] ?? json['sisa_pokok_akhir']),
      status: paid ? 'Lunas' : 'Belum Bayar',
      isPaid: paid,
    );
  }
}

// Backward compatibility alias
typedef LoanInstallmentHistoryModel = LoanInstallmentItemModel;

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip out all characters that are not digits
    String stripped = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    if (stripped.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final double numVal = double.tryParse(stripped) ?? 0.0;
    // Format using en_US which uses commas, then replace commas with dots for id_ID style
    final String formatted = NumberFormat('#,###', 'en_US').format(numVal).replaceAll(',', '.');

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


// SECTION 2: LOAN SCREEN WIDGET
/// LoanScreen menampilkan informasi pinjaman aktif, progress pelunasan,
/// riwayat pembayaran angsuran, serta state pengajuan pinjaman bertahap.

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  LoanModel? _currentLoan;
  bool _isLoading = true;
  bool _hasBukuBiru = true;

  @override
  void initState() {
    super.initState();
    _fetchLoanData();
  }

  Future<void> _fetchLoanData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService().getSavedUser();
      if (user != null) {
        _hasBukuBiru = user['has_buku_biru'] == null
            ? (user['buku_biru'] != false)
            : (user['has_buku_biru'] == true || user['has_buku_biru'] == 1 || user['has_buku_biru'] == '1');
      }

      final token = await AuthService().getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/user/loans'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;

        LoanModel? selectedLoan;

        if (data is List) {
          if (data.isNotEmpty) {
            // 1. Prioritas 1: Pinjaman Aktif Berjalan (DISBURSED / ACTIVE / AKTIF)
            for (var item in data) {
              final String st = (item['status'] ?? '').toString().toUpperCase();
              if (st == 'ACTIVE' ||
                  st == 'AKTIF' ||
                  st == 'DISBURSED' ||
                  st == 'BERJALAN' ||
                  (st == 'APPROVED' &&
                      (item['remaining_principal'] == null ||
                          (double.tryParse(item['remaining_principal'].toString()) ?? 1) > 0))) {
                selectedLoan = LoanModel.fromJson(item is Map<String, dynamic> ? item : {});
                break;
              }
            }

            // 2. Prioritas 2: Pinjaman yang sedang dalam proses verifikasi / persetujuan
            if (selectedLoan == null) {
              for (var item in data) {
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
                  selectedLoan = LoanModel.fromJson(item is Map<String, dynamic> ? item : {});
                  break;
                }
              }
            }

            // 3. Prioritas 3: Pinjaman lainnya (Rejected / Paid Off / dll)
            if (selectedLoan == null) {
              final firstItem = data.first;
              selectedLoan = LoanModel.fromJson(firstItem is Map<String, dynamic> ? firstItem : {});
            }
          }
        } else if (data is Map<String, dynamic>) {
          if (data['has_buku_biru'] != null) {
            _hasBukuBiru = data['has_buku_biru'] == true || data['has_buku_biru'] == 1 || data['has_buku_biru'] == '1';
          }
          if (data['active_loan'] != null) {
            selectedLoan = LoanModel.fromJson(data['active_loan']);
          } else if (data['pending_loan'] != null) {
            selectedLoan = LoanModel.fromJson(data['pending_loan']);
          } else if (data['current_loan'] != null) {
            selectedLoan = LoanModel.fromJson(data['current_loan']);
          } else if (data['loan'] != null) {
            selectedLoan = LoanModel.fromJson(data['loan']);
          } else if (data['id'] != null || data['loan_code'] != null || data['no_kontrak'] != null) {
            selectedLoan = LoanModel.fromJson(data);
          }
        }

        if (mounted) {
          setState(() {
            _currentLoan = selectedLoan;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching loans: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Menampilkan modal pengajuan pinjaman baru
  void _showApplyLoanModal() {
    if (!_hasBukuBiru) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan Pinjaman hanya berlaku untuk Anggota Penuh (Pemilik Buku Biru)'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _buildApplyLoanFormModal(ctx),
      ),
    );
  }

  /// Menampilkan modal pembayaran angsuran
  void _showPayInstallmentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.6,
        child: _buildPayInstallmentModal(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF137A43)),
        ),
      );
    }

    Widget bodyWidget;
    final String status = (_currentLoan?.status ?? '').trim().toUpperCase();

    // 1. Status: pending_admin / WAITING_ADMIN_VERIFICATION
    if (status == 'PENDING_ADMIN' ||
        status == 'WAITING_ADMIN_VERIFICATION' ||
        status == 'PENDING' ||
        status == 'VERIFIKASI_ADMIN') {
      bodyWidget = _buildPendingAdminCard(_currentLoan!);
    }
    // 2. Status: WAITING_MANAGER_APPROVAL / pending_manager / menunggu_ketua
    else if (status == 'WAITING_MANAGER_APPROVAL' ||
        status == 'PENDING_MANAGER' ||
        status == 'MENUNGGU_KETUA' ||
        status == 'MENUNGGU_MANAJER') {
      bodyWidget = _buildWaitingManagerCard(_currentLoan!);
    }
    // 3. Status: APPROVED_BY_MANAGER / disetujui_manajer
    else if (status == 'APPROVED_BY_MANAGER' ||
        status == 'DISETUJUI_MANAJER') {
      bodyWidget = _buildApprovedByManagerCard(_currentLoan!);
    }
    // 4. Status: DISBURSED / ACTIVE / AKTIF
    else if (status == 'DISBURSED' ||
        status == 'ACTIVE' ||
        status == 'AKTIF' ||
        status == 'APPROVED' ||
        status == 'DEFAULTED' ||
        status == 'BERJALAN') {
      bodyWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveLoanCard(_currentLoan!),
          const SizedBox(height: 16),
          _buildQuickActionButtons(),
          const SizedBox(height: 20),
          _buildLoanInfoSection(_currentLoan!),
          const SizedBox(height: 20),
          _buildPaymentSummarySection(_currentLoan!),
          const SizedBox(height: 24),
          _buildInstallmentScheduleSection(_currentLoan!),
          const SizedBox(height: 24),
        ],
      );
    }
    // 5. Status: REJECTED / DITOLAK
    else if (status == 'REJECTED' ||
        status == 'DECLINED' ||
        status == 'DITOLAK') {
      bodyWidget = _buildRejectedStatusCard(_currentLoan!);
    }
    // 6. Status: PAID_OFF / LUNAS / loan == null -> Boleh mengajukan pinjaman baru
    else {
      bodyWidget = _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchLoanData,
        color: const Color(0xFF137A43),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 800,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: bodyWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Card Status: Pengajuan Sedang Diproses (pending_admin / WAITING_ADMIN_VERIFICATION)
  Widget _buildPendingAdminCard(LoanModel loan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 44,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pengajuan Sedang Diproses',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pengajuan pinjaman Anda sebesar ${_fmtRp(loan.totalLoanAmount)} telah kami terima. Proses peninjauan berkas membutuhkan waktu maksimal 1 (satu) minggu. Silakan hubungi admin kami untuk informasi lebih lanjut.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF78350F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 6),
                      Text(
                        'Menunggu Peninjauan (Maks. 1 Minggu)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => WhatsAppHelper.showContactBottomSheet(
                    context,
                    customHeaderTitle: 'Hubungi Admin Koperasi',
                    customHeaderSubtitle: 'Konsultasikan kelengkapan berkas & status pinjaman Anda:',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF137A43),
                    side: const BorderSide(color: Color(0xFF137A43), width: 1.2),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF137A43)),
                  label: const Text(
                    'Hubungi Admin Koperasi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF137A43),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLoanInfoSection(loan),
        const SizedBox(height: 20),
        _buildPaymentSummarySection(loan),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 2. Card Status: Menunggu Persetujuan Manajer (WAITING_MANAGER_APPROVAL)
  Widget _buildWaitingManagerCard(LoanModel loan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          color: const Color(0xFFEEF2FF),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.supervisor_account_rounded,
                    size: 44,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Menunggu Persetujuan Manajer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3730A3),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pengajuan Pinjaman Sebesar ${_fmtRp(loan.totalLoanAmount)} sedang menunggu persetujuan Manajer.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF312E81),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_bottom_rounded, size: 16, color: Color(0xFF4338CA)),
                      SizedBox(width: 6),
                      Text(
                        'Status: Menunggu Persetujuan Manajer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLoanInfoSection(loan),
        const SizedBox(height: 20),
        _buildPaymentSummarySection(loan),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 3. Card Status: Disetujui Manajer (APPROVED_BY_MANAGER)
  Widget _buildApprovedByManagerCard(LoanModel loan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
          ),
          color: const Color(0xFFECFDF5),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 44,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pinjaman Disetujui Manajer!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pinjaman Disetujui Manajer! Silakan datang ke kantor koperasi / kasir untuk pencairan dana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF065F46)),
                      SizedBox(width: 6),
                      Text(
                        'Status: Disetujui Manajer – Siap Dicairkan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLoanInfoSection(loan),
        const SizedBox(height: 20),
        _buildPaymentSummarySection(loan),
        if (loan.installments.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildInstallmentScheduleSection(loan),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Section 1: Info Pinjaman
  Widget _buildLoanInfoSection(LoanModel loan) {
    final methodText = (loan.interestMethod.toLowerCase() == 'declining_balance' ||
            loan.interestMethod.toLowerCase().contains('menurun'))
        ? 'Saldo Menurun'
        : 'Flat';

    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF137A43).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined, color: Color(0xFF137A43), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Info Pinjaman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('No. Kontrak', loan.loanNumber.isNotEmpty ? loan.loanNumber : '-'),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Plafon Disetujui', _fmtRp(loan.totalLoanAmount), isBoldValue: true),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Tenor', '${loan.tenorMonths} Bulan'),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Suku Bunga', '${loan.interestRatePercent.toStringAsFixed(2)}% / bulan'),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Metode Bunga', methodText),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Jaminan', loan.collateral.isNotEmpty ? loan.collateral : '-'),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Tujuan Pinjaman', loan.purpose.isNotEmpty ? loan.purpose : '-'),
        ],
      ),
    );
  }

  /// Section 2: Ringkasan Pembayaran
  Widget _buildPaymentSummarySection(LoanModel loan) {
    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ringkasan Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Angsuran per Bulan', _fmtRp(loan.monthlyInstallment), isBoldValue: true),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Total Kewajiban', _fmtRp(loan.totalKewajiban)),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Total Sudah Dibayar', _fmtRp(loan.totalDibayar), valueColor: const Color(0xFF16A34A), isBoldValue: true),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Sisa Pokok', _fmtRp(loan.remainingBalance), valueColor: const Color(0xFFDC2626), isBoldValue: true),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progres Angsuran',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Text(
                '${loan.paidMonths} dari ${loan.totalAngsuran} Bulan (${(loan.progressPercentage * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF137A43)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: loan.progressPercentage,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF137A43)),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 3: Jadwal Angsuran (ListView)
  Widget _buildInstallmentScheduleSection(LoanModel loan) {
    final list = loan.installments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Jadwal Angsuran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${list.length} Periode',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Belum ada jadwal angsuran.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildInstallmentItemCard(item);
            },
          ),
      ],
    );
  }

  Widget _buildInstallmentItemCard(LoanInstallmentItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isPaid ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris: Angsuran Ke-X & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Angsuran Ke-${item.angsuranKe}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: item.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isPaid ? Icons.check_circle_rounded : Icons.pending_outlined,
                      size: 13,
                      color: item.isPaid ? const Color(0xFF15803D) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.isPaid ? 'Lunas' : 'Belum Bayar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isPaid ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          // Grid Detail Angsuran
          _buildItemDetailRow('Jatuh Tempo', _formatDate(item.dueDate)),
          const SizedBox(height: 6),
          _buildItemDetailRow('Tanggal Bayar', item.paidAt != null ? _formatDate(item.paidAt) : '-'),
          const SizedBox(height: 6),
          _buildItemDetailRow('Pokok', _fmtRp(item.principalAmount)),
          const SizedBox(height: 6),
          _buildItemDetailRow('Jasa / Bunga', _fmtRp(item.interestAmount)),
          if (item.penaltyAmount > 0) ...[
            const SizedBox(height: 6),
            _buildItemDetailRow('Denda', _fmtRp(item.penaltyAmount), valueColor: const Color(0xFFDC2626)),
          ],
          const SizedBox(height: 6),
          _buildItemDetailRow('Total Bayar', _fmtRp(item.totalAmount), isBold: true, valueColor: const Color(0xFF137A43)),
          const Divider(height: 16, color: Color(0xFFF8FAFC)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sisa Pokok Awal', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(_fmtRp(item.beginningBalance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Sisa Pokok Akhir', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    Text(_fmtRp(item.endingBalance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBoldValue = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty || rawDate == '-' || rawDate == 'null') return '-';
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
      }
    } catch (_) {}
    return rawDate;
  }

  /// 5. Card Status: Pengajuan Ditolak (REJECTED)
  Widget _buildRejectedStatusCard(LoanModel loan) {
    final reason = (loan.rejectionReason != null && loan.rejectionReason!.trim().isNotEmpty)
        ? loan.rejectionReason!
        : 'Pengajuan pinjaman ditolak oleh pimpinan koperasi.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          color: const Color(0xFFFEF2F2),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    size: 44,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pengajuan Pinjaman Ditolak',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7F1D1D),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alasan Penolakan:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F1D1D),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showApplyLoanModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137A43),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text(
                      'Ajukan Pinjaman Baru',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // SECTION 3: MODULAR BUILD METHODS
  /// AppBar khusus Halaman Pinjaman
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF137A43),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        tooltip: 'Kembali',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            const TabSwitchNotification(0).dispatch(context);
          }
        },
      ),
      title: const Text(
        'Pinjaman Koperasi',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }



  /// Kartu Status Pinjaman Aktif dengan Progress Bar Pelunasan
  Widget _buildActiveLoanCard(LoanModel loan) {
    final double percent = loan.progressPercentage;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF137A43), Color(0xFF0F5A32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF137A43).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu: Nama Pinjaman & Nomor ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.loanType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No. Kontrak: ${loan.loanNumber}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  loan.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sisa Pokok Pinjaman
          const Text(
            'Sisa Pokok Pinjaman',
            style: TextStyle(
              color: Color(0xD8FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${_formatCurrency(loan.remainingBalance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Progress Bar Pelunasan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Pelunasan (${(percent * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${loan.paidMonths} dari ${loan.tenorMonths} Bulan',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 14),

          // Rincian Angsuran & Tanggal Jatuh Tempo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Angsuran Per Bulan',
                    style: TextStyle(color: Color(0xD8FFFFFF), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${_formatCurrency(loan.monthlyInstallment)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Jatuh Tempo Berikutnya',
                    style: TextStyle(color: Color(0xD8FFFFFF), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loan.nextDueDate,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tombol Aksi saat Pinjaman Aktif Berjalan (Lihat Angsuran & Tagihan)
  Widget _buildQuickActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showPayInstallmentModal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF137A43),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.receipt_long_rounded, size: 20),
        label: const Text(
          'Lihat Angsuran & Tagihan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }







  /// Tampilan State Kosong jika Anggota belum memiliki Pinjaman Aktif
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF137A43).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.request_quote_outlined,
              size: 72,
              color: Color(0xFF137A43),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum Ada Pinjaman Aktif',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2533),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nikmati fasilitas pinjaman dana anggota koperasi dengan bunga saldo menurun 2.50% per bulan dan proses transparan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
          if (!_hasBukuBiru)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              color: const Color(0xFFFFFBEB),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.lock_rounded, size: 40, color: Color(0xFFD97706)),
                    SizedBox(height: 12),
                    Text(
                      'Akses Pinjaman Terbatas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Pengajuan Pinjaman hanya berlaku untuk Anggota Penuh (Pemilik Buku Biru). Silakan buka Saham Buku Biru melalui Admin/Manajer untuk menikmati fasilitas ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFB45309), height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showApplyLoanModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137A43),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                label: const Text(
                  'Ajukan Pinjaman Sekarang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }



  /// Hitung estimasi angsuran (Saldo Menurun 2.50% atau Bunga Tetap / Flat 1.00%)
  Map<String, double> _calcInstallmentEst(double nominal, int tenor, String method, double rate) {
    if (nominal <= 0 || tenor <= 0) return {'pokok': 0, 'jasa': 0, 'total': 0};
    final double pokok = (nominal / tenor).ceilToDouble();
    final double rateFraction = rate / 100.0;
    // Flat: Jasa dihitung dari plafon pinjaman awal (konstan)
    // Declining: Jasa bulan ke-1 dihitung dari saldo awal (nominal)
    final double jasa = (nominal * rateFraction).roundToDouble();
    return {'pokok': pokok, 'jasa': jasa, 'total': pokok + jasa};
  }

  String _fmtRp(double val) {
    return 'Rp ${_formatCurrency(val)}';
  }

  Widget _simRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: highlight ? const Color(0xFF059669) : const Color(0xFF1A2533),
          ),
        ),
      ],
    );
  }

  /// Form Modal Bottom Sheet untuk Pengajuan Pinjaman Baru
  Widget _buildApplyLoanFormModal(BuildContext modalContext) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController collateralController = TextEditingController();
    final TextEditingController purposeController = TextEditingController();
    String selectedTenor = '12 Bulan';
    String selectedInterestMethod = 'declining_balance'; // 'declining_balance' (2.50%) or 'flat' (1.00%)
    bool isSubmitting = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final double selectedInterestRate = selectedInterestMethod == 'flat' ? 1.00 : 2.50;
        final String rawAmt = amountController.text.replaceAll('.', '').trim();
        final double nominalVal = double.tryParse(rawAmt) ?? 0;
        final int tenorVal = int.tryParse(selectedTenor.split(' ')[0]) ?? 12;
        final est = _calcInstallmentEst(nominalVal, tenorVal, selectedInterestMethod, selectedInterestRate);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag handle indicator
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Scrollable Form Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                    top: 10,
                    left: 20,
                    right: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengajuan Pinjaman Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2533),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Isi nominal, jangka waktu, dan skema bunga yang Anda butuhkan.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          ThousandsSeparatorInputFormatter(),
                        ],
                        onChanged: (val) {
                          final cleanVal = val.replaceAll('.', '').replaceAll('Rp', '').replaceAll(' ', '').replaceAll(',', '').trim();
                          final amount = double.tryParse(cleanVal) ?? 0;
                          setModalState(() {
                            if (amount >= 50000000) {
                              selectedInterestMethod = 'flat';
                            } else {
                              selectedInterestMethod = 'declining_balance';
                            }
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Nominal Pinjaman (Rp)',
                          hintText: 'Contoh: 10.000.000',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTenor,
                        decoration: InputDecoration(
                          labelText: 'Jangka Waktu (Tenor)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        items: ['3 Bulan', '6 Bulan', '12 Bulan', '18 Bulan', '24 Bulan', '36 Bulan', '48 Bulan', '60 Bulan']
                            .map(
                              (tenor) => DropdownMenuItem(value: tenor, child: Text(tenor)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedTenor = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // ── Pilihan Skema Suku Bunga ──
                      const Text(
                        'Skema Suku Bunga',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedInterestMethod = 'declining_balance';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: selectedInterestMethod == 'declining_balance'
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedInterestMethod == 'declining_balance'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFE2E8F0),
                                    width: selectedInterestMethod == 'declining_balance' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          selectedInterestMethod == 'declining_balance'
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 16,
                                          color: selectedInterestMethod == 'declining_balance'
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Saldo Menurun',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '2,50% / bulan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedInterestMethod = 'flat';
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: selectedInterestMethod == 'flat'
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedInterestMethod == 'flat'
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFE2E8F0),
                                    width: selectedInterestMethod == 'flat' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          selectedInterestMethod == 'flat'
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 16,
                                          color: selectedInterestMethod == 'flat'
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Bunga Tetap / Flat',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '1,00% / bulan',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ── Kartu Simulasi Estimasi Angsuran ──
                      if (nominalVal > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selectedInterestMethod == 'flat' ? const Color(0xFFF0F7FF) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedInterestMethod == 'flat' ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calculate_rounded,
                                    size: 16,
                                    color: selectedInterestMethod == 'flat' ? const Color(0xFF1D4ED8) : const Color(0xFF137A43),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    selectedInterestMethod == 'flat'
                                        ? 'Estimasi Tagihan Bulanan (Flat 1.00%)'
                                        : 'Estimasi Tagihan Bulan ke-1 (Menurun 2.50%)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedInterestMethod == 'flat' ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _simRow('Angsuran Pokok', _fmtRp(est['pokok']!)),
                              const SizedBox(height: 4),
                              _simRow(
                                selectedInterestMethod == 'flat' ? 'Jasa Flat 1.00% / bln' : 'Jasa 2.50% (Bln 1)',
                                _fmtRp(est['jasa']!),
                                highlight: true,
                              ),
                              Divider(
                                height: 14,
                                color: selectedInterestMethod == 'flat' ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                              ),
                              _simRow(
                                selectedInterestMethod == 'flat' ? 'Total Angsuran per Bulan' : 'Total Tagihan Bln 1',
                                _fmtRp(est['total']!),
                                bold: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedInterestMethod == 'flat'
                                    ? '* Metode Bunga Flat 1.00% — angsuran pokok dan jasa bernilai tetap setiap bulan hingga lunas.'
                                    : '* Metode Bunga Saldo Menurun 2.50% — angsuran jasa berkurang tiap bulan seiring berkurangnya sisa pokok.',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontStyle: FontStyle.italic, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: collateralController,
                        decoration: InputDecoration(
                          labelText: 'Jaminan / Agunan',
                          hintText: 'BPKB Motor / Sertifikat Tanah / BPKB Mobil',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: purposeController,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: 'Keperluan / Alasan Pinjaman',
                          hintText: 'Jelaskan alasan pengajuan pinjaman Anda...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final cleanAmount = amountController.text.replaceAll('.', '').replaceAll('Rp', '').trim();
                                  final purposeText = purposeController.text.trim();
                                  final collateralText = collateralController.text.trim();
                                  
                                  final amountVal = double.tryParse(cleanAmount);
                                  if (amountVal == null || amountVal <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Nominal pinjaman wajib diisi dan harus lebih besar dari 0!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    isSubmitting = true;
                                  });

                                  try {
                                    final token = await AuthService().getToken();
                                    final headers = {
                                      'Content-Type': 'application/json',
                                      'Accept': 'application/json',
                                      if (token != null) 'Authorization': 'Bearer $token',
                                    };

                                    final response = await http.post(
                                      Uri.parse('${AuthService.staticBaseUrl}/user/loans/apply'),
                                      headers: headers,
                                      body: jsonEncode({
                                        'amount': amountVal,
                                        'tenor': int.tryParse(selectedTenor.split(' ')[0]) ?? 12,
                                        'interest_method': selectedInterestMethod,
                                        'interest_rate': selectedInterestRate,
                                        'purpose': purposeText,
                                        'collateral': collateralText,
                                      }),
                                    ).timeout(const Duration(seconds: 60));

                                    if (response.statusCode == 200 || response.statusCode == 201) {
                                      if (context.mounted) {
                                        Navigator.of(modalContext).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Pengajuan Pinjaman Berhasil Dikirim!'),
                                            backgroundColor: Color(0xFF137A43),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        _fetchLoanData();
                                      }
                                    } else {
                                      final body = jsonDecode(response.body);
                                      throw body['message'] ?? 'Gagal mengirim pengajuan.';
                                    }
                                  } catch (e) {
                                    final errorMsg = e.toString().replaceFirst('Exception: ', '');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(errorMsg),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } finally {
                                    setModalState(() {
                                      isSubmitting = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF137A43),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Kirim Pengajuan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Form Modal Bottom Sheet untuk Pembayaran Angsuran 
  Widget _buildPayInstallmentModal(BuildContext modalContext) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                top: 10,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pembayaran Angsuran',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2533),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentLoan != null
                        ? 'Tagihan Angsuran ke-${_currentLoan!.paidMonths + 1} (Jatuh Tempo: ${_currentLoan!.nextDueDate})'
                        : 'Tagihan Angsuran',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF137A43).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Tagihan:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2533),
                          ),
                        ),
                        Text(
                          'Rp ${_formatCurrency(_currentLoan?.monthlyInstallment ?? 0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF137A43),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Segera Hubungi Admin Untuk Melakukan Pembayaran.',
                            ),
                            backgroundColor: Color(0xFF137A43),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137A43),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper format mata uang Rupiah
  String _formatCurrency(double? amount) {
    final double safeAmount = amount ?? 0.0;
    final String priceString = safeAmount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceString.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }
}
