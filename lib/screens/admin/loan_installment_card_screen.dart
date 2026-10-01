import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_input_formatter.dart';

/// Header metadata pinjaman (dari API atau fallback statis)
class LoanCardHeader {
  final int? loanId;
  final String loanCode;
  final String memberName;
  final String memberNo;
  final String church;
  final String address;
  final String phone;
  final int totalLoanAmount;
  final int tenorMonths;
  final double interestRate;
  final String interestMethod;
  final String collateral;
  final String dueDate;
  final String disbursementDate;
  final int remainingBalance;

  int get remainingPrincipal => remainingBalance;
  int get amount => totalLoanAmount;

  const LoanCardHeader({
    this.loanId,
    required this.loanCode,
    required this.memberName,
    required this.memberNo,
    required this.church,
    required this.address,
    required this.phone,
    required this.totalLoanAmount,
    required this.tenorMonths,
    required this.interestRate,
    this.interestMethod = 'declining_balance',
    required this.collateral,
    required this.dueDate,
    required this.disbursementDate,
    this.remainingBalance = 0,
  });

  factory LoanCardHeader.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

    final memberMap = j['member'] is Map ? j['member'] as Map<String, dynamic> : null;
    final mName = memberMap?['name'] ?? memberMap?['nama'] ?? j['nama_anggota'] ?? j['member_name'] ?? j['nama'] ?? '-';
    final mNo = memberMap?['member_number'] ?? memberMap?['no_anggota'] ?? j['no_anggota'] ?? j['member_no'] ?? '-';
    final mAddr = memberMap?['address'] ?? memberMap?['alamat'] ?? j['alamat'] ?? j['address'] ?? '-';
    final mPhone = memberMap?['phone'] ?? memberMap?['telepon'] ?? memberMap?['no_hp'] ?? j['no_hp'] ?? j['phone'] ?? '-';

    return LoanCardHeader(
      loanId: j['loan_id'] != null
          ? int.tryParse(j['loan_id'].toString())
          : (j['id'] != null ? int.tryParse(j['id'].toString()) : null),
      loanCode: j['loan_number'] ?? j['loan_code'] ?? j['no_sh'] ?? j['no_kontrak'] ?? j['sh_number'] ?? '-',
      memberName: mName,
      memberNo: mNo,
      church: j['church'] ?? j['church_sector'] ?? 'CUM PELITA HKBP RESSORT DAME',
      address: mAddr,
      phone: mPhone,
      totalLoanAmount: i(j['amount'] ?? j['total_loan_amount'] ?? j['plafon'] ?? j['plafon_pinjaman'] ?? j['nominal_pinjaman']),
      tenorMonths: i(j['duration_months'] ?? j['tenor_months'] ?? j['tenor_bulan'] ?? j['tenor'] ?? 12),
      interestRate: d(j['interest_rate'] ?? j['suku_bunga'] ?? j['bunga_persen'] ?? 2.5),
      interestMethod: j['interest_method']?.toString() ?? 'declining_balance',
      collateral: j['collateral_type'] ?? j['collateral'] ?? j['agunan'] ?? j['jaminan'] ?? '-',
      dueDate: j['due_date'] ?? j['tanggal_jatuh_tempo_akhir'] ?? j['jatuh_tempo'] ?? '-',
      disbursementDate: j['tanggal_cair'] ?? j['tanggal_pencairan'] ?? j['disbursement_date'] ?? j['start_date'] ?? j['created_at'] ?? '-',
      remainingBalance: i(j['remaining_principal'] ?? j['remainingPrincipal'] ?? j['remaining_balance'] ?? j['sisa_pokok']),
    );
  }
}

/// Model Data Histori Angsuran Pinjaman
class InstallmentRecord {
  final dynamic id;
  final int no;
  final String date;
  final String proofCode;
  final int principalPaid;
  final int remainingBalance;
  final int interestPaid;
  final int penaltyPaid;
  final String status; // 'paid', 'unpaid', 'late', 'partially_paid'
  final bool isPaid;
  final String tellerName;

  const InstallmentRecord({
    this.id,
    required this.no,
    required this.date,
    required this.proofCode,
    required this.principalPaid,
    required this.remainingBalance,
    required this.interestPaid,
    required this.penaltyPaid,
    this.status = 'unpaid',
    this.isPaid = false,
    this.tellerName = 'Kasir',
  });

  factory InstallmentRecord.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    final rawStatus = j['status']?.toString() ?? '';
    final isPaidValue = j['is_paid'] == true ||
        j['is_paid'] == 1 ||
        j['is_paid'] == '1' ||
        j['is_paid'] == 'true' ||
        rawStatus.toLowerCase() == 'paid' ||
        rawStatus.toLowerCase() == 'lunas';

    return InstallmentRecord(
      id: j['id'],
      no: i(j['angsuran_ke'] ?? j['installment_order'] ?? j['installment_number'] ?? j['no']),
      date: j['tanggal_bayar'] ?? j['date'] ?? j['transaction_date'] ?? j['paid_at'] ?? j['payment_date'] ?? '-',
      proofCode: j['no_bukti'] ?? j['receipt_number'] ?? j['proof_code'] ?? '-',
      principalPaid: i(j['angsuran_pokok'] ?? j['principal_amount'] ?? j['principal_paid'] ?? j['pokok']),
      remainingBalance: i(j['sisa_pokok_akhir'] ?? j['ending_balance'] ?? j['remaining_balance'] ?? j['sisa_pokok']),
      interestPaid: i(j['jasa_pinjaman'] ?? j['interest_amount'] ?? j['interest_paid'] ?? j['jasa']),
      penaltyPaid: i(j['denda'] ?? j['late_fee'] ?? j['penalty_fee'] ?? j['penalty_amount']),
      status: rawStatus.isNotEmpty ? rawStatus : (isPaidValue ? 'paid' : 'unpaid'),
      isPaid: isPaidValue,
      tellerName: j['teller_name'] ?? j['paraf'] ?? 'Kasir',
    );
  }
}

/// Screen "Kartu Pinjaman & Riwayat Angsuran" Koperasi CUM Pelita
/// Mendukung 2 Mode Akses: Admin (Full + Input Modal) & User/Anggota (Read-Only)
class LoanInstallmentCardScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int? loanId;

  const LoanInstallmentCardScreen({
    super.key,
    this.onOpenDrawer,
    this.loanId,
  });

  @override
  State<LoanInstallmentCardScreen> createState() => _LoanInstallmentCardScreenState();
}

class _LoanInstallmentCardScreenState extends State<LoanInstallmentCardScreen> {
  // ── UI State 
  bool _isAdmin = true;
  bool _isLoading = true;
  bool _isPrinting = false;
  String? _errorMessage;

  // ── Data dari API
  int? _currentLoanId;
  List<Map<String, dynamic>> _availableLoans = [];
  LoanCardHeader? _header;
  List<InstallmentRecord> _installments = [];

  @override
  void initState() {
    super.initState();
    _currentLoanId = widget.loanId;
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _fetchLoanDropdownList();
    if (_availableLoans.isNotEmpty && _currentLoanId == null) {
      _currentLoanId = int.tryParse(_availableLoans.first['id']?.toString() ?? '');
    }
    if (_currentLoanId != null) {
      await _fetchLoanCard(_currentLoanId);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Belum ada data pinjaman aktif.';
        });
      }
    }
  }

  Future<void> _fetchLoanDropdownList() async {
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final resp = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/loans/dropdown-list'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final raw = body['data'] is List ? body['data'] : (body['loans'] ?? []);
        if (raw is List && raw.isNotEmpty) {
          _availableLoans = raw.whereType<Map<String, dynamic>>().toList();
          return;
        }
      }

      // Fallback: /admin/loans/dropdown-list
      final resp2 = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans/dropdown-list'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (resp2.statusCode == 200) {
        final body = jsonDecode(resp2.body);
        final raw = body['data'] is List ? body['data'] : (body['loans'] ?? []);
        if (raw is List && raw.isNotEmpty) {
          _availableLoans = raw.whereType<Map<String, dynamic>>().toList();
          return;
        }
      }

      // Fallback 2: /admin/loans?status=all
      final listResp = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/admin/loans?status=all'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (listResp.statusCode == 200) {
        final listBody = jsonDecode(listResp.body);
        final rawLoans = listBody['data']?['data'] ?? listBody['data'] ?? listBody['loans'] ?? [];
        if (rawLoans is List && rawLoans.isNotEmpty) {
          _availableLoans = rawLoans.whereType<Map<String, dynamic>>().map((loan) {
            final id = int.tryParse(loan['id']?.toString() ?? '') ?? 0;
            final code = loan['loan_code'] ?? loan['no_kontrak'] ?? '#$id';
            final memberName = loan['member']?['name'] ?? loan['nama_anggota'] ?? 'Anggota';
            final memberNo = loan['member']?['member_number'] ?? loan['no_anggota'] ?? '-';
            final sisa = num.tryParse(loan['remaining_principal']?.toString() ?? loan['sisa_pokok']?.toString() ?? '0') ?? 0;
            return {
              'id': id,
              'loan_code': code,
              'member_name': memberName,
              'member_no': memberNo,
              'amount': num.tryParse(loan['amount']?.toString() ?? '0') ?? 0,
              'remaining_balance': sisa,
              'label': '$memberName ($memberNo) - No. SH: $code (Sisa ${_formatRupiah(sisa)})',
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[LOAN_CARD] fetch dropdown error: $e');
    }
  }

  Future<void> _fetchLoanCard([int? targetLoanId]) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      int? loanToFetch = targetLoanId ?? _currentLoanId;
      if (loanToFetch == null && _availableLoans.isNotEmpty) {
        loanToFetch = int.tryParse(_availableLoans.first['id']?.toString() ?? '');
      }

      if (loanToFetch != null) {
        _currentLoanId = loanToFetch;
        final response = await http.get(
          Uri.parse('${AuthService.staticBaseUrl}/loans/$loanToFetch/card'),
          headers: headers,
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final data = body['data'] ?? body;
          final headerRaw = data['header'] ?? data['active_loan'] ?? data['loan'] ?? data;
          _header = LoanCardHeader.fromJson(headerRaw is Map<String, dynamic> ? headerRaw : (data is Map<String, dynamic> ? data : {}));

          final rawInst = data['installments'] ?? headerRaw['installments'];
          if (rawInst is List) {
            _installments = rawInst
                .map((i) => InstallmentRecord.fromJson(i as Map<String, dynamic>))
                .toList();
          } else {
            _installments = [];
          }
          _errorMessage = null;
        } else if (response.statusCode == 404) {
          _availableLoans.removeWhere((loan) => loan['id']?.toString() == loanToFetch.toString());
          if (_availableLoans.isNotEmpty) {
            final nextLoanId = int.tryParse(_availableLoans.first['id']?.toString() ?? '');
            if (nextLoanId != null && nextLoanId != loanToFetch) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data kartu pinjaman sudah tidak tersedia di server. Memuat data pinjaman lainnya.'),
                    backgroundColor: Color(0xFFD97706),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              await _fetchLoanCard(nextLoanId);
              return;
            }
          }
          _currentLoanId = null;
          _header = null;
          _installments = [];
          _errorMessage = 'Belum ada data pinjaman aktif.';
        } else {
          _errorMessage = 'Gagal memuat kartu pinjaman (#$loanToFetch): status ${response.statusCode}';
        }
      } else {
        _header = null;
        _installments = [];
        _errorMessage = 'Belum ada data pinjaman aktif.';
      }
    } catch (e) {
      debugPrint('[LOAN_CARD] error: $e');
      _errorMessage = 'Gagal terhubung ke server. Silakan coba lagi.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePrintLoanCard() async {
    final loanId = _currentLoanId ?? _header?.loanId;
    if (loanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kartu pinjaman terlebih dahulu.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final token = await AuthService().getToken();
      final baseUrl = AuthService.staticBaseUrl;
      final tokenParam = (token != null && token.isNotEmpty) ? '&token=$token' : '';
      final printUrl = '$baseUrl/loans/$loanId/print?inline=1$tokenParam';

      debugPrint('[LOAN_CARD] Opening PDF print: $printUrl');
      final uri = Uri.parse(printUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        final pdfUrl = '$baseUrl/loans/$loanId/card/pdf?token=$token';
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka cetak PDF: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── Kalkulasi Dinamis ─────────────────────────────────────────────
  int get _totalPrincipalPaid {
    if (_header != null && _header!.amount > 0) {
      final paid = _header!.amount - _header!.remainingPrincipal;
      return paid < 0 ? 0 : paid;
    }
    return _installments.where((item) => item.isPaid)
        .fold(0, (sum, item) => sum + item.principalPaid);
  }

  int get _currentRemainingBalance {
    if (_header == null) return 0;
    return _header!.remainingPrincipal;
  }

  double get _repaymentProgressRatio {
    if (_header == null || _header!.amount <= 0) return 0.0;
    final ratio = (_header!.amount - _header!.remainingPrincipal) / _header!.amount;
    return ratio.clamp(0.0, 1.0);
  }

  static String _formatRupiah(num val) {
    return "Rp ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('dd/MM/yyyy').format(parsed);
      }
    } catch (_) {}
    return raw;
  }

  // ── FITUR EDIT & HAPUS KARTU PINJAMAN ─────────────────────────────
  Future<void> _showDeleteLoanConfirmation({
    required int loanId,
    required String loanCode,
    required String memberName,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Hapus Kartu Pinjaman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus kartu pinjaman No. SH: $loanCode ($memberName)?\n\nTindakan ini tidak dapat dibatalkan dan akan menghapus seluruh data jadwal angsuran pinjaman ini.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteLoan(loanId, loanCode);
    }
  }

  Future<void> _deleteLoan(int loanId, String loanCode) async {
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      var resp = await http.delete(
        Uri.parse('${AuthService.staticBaseUrl}/loans/$loanId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        resp = await http.delete(
          Uri.parse('${AuthService.staticBaseUrl}/admin/loans/$loanId'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kartu pinjaman No. SH: $loanCode berhasil dihapus.'),
            backgroundColor: const Color(0xFF166534),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (_currentLoanId == loanId) {
          _currentLoanId = null;
          _header = null;
          _installments = [];
        }
        await _fetchLoanDropdownList();
        if (_currentLoanId == null && _availableLoans.isNotEmpty) {
          _currentLoanId = int.tryParse(_availableLoans.first['id']?.toString() ?? '');
        }
        if (_currentLoanId != null) {
          await _fetchLoanCard(_currentLoanId);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Belum ada data pinjaman aktif.';
          });
        }
      } else {
        final body = jsonDecode(resp.body);
        final msg = body['message'] ?? 'Gagal menghapus kartu pinjaman (Status ${resp.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showEditLoanModal({
    required int loanId,
    required String loanCode,
    required String memberName,
    required int currentAmount,
    required int currentTenor,
    required double currentInterestRate,
    required String currentDisbursementDate,
    required String currentCollateral,
  }) async {
    final formKey = GlobalKey<FormState>();
    final curFmt = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final amountCtrl = TextEditingController(text: currentAmount > 0 ? curFmt.format(currentAmount).trim() : '');
    final tenorCtrl = TextEditingController(text: currentTenor > 0 ? currentTenor.toString() : '12');
    final rateCtrl = TextEditingController(text: currentInterestRate > 0 ? currentInterestRate.toString() : '2.5');
    final dateCtrl = TextEditingController(text: currentDisbursementDate != '-' && currentDisbursementDate.isNotEmpty ? currentDisbursementDate : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final collateralCtrl = TextEditingController(text: currentCollateral != '-' ? currentCollateral : '');

    DateTime selectedDate = DateTime.tryParse(currentDisbursementDate) ?? DateTime.now();
    bool isSaving = false;

    final bool? updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Kartu Pinjaman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
                      Text('No. SH: $loanCode • $memberName', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // 1. Plafon Pinjaman
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nominal Plafon Pinjaman (Rp)',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        validator: (val) {
                          final clean = int.tryParse((val ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;
                          if (clean <= 0) return 'Nominal pinjaman wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 2. Tenor & Bunga
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: tenorCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Tenor (Bulan)',
                                suffixText: 'Bln',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                              ),
                              validator: (val) {
                                final t = int.tryParse(val?.trim() ?? '');
                                if (t == null || t <= 0) return 'Tenor wajib > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: rateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Jasa Pinjaman (%)',
                                suffixText: '%',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                              ),
                              validator: (val) {
                                final r = double.tryParse(val?.trim().replaceAll(',', '.') ?? '');
                                if (r == null || r < 0) return 'Bunga invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. Tanggal Pencairan
                      TextFormField(
                        controller: dateCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Pencairan',
                          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFD97706)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            selectedDate = picked;
                            dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Jaminan / Agunan
                      TextFormField(
                        controller: collateralCtrl,
                        decoration: InputDecoration(
                          labelText: 'Jaminan / Agunan',
                          hintText: 'BPKB Motor / Sertifikat Tanah...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx, false),
                child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlgState(() => isSaving = true);

                        final cleanAmount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? currentAmount;
                        final tenorMonths = int.tryParse(tenorCtrl.text.trim()) ?? currentTenor;
                        final interestRate = double.tryParse(rateCtrl.text.trim().replaceAll(',', '.')) ?? currentInterestRate;
                        final dateStr = dateCtrl.text.trim();
                        final collateralStr = collateralCtrl.text.trim();

                        final success = await _updateLoan(
                          loanId: loanId,
                          amount: cleanAmount,
                          tenor: tenorMonths,
                          rate: interestRate,
                          date: dateStr,
                          collateral: collateralStr,
                        );

                        if (success && dlgCtx.mounted) {
                          Navigator.pop(dlgCtx, true);
                        } else if (dlgCtx.mounted) {
                          setDlgState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Simpan Koreksi'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true) {
      await _fetchLoanDropdownList();
      await _fetchLoanCard(loanId);
    }
  }

  Future<bool> _updateLoan({
    required int loanId,
    required int amount,
    required int tenor,
    required double rate,
    required String date,
    required String collateral,
  }) async {
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final payload = jsonEncode({
        'amount': amount,
        'duration_months': tenor,
        'tenor': tenor,
        'interest_rate': rate,
        'start_date': date,
        'disbursement_date': date,
        'tanggal_cair': date,
        'collateral_type': collateral,
        'collateral': collateral,
      });

      var resp = await http.put(
        Uri.parse('${AuthService.staticBaseUrl}/loans/$loanId'),
        headers: headers,
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 404 || resp.statusCode == 405) {
        resp = await http.put(
          Uri.parse('${AuthService.staticBaseUrl}/admin/loans/$loanId'),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 15));
      }

      if (!mounted) return (resp.statusCode == 200 || resp.statusCode == 201);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kartu pinjaman berhasil diperbarui.'),
            backgroundColor: Color(0xFF166534),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      } else {
        final body = jsonDecode(resp.body);
        final msg = body['message'] ?? 'Gagal memperbarui pinjaman (Status ${resp.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }


  // --- MODAL DIALOG INPUT ANGSURAN BARU (FLEKSIBEL 3 KOMPONEN: POKOK, JASA, DENDA) ---
  void _showInputAngsuranModal() {
    if (_installments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada jadwal angsuran pinjaman yang dapat dibayar.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();

    // Temukan angsuran pertama yang statusnya unpaid / belum lunas
    InstallmentRecord? nextUnpaid;
    try {
      nextUnpaid = _installments.firstWhere((rec) => !rec.isPaid);
    } catch (_) {
      nextUnpaid = null;
    }

    if (nextUnpaid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua angsuran pinjaman ini sudah lunas!'),
          backgroundColor: Color(0xFF166534),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final proofController = TextEditingController(
      text: nextUnpaid.proofCode.isNotEmpty && nextUnpaid.proofCode != '-'
          ? nextUnpaid.proofCode
          : 'KM-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${1000 + nextUnpaid.no}',
    );

    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    final principalController = TextEditingController(
      text: nextUnpaid.principalPaid > 0 ? currencyFormatter.format(nextUnpaid.principalPaid).trim() : '0',
    );
    final interestController = TextEditingController(
      text: nextUnpaid.interestPaid > 0 ? currencyFormatter.format(nextUnpaid.interestPaid).trim() : '0',
    );
    final penaltyController = TextEditingController(text: '0');

    bool isSubmitting = false;

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
                                    'Angsuran Ke-${nextUnpaid!.no} • ${_header?.memberName ?? "-"}',
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

                      // Row 1: Tanggal & No. Bukti
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () async {
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
                              enabled: !isSubmitting,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'No. Bukti Transaksi',
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

                      // 1. Bayar Pokok (Rp) - Editable & Opsional
                      TextFormField(
                        controller: principalController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        enabled: !isSubmitting,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Bayar Pokok (Rp)',
                          helperText: 'Mengurangi saldo pokok pinjaman anggota',
                          isDense: true,
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2 & 3: Bayar Bunga / Jasa (Rp) & Bayar Denda (Rp)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: interestController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              enabled: !isSubmitting,
                              onChanged: (_) => setModalState(() {}),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Bayar Bunga / Jasa (Rp)',
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              enabled: !isSubmitting,
                              onChanged: (_) => setModalState(() {}),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Bayar Denda (Rp)',
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

                      // Banner Total Pembayaran Angsuran (Real-time sum)
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
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() {
                                      isSubmitting = true;
                                    });

                                    try {
                                      final token = await AuthService().getToken();
                                      final dateStr =
                                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

                                      final response = await http.post(
                                        Uri.parse('${AuthService.staticBaseUrl}/loans/installments/${nextUnpaid!.id}/pay'),
                                        headers: {
                                          'Content-Type': 'application/json',
                                          'Accept': 'application/json',
                                          if (token != null) 'Authorization': 'Bearer $token',
                                        },
                                        body: jsonEncode({
                                          'receipt_number': proofController.text.trim(),
                                          'principal_amount': pPaid,
                                          'interest_amount': iPaid,
                                          'penalty_fee': penPaid,
                                          'penalty_amount': penPaid,
                                          'paid_at': dateStr,
                                          'payment_method': 'cash',
                                          'notes': 'Pembayaran Angsuran Ke-${nextUnpaid.no}',
                                        }),
                                      ).timeout(const Duration(seconds: 30));

                                      if (response.statusCode == 200) {
                                        if (context.mounted) {
                                          Navigator.pop(modalContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Angsuran Ke-${nextUnpaid.no} (${proofController.text}) BERHASIL DISIMPAN!'),
                                              backgroundColor: AppColors.success,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        _fetchLoanCard(_currentLoanId);
                                      } else {
                                        final body = jsonDecode(response.body);
                                        throw body['message'] ?? 'Gagal menyimpan angsuran.';
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded, size: 20),
                          label: Text(
                            isSubmitting ? 'Menyimpan...' : 'Simpan Transaksi Angsuran',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
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

  // --- MODAL DIALOG MIGRASI SALDO AWAL PINJAMAN LAMA ---
  void _showMigrateLoanModal() async {
    List<Map<String, dynamic>> membersList = [];
    bool loadingMembers = true;

    try {
      final token = await AuthService().getToken();
      final resp = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/members/active-list'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final dynamic raw = body['data'] is List
            ? body['data']
            : (body['data']?['data'] ?? body['members'] ?? []);
        if (raw is List) {
          membersList = raw.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    loadingMembers = false;

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    int? selectedMemberId = membersList.isNotEmpty ? int.tryParse(membersList.first['id']?.toString() ?? '') : null;
    String selectedMethod = 'declining_balance'; // 'declining_balance' (2.50%) or 'flat' (1.00%)
    final plafonController = TextEditingController();
    final remainingPrincipalController = TextEditingController();
    int remainingTenor = 12;
    DateTime dueDate = DateTime.now().add(const Duration(days: 365));
    final collateralController = TextEditingController(text: 'Migrasi Saldo Awal');
    final notesController = TextEditingController(text: 'Migrasi Saldo Awal Pinjaman Lama');
    bool isSubmitting = false;

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
            final double rate = selectedMethod == 'flat' ? 1.00 : 2.50;
            final double origAmt = parseNum(plafonController.text).toDouble();
            final double currBal = parseNum(remainingPrincipalController.text).toDouble();
            final double pokokEst = remainingTenor > 0 ? (currBal / remainingTenor).ceilToDouble() : 0;
            final double jasaEst = selectedMethod == 'flat'
                ? (origAmt * 0.01).roundToDouble()
                : (currBal * 0.025).roundToDouble();
            final double totalEst = pokokEst + jasaEst;

            final String dueDateStr =
                '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';

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
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.history_edu_rounded, color: Color(0xFFD97706), size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Migrasi Saldo Awal Pinjaman',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                  ),
                                  Text(
                                    'Input data cut-off saldo pinjaman lama anggota',
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

                      // 1. Pilih Anggota (Searchable Typeahead Dropdown)
                      if (loadingMembers)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Memuat daftar anggota...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        InkWell(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  final selected = await _showMemberSearchPicker(context, membersList, selectedMemberId);
                                  if (selected != null) {
                                    setModalState(() {
                                      selectedMemberId = int.tryParse(selected['id']?.toString() ?? '');
                                      final exists = membersList.any((m) => int.tryParse(m['id']?.toString() ?? '') == selectedMemberId);
                                      if (!exists) {
                                        membersList.add(selected);
                                      }

                                      // Pemetaan data pinjaman anggota jika tersedia di objek API
                                      final plafonVal = selected['plafon_awal'] ?? selected['original_amount'] ?? selected['amount'] ?? selected['plafon'] ?? selected['nominal'];
                                      if (plafonVal != null) {
                                        final num parsedPlafon = num.tryParse(plafonVal.toString()) ?? 0;
                                        if (parsedPlafon > 0) {
                                          plafonController.text = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(parsedPlafon).trim();
                                        }
                                      }

                                      final sisaVal = selected['sisa_saldo_pokok'] ?? selected['remaining_principal'] ?? selected['current_balance'] ?? selected['sisa_pokok'] ?? selected['sisa_pinjaman'];
                                      if (sisaVal != null) {
                                        final num parsedSisa = num.tryParse(sisaVal.toString()) ?? 0;
                                        if (parsedSisa > 0) {
                                          remainingPrincipalController.text = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(parsedSisa).trim();
                                        }
                                      }
                                    });
                                  }
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedMemberId != null ? AppColors.primary : const Color(0xFFCBD5E1),
                                width: selectedMemberId != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Anggota Koperasi (Klik untuk Cari Nama / No. Anggota)',
                                        style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        () {
                                          if (selectedMemberId == null) return 'Pilih / Cari Anggota...';
                                          final found = membersList.firstWhere(
                                            (m) => (int.tryParse(m['id']?.toString() ?? '') == selectedMemberId),
                                            orElse: () => {},
                                          );
                                          if (found.isEmpty) return 'Pilih / Cari Anggota...';
                                          final name = found['name'] ?? found['nama'] ?? '-';
                                          final no = found['member_number'] ?? found['member_no'] ?? found['no_anggota'] ?? '-';
                                          return '$name ($no)';
                                        }(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: selectedMemberId != null ? const Color(0xFF1E293B) : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 24),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 2. Skema Bunga
                      const Text(
                        'Skema Suku Bunga Pinjaman',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedMethod = 'declining_balance';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: selectedMethod == 'declining_balance' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedMethod == 'declining_balance' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedMethod == 'declining_balance' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: selectedMethod == 'declining_balance' ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Saldo Menurun (2.5%)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedMethod = 'flat';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: selectedMethod == 'flat' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedMethod == 'flat' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedMethod == 'flat' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: selectedMethod == 'flat' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Bunga Tetap / Flat (1%)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 3. Plafon Awal & Sisa Saldo Pokok Terakhir (Controller Independen)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: plafonController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              onChanged: (_) => setModalState(() {}),
                              validator: (v) => parseNum(v ?? '') <= 0 ? 'Plafon awal wajib diisi' : null,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Plafon Awal (Rp)',
                                isDense: true,
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: remainingPrincipalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              onChanged: (_) => setModalState(() {}),
                              validator: (v) {
                                final sisa = parseNum(v ?? '');
                                if (sisa <= 0) return 'Sisa saldo pokok wajib diisi';
                                final plafon = parseNum(plafonController.text);
                                if (plafon > 0 && sisa > plafon) {
                                  return 'Sisa pokok tidak boleh melebihi plafon awal';
                                }
                                return null;
                              },
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: 'Sisa Saldo Pokok (Rp)',
                                isDense: true,
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 4. Sisa Tenor & Jatuh Tempo
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: remainingTenor,
                              decoration: const InputDecoration(
                                labelText: 'Sisa Tenor (Bulan)',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: [1, 2, 3, 4, 5, 6, 8, 10, 12, 18, 24, 36, 48, 60].map((t) {
                                return DropdownMenuItem<int>(
                                  value: t,
                                  child: Text('$t Bulan'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    remainingTenor = val;
                                    dueDate = DateTime.now().add(Duration(days: val * 30));
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dueDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    dueDate = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Jatuh Tempo',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.calendar_month_outlined, size: 16),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                child: Text(dueDateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Simulasi Ringkasan
                      if (currBal > 0 || origAmt > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Angsuran Pokok: ${_formatRupiah(pokokEst)} / bln',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  Text(
                                    selectedMethod == 'flat'
                                        ? 'Jasa (1% Flat Plafon): ${_formatRupiah(jasaEst)} / bln'
                                        : 'Jasa (2.5% Saldo Menurun): ${_formatRupiah(jasaEst)} / bln',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Text(
                                'Total: ${_formatRupiah(totalEst)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // 5. Agunan & Keterangan
                      TextFormField(
                        controller: collateralController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Jaminan / Agunan',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedMemberId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pilih anggota terlebih dahulu!'), backgroundColor: Colors.red),
                                    );
                                    return;
                                  }
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() {
                                      isSubmitting = true;
                                    });

                                    try {
                                      final token = await AuthService().getToken();
                                      final formattedDueDate =
                                          "${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

                                      final response = await http.post(
                                        Uri.parse('${AuthService.staticBaseUrl}/loans/migrate-existing'),
                                        headers: {
                                          'Content-Type': 'application/json',
                                          'Accept': 'application/json',
                                          if (token != null) 'Authorization': 'Bearer $token',
                                        },
                                        body: jsonEncode({
                                          'member_id': selectedMemberId,
                                          'interest_method': selectedMethod,
                                          'interest_rate': rate,
                                          'original_amount': origAmt,
                                          'plafon_awal': origAmt,
                                          'current_balance': currBal,
                                          'remaining_principal': currBal,
                                          'sisa_saldo_pokok': currBal,
                                          'remaining_tenor': remainingTenor,
                                          'due_date': formattedDueDate,
                                          'collateral': collateralController.text.trim(),
                                          'notes': notesController.text.trim(),
                                        }),
                                      ).timeout(const Duration(seconds: 30));

                                      if (response.statusCode == 200 || response.statusCode == 201) {
                                        final resBody = jsonDecode(response.body);
                                        final newLoan = resBody['data'];
                                        final newLoanId = int.tryParse(newLoan?['id']?.toString() ?? '');

                                        if (context.mounted) {
                                          Navigator.pop(modalContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Migrasi Saldo Awal Pinjaman Berhasil!'),
                                              backgroundColor: AppColors.success,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        _fetchLoanCard(newLoanId);
                                      } else {
                                        final resBody = jsonDecode(response.body);
                                        throw resBody['message'] ?? 'Gagal migrasi pinjaman.';
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            isSubmitting ? 'Memproses Migrasi...' : 'Simpan Saldo Awal Migrasi',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
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

  // --- MODAL SEARCHABLE / TYPEAHEAD PICKER UNTUK ANGGOTA KOPERASI ---
  Future<Map<String, dynamic>?> _showMemberSearchPicker(
    BuildContext context,
    List<Map<String, dynamic>> allMembers,
    int? currentSelectedId,
  ) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerContext) {
        return _MemberSearchPickerSheet(
          initialMembers: allMembers,
          currentSelectedId: currentSelectedId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.adminNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          tooltip: 'Menu Admin',
          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kartu Pinjaman & Angsuran',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _isAdmin ? 'Mode: Admin (Full Input & Mutasi)' : 'Mode: Anggota (Read-Only)',
              style: const TextStyle(color: AppColors.adminAccent, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Segarkan',
            onPressed: () {
              _fetchLoanDropdownList();
              _fetchLoanCard(_currentLoanId);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilterChip(
              avatar: Icon(
                _isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                size: 16,
                color: _isAdmin ? AppColors.adminNavy : AppColors.primary,
              ),
              label: Text(
                _isAdmin ? 'Admin' : 'User',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _isAdmin ? AppColors.adminNavy : AppColors.primary,
                ),
              ),
              selected: _isAdmin,
              onSelected: (val) {
                setState(() {
                  _isAdmin = val;
                });
              },
              backgroundColor: Colors.white24,
              selectedColor: Colors.white,
              checkmarkColor: AppColors.adminNavy,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD97706)),
                  SizedBox(height: 12),
                  Text('Memuat Kartu Pinjaman...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchLoanDropdownList();
                await _fetchLoanCard(_currentLoanId);
              },
              color: const Color(0xFFD97706),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. DROPDOWN PILIHAN PINJAMAN & TOMBOL CETAK PDF ──
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 650;
                          return isNarrow
                              ? Column(
                                  children: [
                                    _buildLoanDropdownPicker(),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: _buildPrintButton()),
                                        if (_isAdmin) ...[
                                          const SizedBox(width: 8),
                                          _buildInputAngsuranTopButton(),
                                        ],
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: _buildLoanDropdownPicker()),
                                    const SizedBox(width: 10),
                                    _buildPrintButton(),
                                    if (_isAdmin) ...[
                                      const SizedBox(width: 10),
                                      _buildInputAngsuranTopButton(),
                                    ],
                                  ],
                                );
                        },
                      ),
                    ),

                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── 2. KARTU PINJAMAN FISIK (KARTU KUNING CUM PELITA) ──
                    if (_header != null) ...[
                      _buildPhysicalLoanCardHeader(),
                      const SizedBox(height: 16),
                    ],

                    // ── 3. ACTION BAR ADMIN (MIGRASI SALDO AWAL & INPUT) ──
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history_rounded, color: AppColors.adminNavy, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Tabel Mutasi Angsuran Pinjaman',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(
                                    '${_installments.length} Baris',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: _showMigrateLoanModal,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                backgroundColor: const Color(0xFFFFFBEB),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.history_edu_rounded, size: 16),
                              label: const Text(
                                '+ Saldo Awal Pinjaman Lama',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── 4. TABEL MUTASI ANGSURAN 9 KOLOM RESMI KARTU KUNING ──
                    _buildInstallmentHistoryTable(),
                  ],
                ),
              ),
            ),
      floatingActionButton: _isAdmin && !_isLoading && _header != null
          ? FloatingActionButton.extended(
              onPressed: _showInputAngsuranModal,
              backgroundColor: const Color(0xFFD97706),
              icon: const Icon(Icons.add_card_rounded, color: Colors.white),
              label: const Text(
                'Input Angsuran Baru',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
    );
  }

  // --- WIDGET DROPDOWN / SEARCHABLE PICKER PINJAMAN ANGGOTA ---
  Widget _buildLoanDropdownPicker() {
    return InkWell(
      onTap: () async {
        final selected = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => _LoanSearchPickerSheet(
            initialLoans: _availableLoans,
            currentSelectedId: _currentLoanId,
            isAdmin: _isAdmin,
            onEditLoan: (item) async {
              Navigator.pop(ctx);
              final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
              final code = item['loan_code'] ?? item['loan_number'] ?? item['no_sh'] ?? '#$id';
              final name = item['member_name'] ?? item['name'] ?? item['nama_anggota'] ?? (_header?.loanId == id ? _header!.memberName : '-');
              final amount = num.tryParse(item['amount']?.toString() ?? item['total_loan_amount']?.toString() ?? (_header?.loanId == id ? _header!.totalLoanAmount.toString() : '0'))?.toInt() ?? (_header?.loanId == id ? _header!.totalLoanAmount : 0);
              final tenor = int.tryParse(item['duration_months']?.toString() ?? item['tenor_months']?.toString() ?? item['tenor']?.toString() ?? (_header?.loanId == id ? _header!.tenorMonths.toString() : '12')) ?? (_header?.loanId == id ? _header!.tenorMonths : 12);
              final rate = double.tryParse(item['interest_rate']?.toString() ?? item['bunga_persen']?.toString() ?? (_header?.loanId == id ? _header!.interestRate.toString() : '2.5')) ?? (_header?.loanId == id ? _header!.interestRate : 2.5);
              final date = (item['disbursement_date'] ?? item['start_date'] ?? item['tanggal_cair'] ?? (_header?.loanId == id ? _header!.disbursementDate : '')).toString();
              final collateral = (item['collateral_type'] ?? item['collateral'] ?? item['jaminan'] ?? (_header?.loanId == id ? _header!.collateral : '-')).toString();

              await _showEditLoanModal(
                loanId: id,
                loanCode: code,
                memberName: name,
                currentAmount: amount,
                currentTenor: tenor,
                currentInterestRate: rate,
                currentDisbursementDate: date,
                currentCollateral: collateral,
              );
            },
            onDeleteLoan: (item) async {
              Navigator.pop(ctx);
              final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
              final code = item['loan_code'] ?? item['loan_number'] ?? item['no_sh'] ?? '#$id';
              final name = item['member_name'] ?? item['name'] ?? item['nama_anggota'] ?? '-';
              await _showDeleteLoanConfirmation(
                loanId: id,
                loanCode: code,
                memberName: name,
              );
            },
          ),
        );
        if (selected != null) {
          final newId = int.tryParse(selected['id']?.toString() ?? '');
          if (newId != null && newId != _currentLoanId) {
            _fetchLoanCard(newId);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD97706), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PILIH PINJAMAN / NAMA ANGGOTA (KLIK UNTUK CARI)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _header != null
                        ? '${_header!.memberName} (${_header!.memberNo}) - No. SH: ${_header!.loanCode} (Sisa ${_formatRupiah(_currentRemainingBalance)})'
                        : 'Pilih Pinjaman Anggota...',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFD97706), size: 28),
          ],
        ),
      ),
    );
  }

  // --- WIDGET TOMBOL CETAK KARTU PINJAMAN (PDF) ---
  Widget _buildPrintButton() {
    return ElevatedButton.icon(
      onPressed: (_currentLoanId == null || _isPrinting) ? null : _handlePrintLoanCard,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _isPrinting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.print_rounded, size: 20),
      label: Text(
        _isPrinting ? 'Menyiapkan PDF...' : 'Cetak Kartu Pinjaman',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInputAngsuranTopButton() {
    return ElevatedButton.icon(
      onPressed: _showInputAngsuranModal,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Input Angsuran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // --- WIDGET KARTU FISIK PINJAMAN (KARTU KUNING CUM PELITA) ---
  Widget _buildPhysicalLoanCardHeader() {
    if (_header == null) return const SizedBox.shrink();
    final h = _header!;
    final progressPercent = (_repaymentProgressRatio * 100).toStringAsFixed(1);
    final isFlat = h.interestMethod.toLowerCase().contains('flat');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KOP KOPERASI & KARTU KUNING HEADER ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFFDE68A), width: 1.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
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
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KOPERASI SIMPAN PINJAM CUM PELITA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adminNavy,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'HKBP RESSORT DAME • KARTU PINJAMAN ANGGOTA (KARTU KUNING)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No. SH: ${h.loanCode}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── DUA KOLOM: HEADER KIRI vs HEADER KANAN ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    return isNarrow
                        ? Column(
                            children: [
                              _buildHeaderKiri(h, isFlat),
                              const SizedBox(height: 12),
                              _buildHeaderKanan(h),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildHeaderKiri(h, isFlat)),
                              const SizedBox(width: 16),
                              Expanded(flex: 6, child: _buildHeaderKanan(h)),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 14),

                // ── PROGRES PELUNASAN BAR ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progres Pelunasan Pokok ($progressPercent%)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          Text(
                            'Pokok Terbayar: ${_formatRupiah(_totalPrincipalPaid)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _repaymentProgressRatio,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER KIRI: SPESIFIKASI JASA & JANGKA WAKTU ---
  Widget _buildHeaderKiri(LoanCardHeader h, bool isFlat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'SPESIFIKASI PINJAMAN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const Divider(height: 14, color: Color(0xFFFDE68A)),
          _buildDetailRow('Jasa', '${h.interestRate}% per bulan (${isFlat ? "Bunga Flat" : "Saldo Menurun"})'),
          const SizedBox(height: 6),
          _buildDetailRow('Jangka Waktu', '${h.tenorMonths} Bulan'),
          const SizedBox(height: 6),
          _buildDetailRow('Tgl Pencairan', _formatDate(h.disbursementDate)),
          const SizedBox(height: 6),
          _buildDetailRow('Jatuh Tempo', _formatDate(h.dueDate)),
        ],
      ),
    );
  }

  // --- HEADER KANAN: DATA ANGGOTA, NO SH & NOMINAL SALDO ---
  Widget _buildHeaderKanan(LoanCardHeader h) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'DATA ANGGOTA & PINJAMAN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const Divider(height: 14, color: Color(0xFFFDE68A)),
          _buildDetailRow('NAMA', '${h.memberName} (${h.memberNo})'),
          const SizedBox(height: 6),
          _buildDetailRow('No SH', h.loanCode),
          const SizedBox(height: 6),
          _buildDetailRow('PINJAMAN', _formatRupiah(h.totalLoanAmount), isHighlight: true),
          const SizedBox(height: 6),
          _buildDetailRow('Alamat & HP', '${(h.address.isNotEmpty && h.address != "-") ? h.address : h.church} / HP ${h.phone}'),
          const SizedBox(height: 6),
          _buildDetailRow('Jaminan', h.collateral),
          const SizedBox(height: 6),
          _buildDetailRow('Sisa Pokok', _formatRupiah(_currentRemainingBalance), isHighlight: true, isRemaining: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isRemaining = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isRemaining
                  ? const Color(0xFFD97706)
                  : (isHighlight ? AppColors.adminNavy : const Color(0xFF1E293B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, {bool isPaid = false}) {
    final bool paid = isPaid || status.toLowerCase() == 'paid' || status.toLowerCase() == 'lunas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: paid ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
      ),
      child: Text(
        paid ? 'LUNAS' : 'BELUM DIBAYAR',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: paid ? const Color(0xFF15803D) : const Color(0xFFB45309),
        ),
      ),
    );
  }

  // --- WIDGET TABEL HISTORI ANGSURAN (9 KOLOM RESMI KARTU KUNING) ---
  Widget _buildInstallmentHistoryTable() {
    if (_header == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text('Belum ada data pinjaman.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    final h = _header!;

    InstallmentRecord? firstUnpaid;
    try {
      firstUnpaid = _installments.firstWhere((rec) => !rec.isPaid);
    } catch (_) {
      firstUnpaid = null;
    }

    final List<DataRow> tableRows = [];

    // Baris 1: Catatan Pencairan Plafon Pokok
    tableRows.add(
      DataRow(
        color: WidgetStateProperty.all(const Color(0xFFFEF9C3).withValues(alpha: 0.6)),
        cells: [
          // 1. Tgl
          DataCell(
            Text(
              _formatDate(h.disbursementDate),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
            ),
          ),
          // 2. No. Bukti
          const DataCell(
            Text(
              'Pencairan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
            ),
          ),
          // 3. Ang Ke
          const DataCell(
            Text('-', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          // 4. Jumlah Pinjaman (Rp)
          DataCell(
            Text(
              _formatRupiah(h.totalLoanAmount),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
            ),
          ),
          // 5. Angsuran (Rp)
          const DataCell(
            Text('-', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          // 6. Saldo (Rp)
          DataCell(
            Text(
              _formatRupiah(h.totalLoanAmount),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
            ),
          ),
          // 7. Jasa (Rp)
          const DataCell(
            Text('-', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          // 8. Denda (Rp)
          const DataCell(
            Text('-', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          // 9. Paraf (Teller)
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                '✓ Kasir',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ),
          ),
        ],
      ),
    );

    // Baris 2..N: Catatan Angsuran & Penurunan Saldo Dinamis
    for (final rec in _installments) {
      final bool isPaid = rec.isPaid;
      final bool isFirstUnpaid = firstUnpaid != null && rec.no == firstUnpaid.no;

      tableRows.add(
        DataRow(
          cells: [
            // 1. Tgl
            DataCell(
              Text(
                _formatDate(rec.date),
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
            // 2. No. Bukti
            DataCell(
              Text(
                rec.proofCode.isNotEmpty && rec.proofCode != '-' ? rec.proofCode : 'KM-${rec.no}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.adminNavy),
              ),
            ),
            // 3. Ang Ke
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Ke-${rec.no}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isPaid ? const Color(0xFFB45309) : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // 4. Jumlah Pinjaman (Rp)
            const DataCell(
              Text('-', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
            // 5. Angsuran (Rp)
            DataCell(
              Text(
                rec.principalPaid > 0
                    ? _formatRupiah(rec.principalPaid)
                    : (isPaid ? 'Rp 0' : '-'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: rec.principalPaid > 0 ? FontWeight.bold : FontWeight.normal,
                  color: rec.principalPaid > 0 ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ),
            // 6. Saldo (Rp)
            DataCell(
              Text(
                _formatRupiah(rec.remainingBalance),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            // 7. Jasa (Rp)
            DataCell(
              Text(
                rec.interestPaid > 0 ? _formatRupiah(rec.interestPaid) : '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: rec.interestPaid > 0 ? FontWeight.w600 : FontWeight.normal,
                  color: rec.interestPaid > 0 ? const Color(0xFF0284C7) : AppColors.textMuted,
                ),
              ),
            ),
            // 8. Denda (Rp)
            DataCell(
              Text(
                rec.penaltyPaid > 0 ? _formatRupiah(rec.penaltyPaid) : '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: rec.penaltyPaid > 0 ? FontWeight.bold : FontWeight.normal,
                  color: rec.penaltyPaid > 0 ? AppColors.danger : AppColors.textMuted,
                ),
              ),
            ),
            // 9. Paraf (Teller)
            DataCell(
              _isAdmin && isFirstUnpaid
                  ? ElevatedButton(
                      onPressed: _showInputAngsuranModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'Bayar Angsuran',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  : (isPaid
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            '✓ ${rec.tellerName.isNotEmpty && rec.tellerName != "-" ? rec.tellerName : "Kasir"} (Lunas)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        )
                      : _buildStatusBadge(rec.status, isPaid: isPaid)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
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
            headingRowColor: WidgetStateProperty.all(const Color(0xFFFEF3C7)),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 44,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('Tgl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('No. Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Ang Ke', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Jumlah Pinjaman (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Angsuran (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Saldo (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Jasa (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Denda (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
              DataColumn(label: Text('Paraf (Teller)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)))),
            ],
            rows: tableRows,
          ),
        ),
      ),
    );
  }
}

/// Searchable Picker Sheet untuk Pinjaman Anggota (No. SH, Nama, No. Anggota)
class _LoanSearchPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialLoans;
  final int? currentSelectedId;
  final bool isAdmin;
  final Function(Map<String, dynamic> item)? onEditLoan;
  final Function(Map<String, dynamic> item)? onDeleteLoan;

  const _LoanSearchPickerSheet({
    required this.initialLoans,
    this.currentSelectedId,
    this.isAdmin = false,
    this.onEditLoan,
    this.onDeleteLoan,
  });

  @override
  State<_LoanSearchPickerSheet> createState() => _LoanSearchPickerSheetState();
}

class _LoanSearchPickerSheetState extends State<_LoanSearchPickerSheet> {
  late List<Map<String, dynamic>> _allLoans;
  List<Map<String, dynamic>> _filteredLoans = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allLoans = List.from(widget.initialLoans);
    _filteredLoans = List.from(_allLoans);
    if (_allLoans.isEmpty) {
      _fetchLoans();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoans([String query = '']) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthService().getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final resp = await http.get(
        Uri.parse('${AuthService.staticBaseUrl}/loans/dropdown-list'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final dynamic raw = body['data'] is List ? body['data'] : (body['loans'] ?? []);
        if (raw is List) {
          final list = raw.whereType<Map<String, dynamic>>().toList();
          if (mounted) {
            setState(() {
              _allLoans = list;
              _applyFilter(_searchQuery, list);
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _applyFilter(_searchQuery, _allLoans);
        });
      }
    });
  }

  void _applyFilter(String query, List<Map<String, dynamic>> sourceList) {
    if (query.trim().isEmpty) {
      _filteredLoans = List.from(sourceList);
      return;
    }
    final q = query.toLowerCase().trim();
    _filteredLoans = sourceList.where((m) {
      final name = (m['member_name'] ?? m['name'] ?? m['nama_anggota'] ?? '').toString().toLowerCase();
      final no = (m['member_no'] ?? m['member_number'] ?? m['no_anggota'] ?? '').toString().toLowerCase();
      final code = (m['loan_code'] ?? m['loan_number'] ?? m['no_sh'] ?? '').toString().toLowerCase();
      return name.contains(q) || no.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pilih Pinjaman Anggota (No. SH)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari Nama Anggota, No. Anggota, atau No. SH...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD97706)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFFEF9C3).withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isLoading
                    ? 'Memuat data pinjaman...'
                    : 'Ditemukan ${_filteredLoans.length} pinjaman',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredLoans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        const Text(
                          'Tidak ada pinjaman yang cocok dengan pencarian.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _fetchLoans(''),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Muat Ulang Semua Pinjaman', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredLoans.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final item = _filteredLoans[idx];
                      final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
                      final name = item['member_name'] ?? item['name'] ?? item['nama_anggota'] ?? '-';
                      final no = item['member_no'] ?? item['member_number'] ?? item['no_anggota'] ?? '-';
                      final code = item['loan_code'] ?? item['loan_number'] ?? item['no_sh'] ?? '#$id';
                      final sisa = num.tryParse(item['remaining_balance']?.toString() ?? item['sisa_pokok']?.toString() ?? '0') ?? 0;
                      final isSelected = widget.currentSelectedId == id;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected ? const Color(0xFFD97706) : const Color(0xFFFEF3C7),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: isSelected ? Colors.white : const Color(0xFFD97706),
                          ),
                        ),
                        title: Text(
                          '$name ($no)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          'No. SH: $code • Sisa: ${_LoanInstallmentCardScreenState._formatRupiah(sisa)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: widget.isAdmin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.onEditLoan != null)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF0284C7)),
                                      tooltip: 'Edit Pinjaman',
                                      splashRadius: 18,
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      onPressed: () => widget.onEditLoan!(item),
                                    ),
                                  if (widget.onDeleteLoan != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFDC2626)),
                                      tooltip: 'Hapus Pinjaman',
                                      splashRadius: 18,
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      onPressed: () => widget.onDeleteLoan!(item),
                                    ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 20),
                                  ],
                                ],
                              )
                            : (isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 20)
                                : null),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberSearchPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialMembers;
  final int? currentSelectedId;

  const _MemberSearchPickerSheet({
    required this.initialMembers,
    this.currentSelectedId,
  });

  @override
  State<_MemberSearchPickerSheet> createState() => _MemberSearchPickerSheetState();
}

class _MemberSearchPickerSheetState extends State<_MemberSearchPickerSheet> {
  late List<Map<String, dynamic>> _allMembers;
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allMembers = List.from(widget.initialMembers);
    _filteredMembers = List.from(_allMembers);

    // Auto-Load saat dialog dibuka jika list awal kosong atau butuh fetch ulang
    if (_allMembers.isEmpty) {
      _fetchMembers();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers([String query = '']) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService().getToken();
      final uri = query.trim().isNotEmpty
          ? Uri.parse('${AuthService.staticBaseUrl}/members/active-list?search=${Uri.encodeComponent(query.trim())}')
          : Uri.parse('${AuthService.staticBaseUrl}/members/active-list');

      final resp = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final dynamic raw = body['data'] is List
            ? body['data']
            : (body['data']?['data'] ?? body['members'] ?? []);
        if (raw is List) {
          final list = raw.whereType<Map<String, dynamic>>().toList();
          if (mounted) {
            setState(() {
              if (query.trim().isEmpty) {
                _allMembers = list;
              }
              _applyFilter(query, list);
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_allMembers.isNotEmpty) {
        setState(() {
          _applyFilter(_searchQuery, _allMembers);
        });
      } else {
        _fetchMembers(_searchQuery);
      }
    });
  }

  void _applyFilter(String query, List<Map<String, dynamic>> sourceList) {
    if (query.trim().isEmpty) {
      _filteredMembers = List.from(sourceList);
      return;
    }
    final q = query.toLowerCase().trim();
    _filteredMembers = sourceList.where((m) {
      final name = (m['name'] ?? m['nama'] ?? '').toString().toLowerCase();
      final no = (m['member_number'] ?? m['member_no'] ?? m['no_anggota'] ?? m['no_register'] ?? '').toString().toLowerCase();
      final phone = (m['phone'] ?? m['no_hp'] ?? '').toString().toLowerCase();
      final nik = (m['nik'] ?? '').toString().toLowerCase();
      return name.contains(q) || no.contains(q) || phone.contains(q) || nik.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pilih Anggota Koperasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.adminNavy),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Ketik nama, no anggota, atau no HP...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isLoading
                    ? 'Memuat data anggota...'
                    : 'Ditemukan ${_filteredMembers.length} anggota',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading && _filteredMembers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Mengambil data anggota aktif...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_off_rounded, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            const Text(
                              'Tidak ada anggota yang cocok dengan pencarian.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _fetchMembers(''),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Muat Ulang Semua Anggota', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredMembers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final item = _filteredMembers[idx];
                          final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
                          final name = item['name'] ?? item['nama'] ?? '-';
                          final no = item['member_number'] ?? item['member_no'] ?? item['no_anggota'] ?? item['no_register'] ?? '-';
                          final phone = item['phone'] ?? item['no_hp'] ?? '-';
                          final isSelected = widget.currentSelectedId == id;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected ? AppColors.primary : AppColors.primaryBackground,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              '$name ($no)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: Text(
                              'HP: $phone',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                : null,
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
